import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @State private var selectedDate = Date()
    
    var body: some View {
        @Bindable var bindableManager = manager
        
        HStack(spacing: 0) {
            if manager.isSidebarVisible {
                TimerControlsView()
                    .frame(width: AppTheme.sidebarWidth)
                    .background(.regularMaterial)
                    .transition(.move(edge: .leading))
                
                Divider()
            }
            
            DayView(date: selectedDate, onDateChange: { selectedDate = $0 })
                .frame(minWidth: 100, idealWidth: AppTheme.mainWidth, maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.isSidebarVisible.toggle()
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
        .alert("Time to Track!", isPresented: $bindableManager.showAggressiveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have no active timers running.")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let manager = AppManager(modelContext: container.mainContext)
    let today = Date()
    
    let start1 = today.addingTimeInterval(-10000)
    let end1 = today.addingTimeInterval(-7200)
    let task1 = Task(taskDescription: "Daily Standup", startTime: start1, isActive: false)
    task1.endTime = end1
    container.mainContext.insert(task1)
    
    let start2 = today.addingTimeInterval(-3600)
    let task2 = Task(taskDescription: "Working on UI Previews", startTime: start2, isActive: true)
    container.mainContext.insert(task2)
    
    return ContentView()
        .modelContainer(container)
        .environment(manager)
}
