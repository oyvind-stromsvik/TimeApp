import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header / Date Picker Area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    
                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                TimerControlsView()
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            DayView(date: selectedDate)
                .frame(minWidth: 600)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
}
