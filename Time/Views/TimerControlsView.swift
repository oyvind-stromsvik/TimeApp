import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TimeEntry> { $0.isActive == true }, sort: \TimeEntry.startTime) private var activeEntries: [TimeEntry]
    
    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Start Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Track New Task")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                HStack(spacing: 8) {
                    TextField("What are you working on?", text: $newTimerDescription)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onSubmit(startTimer)
                    
                    Button(action: startTimer) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(newTimerDescription.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newTimerDescription.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            Divider()
            
            if activeEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No Active Timers")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Start a task to begin tracking time.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    Section {
                        ForEach(activeEntries) { entry in
                            ActiveTimerRow(entry: entry)
                        }
                    } header: {
                        Text("Active Tasks")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(AppTheme.Colors.sidebarBackground)
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
    @Environment(TimerManager.self) private var timerManager
    
    var body: some View {
        let _ = timerManager.lastTick
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.taskDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                    Text(entry.formattedDuration)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    entry.stop()
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red.gradient)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    return TimerControlsView()
        .modelContainer(container)
        .environment(manager)
}
