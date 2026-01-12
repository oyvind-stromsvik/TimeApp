import SwiftUI

struct MenuBarTaskList: View {
    let manager: AppManager
    
    var body: some View {
        // Force refresh every second to update durations
        let _ = manager.lastTick
        
        if !manager.activeTasks.isEmpty {
            ForEach(manager.activeTasks) { task in
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("\(task.taskDescription)    \(task.formattedDuration)")
                }
            }
            Divider()
        }
    }
}
