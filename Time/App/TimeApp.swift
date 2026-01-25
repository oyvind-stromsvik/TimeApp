import SwiftUI
import AppKit
import SwiftData

@main
struct TimeApp: App {
    let sharedModelContainer: ModelContainer
    let manager: AppManager
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"
    
    init() {
        do {
            // Use the migration plan to ensure proper schema versioning
            let container = try ModelContainer(
                for: Task.self,
                migrationPlan: TaskMigrationPlan.self
            )
            self.sharedModelContainer = container
            self.manager = AppManager(modelContext: container.mainContext)

            // Disable native macOS window tabbing
            NSWindow.allowsAutomaticWindowTabbing = false
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light":
            return .light
        case "Dark":
            return .dark
        default:
            return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(sharedModelContainer)
        
        Settings {
            SettingsView()
                .preferredColorScheme(colorScheme)
        }

        .commands {
            CommandGroup(replacing: .sidebar) {
                Button(manager.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.isSidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: [.control, .command])
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Time") {
                    let credits = NSMutableAttributedString()
                    
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    
                    let normalAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    let linkAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                        .foregroundColor: NSColor.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: URL(string: "https://github.com/oyvind-stromsvik")!,
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    credits.append(NSAttributedString(string: "Made by Øyvind Strømsvik\n\n", attributes: normalAttributes))
                    credits.append(NSAttributedString(string: "GitHub Profile", attributes: linkAttributes))
                    
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: credits
                    ])
                }
            }
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
            MenuBarTaskList(manager: manager)
            
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
