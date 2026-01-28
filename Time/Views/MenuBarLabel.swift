import SwiftUI
import SwiftData
import AppKit

struct MenuBarLabel: View {
    let manager: AppManager

    private func menuBarIcon(isActive: Bool) -> NSImage {
        let iconName = isActive ? "MenuBarIconActive" : "MenuBarIcon"
        let icon = NSImage(named: iconName) ?? NSImage(systemSymbolName: "clock", accessibilityDescription: nil)!
        icon.isTemplate = true
        return icon
    }

    var body: some View {
        // Accessing lastTick ensures this view redraws every second (if the timer is running)
        let _ = manager.lastTick
        let activeTasks = manager.activeTasks
        let hasActiveTasks = !activeTasks.isEmpty

        HStack {
            Image(nsImage: menuBarIcon(isActive: hasActiveTasks))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)

            if activeTasks.isEmpty {
                Text("  NO ACTIVE TASKS")
            } else if activeTasks.count == 1, let task = activeTasks.first {
                Text("  \(task.taskDescription)  \(task.formattedDuration)")
            } else {
                Text("  \(activeTasks.count) Active")
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
