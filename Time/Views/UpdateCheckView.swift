import SwiftUI

struct UpdateCheckView: View {
    @State private var updateManager = UpdateManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "clock.fill", accessibilityDescription: nil)!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
            
            VStack(spacing: 16) {
                switch updateManager.status {
                case .idle:
                    Text("Time")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Version \(updateManager.currentVersion)")
                        .foregroundStyle(.secondary)
                    
                case .checking:
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Checking for updates...")
                            .foregroundStyle(.secondary)
                    }
                    
                case .updateAvailable(let version, let url):
                    VStack(spacing: 12) {
                        Text("New Version Available")
                            .font(.headline)
                        
                        Text("Time \(version) is available.")
                            .multilineTextAlignment(.center)
                        
                        Text("You are currently using version \(updateManager.currentVersion).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Download Update") {
                            NSWorkspace.shared.open(url)
                            // Optional: Close window?
                            // dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                    
                case .upToDate:
                    VStack(spacing: 8) {
                        Text("You're up to date!")
                            .font(.headline)
                        Text("Time \(updateManager.currentVersion) is the newest version available.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                        
                case .error(let message):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.largeTitle)
                        Text("Update Check Failed")
                            .font(.headline)
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button("Try Again") {
                            updateManager.checkForUpdates()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(30)
        .frame(width: 350)
        .onAppear {
            if case .idle = updateManager.status {
                updateManager.checkForUpdates()
            }
        }
    }
}

#Preview {
    UpdateCheckView()
        .frame(width: 350, height: 300)
}
