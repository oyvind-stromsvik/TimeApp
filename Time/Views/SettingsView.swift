import SwiftUI

struct SettingsView: View {
    @AppStorage("idleThreshold") private var idleThreshold: Double = 300
    @AppStorage("aggressiveThreshold") private var aggressiveThreshold: Double = 60
    @AppStorage("enableAggressiveAlerts") private var enableAggressiveAlerts: Bool = true
    
    var body: some View {
        Form {
            Section("Idle Detection") {
                Text("App will notify you if you are idle while a timer is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Stepper("Idle Threshold: \(Int(idleThreshold / 60)) min", value: $idleThreshold, in: 60...3600, step: 60)
            }
            
            Section("Aggressive Alerts") {
                Toggle("Enable Aggressive Alerts", isOn: $enableAggressiveAlerts)
                
                if enableAggressiveAlerts {
                    Text("App will annoy you if no timer is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Stepper("Alert Interval: \(Int(aggressiveThreshold / 60)) min", value: $aggressiveThreshold, in: 30...600, step: 30)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 300)
    }
}

#Preview {
    SettingsView()
}
