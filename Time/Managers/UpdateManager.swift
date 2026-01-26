import Foundation
import SwiftUI
import OSLog
import _Concurrency
@MainActor
@Observable
final class UpdateManager: NSObject {
    static let shared = UpdateManager()
    
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case updateAvailable(version: String, url: URL)
        case upToDate
        case error(String)
    }
    
    var status: UpdateStatus = .idle
    private var updateWindow: NSWindow?
    
    private let repoOwner = "oyvind-stromsvik"
    private let repoName = "TimeApp"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TimeApp", category: "UpdateManager")
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    private override init() {}
    
    @MainActor
    func showUpdateWindow() {
        if let window = updateWindow {
            window.makeKeyAndOrderFront(nil)
            checkForUpdates()
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Check for Updates"
            window.center()
            window.contentView = NSHostingView(rootView: UpdateCheckView())
            window.isReleasedWhenClosed = false
            window.delegate = self
            
            self.updateWindow = window
            window.makeKeyAndOrderFront(nil)
            // checkForUpdates() is called by onAppear of the view
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func checkForUpdates() {
        status = .checking
        logger.info("Checking for updates...")
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            status = .error("Invalid update URL")
            return
        }
        
        _Concurrency.Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    logger.error("Failed to fetch latest release. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    status = .error("Failed to fetch latest release")
                    return
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                
                logger.info("Latest version: \(latestVersion), Current: \(self.currentVersion)")
                
                if isVersionNewer(latest: latestVersion, current: currentVersion) {
                    if let htmlUrl = URL(string: release.htmlUrl) {
                        status = .updateAvailable(version: latestVersion, url: htmlUrl)
                    } else {
                        status = .error("Invalid release URL")
                    }
                } else {
                    status = .upToDate
                }
            } catch {
                logger.error("Error checking for updates: \(error.localizedDescription)")
                status = .error(error.localizedDescription)
            }
        }
    }
    
    private func isVersionNewer(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let count = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<count {
            let l = i < latestComponents.count ? latestComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            
            if l > c { return true }
            if l < c { return false }
        }
        
        return false
    }
}

extension UpdateManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.updateWindow = nil
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}
