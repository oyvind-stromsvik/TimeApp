import SwiftUI
import AppKit
import SwiftData

@main
struct TimeApp: App {
    let sharedModelContainer: ModelContainer
    let manager: AppManager
    
    init() {
        let schema = Schema([
            Task.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            self.manager = AppManager(modelContext: container.mainContext)
            
            // Disable native macOS window tabbing
            NSWindow.allowsAutomaticWindowTabbing = false
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
        }
        
        MenuBarExtra {
            Button("Open Time") {
                NSApp.activate(ignoringOtherApps: true)
                // If the main window is closed, this might not reopen it automatically in standard SwiftUI without openWindow env, 
                // but usually works for bringing to front.
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            MenuBarLabel(manager: manager)
        }
        .modelContainer(sharedModelContainer)
        // Environment injection for content is still fine, though we don't strictly use it in the menu content yet.
        .environment(manager)
    }
}
