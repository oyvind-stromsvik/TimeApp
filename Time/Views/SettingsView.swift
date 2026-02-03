import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

struct SettingsView: View {
    @AppStorage("idleThreshold") private var idleThreshold: Double = 300
    @AppStorage("enableIdleDetection") private var enableIdleDetection: Bool = true
    @AppStorage("aggressiveThreshold") private var noActiveTasksThreshold: Double = 60
    @AppStorage("enableAggressiveAlerts") private var enableNoActiveTasksAlerts: Bool = true
    @AppStorage("enableTrackingCheck") private var enableTrackingCheck: Bool = false
    @AppStorage("trackingCheckInterval") private var trackingCheckInterval: Double = 1800
    @AppStorage("allowSimultaneousTasks") private var allowSimultaneousTasks: Bool = true
    @AppStorage("askToStopActiveTasks") private var askToStopActiveTasks: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("timeStepMinutes") private var timeStepMinutes: Int = 5
    @AppStorage("defaultNewTaskDuration") private var defaultNewTaskDuration: Double = 1800
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Idle Detection") {
                Toggle("Enable Idle Detection", isOn: $enableIdleDetection)
                
                if enableIdleDetection {
                    Text("App will show a modal if you are idle while a task is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Stepper("Idle Threshold: \(Int(idleThreshold / 60)) min", value: $idleThreshold, in: 60...3600, step: 60)
                }
            }
            
            Section("No Active Tasks Alert") {
                Toggle("Enable No Active Tasks Alert", isOn: $enableNoActiveTasksAlerts)
                
                if enableNoActiveTasksAlerts {
                    Text("App will show a modal when no task is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Stepper("Alert Interval: \(Int(noActiveTasksThreshold / 60)) min", value: $noActiveTasksThreshold, in: 30...600, step: 30)
                }
            }

            Section("Tracking Check-In") {
                Toggle("Enable Tracking Check-In", isOn: $enableTrackingCheck)

                if enableTrackingCheck {
                    Text("App will periodically confirm you are tracking the right task.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Check-In Interval", selection: $trackingCheckInterval) {
#if DEBUG
                        Text("1 minute").tag(60.0)
#endif
                        Text("15 minutes").tag(900.0)
                        Text("30 minutes").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                        Text("2 hours").tag(7200.0)
                    }
                }
            }
            
            Section("Task Settings") {
                Toggle("Allow Simultaneous Active Tasks", isOn: $allowSimultaneousTasks)

                if allowSimultaneousTasks {
                    Toggle("Ask to stop active tasks", isOn: $askToStopActiveTasks)
                        .font(.body)
                        .padding(.leading, AppTheme.Spacing.lg)
                }
            }

            Section("Timeline") {
                Picker("Time Step", selection: $timeStepMinutes) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }

                Picker("Default Task Duration", selection: $defaultNewTaskDuration) {
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 500)
    }
}

#Preview {
    SettingsView()
}
