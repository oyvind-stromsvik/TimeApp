import SwiftUI

struct SettingsView: View {
    @AppStorage("idleThreshold") private var idleThreshold: Double = 300
    @AppStorage("enableIdleDetection") private var enableIdleDetection: Bool = true
    @AppStorage("aggressiveThreshold") private var aggressiveThreshold: Double = 60
    @AppStorage("enableAggressiveAlerts") private var enableAggressiveAlerts: Bool = true
    @AppStorage("allowSimultaneousTasks") private var allowSimultaneousTasks: Bool = true
    
    var body: some View {
        Form {
            Section("Idle Detection") {
                Toggle("Enable Idle Detection", isOn: $enableIdleDetection)
                
                if enableIdleDetection {
                    Text("App will notify you if you are idle while a task is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Stepper("Idle Threshold: \(Int(idleThreshold / 60)) min", value: $idleThreshold, in: 60...3600, step: 60)
                }
            }
            
            Section("Aggressive Alerts") {
                Toggle("Enable Aggressive Alerts", isOn: $enableAggressiveAlerts)
                
                if enableAggressiveAlerts {
                    Text("App will annoy you if no task is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Stepper("Alert Interval: \(Int(aggressiveThreshold / 60)) min", value: $aggressiveThreshold, in: 30...600, step: 30)
                }
            }
            
            Section("Task Settings") {
                Toggle("Allow Simultaneous Active Tasks", isOn: $allowSimultaneousTasks)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 300)
    }
}

#Preview {
    SettingsView()
}
