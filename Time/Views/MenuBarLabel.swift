import SwiftUI
import SwiftData

struct MenuBarLabel: View {
    let manager: AppManager
    
    var body: some View {
        // Accessing lastTick ensures this view redraws every second (if the timer is running)
        let _ = manager.lastTick
        let activeTasks = manager.activeTasks
        
        HStack {
            Image(systemName: "timer")
                .foregroundColor(activeTasks.isEmpty ? .red : .blue)
            
            if activeTasks.isEmpty {
                Text("NO ACTIVE TASKS")
            } else if activeTasks.count == 1, let task = activeTasks.first {
                Text(task.taskDescription)
            } else {
                Text("\(activeTasks.count) Active")
            }
        }
    }
}

#Preview {
    let schema = Schema([Task.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let manager = AppManager(modelContext: container.mainContext)
    
    return MenuBarLabel(manager: manager)
}
