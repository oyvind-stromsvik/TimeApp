import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TimerControlsView()
                .navigationSplitViewColumnWidth(min: 100, ideal: AppTheme.sidebarWidth, max: 400)
        } detail: {
            DayView(date: selectedDate)
                .frame(minWidth: 100, idealWidth: AppTheme.mainWidth, maxWidth: .infinity)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .frame(width: 140)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDate = Date()
                            }
                        } label: {
                            Label("Today", systemImage: "calendar")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
