import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TimeEntry> { $0.isActive == true }, sort: \TimeEntry.startTime) private var activeEntries: [TimeEntry]
    
    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Start Field
            HStack {
                TextField("What are you working on?", text: $newTimerDescription)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(startTimer)
                
                Button(action: startTimer) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(newTimerDescription.isEmpty)
            }
            .padding()
            
            Divider()
            
            if activeEntries.isEmpty {
                ContentUnavailableView("No Active Timers", systemImage: "timer", description: Text("Start a task to begin tracking time."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(activeEntries) { entry in
                        ActiveTimerRow(entry: entry)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private func startTimer() {
        guard !newTimerDescription.isEmpty else { return }
        let newEntry = TimeEntry(taskDescription: newTimerDescription)
        modelContext.insert(newEntry)
        newTimerDescription = ""
        try? modelContext.save()
    }
}

struct ActiveTimerRow: View {
    @Bindable var entry: TimeEntry
    @Environment(\.modelContext) private var modelContext
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entry.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button {
                entry.stop()
                try? modelContext.save()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            tick = Date()
        }
    }
}

#Preview {
    TimerControlsView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
} 
