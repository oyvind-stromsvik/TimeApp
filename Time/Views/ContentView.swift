import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                TimerControlsView()
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            DayView(date: selectedDate)
                .frame(minWidth: 600)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .frame(width: 150)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Today") {
                            withAnimation {
                                selectedDate = Date()
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    return ContentView()
        .modelContainer(container)
        .environment(manager)
}
