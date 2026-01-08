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
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) {
                        Label("Toggle Sidebar", systemImage: "sidebar.left")
                    }
                }
            }
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
    
    private func toggleSidebar() {
        withAnimation {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
}
