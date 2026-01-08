import SwiftUI
import SwiftData

struct EditTimeEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.dismiss) private var dismiss
    
    let entry: TimeEntry
    
    @State private var taskDescription: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isActive: Bool
    @State private var durationString: String = ""
    
    init(entry: TimeEntry) {
        self.entry = entry
        self._taskDescription = State(initialValue: entry.taskDescription)
        self._startTime = State(initialValue: entry.startTime)
        self._endTime = State(initialValue: entry.endTime ?? Date())
        self._isActive = State(initialValue: entry.isActive)
        
        self._durationString = State(initialValue: TimeEntry.formatDuration(entry.duration))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Time Entry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 15)
            
            Divider().opacity(0.5)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Task Description
                    VStack(alignment: .leading, spacing: 8) {
                        Label("DESCRIPTION", systemImage: "pencil.line")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("What are you working on?", text: $taskDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(AppTheme.Colors.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Time Range
                    VStack(alignment: .leading, spacing: 12) {
                        Label("TIME RANGE", systemImage: "clock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in updateDurationFromTimes() }
                                .padding(8)
                                .background(AppTheme.Colors.cardBackground)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in updateDurationFromTimes() }
                                .padding(8)
                                .background(isActive ? Color.secondary.opacity(0.05) : AppTheme.Colors.cardBackground)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        }
                        
                        DatePicker("Date", selection: $startTime, displayedComponents: .date)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
    
                   // Duration Section
                   VStack(alignment: .leading, spacing: 8) {
                       Label("DURATION", systemImage: "hourglass")
                           .font(.system(size: 10, weight: .bold))
                           .foregroundColor(.secondary)
                       
                       TextField("0:00:00", text: $durationString)
                           .textFieldStyle(.plain)
                           .font(.system(size: 20, weight: .medium, design: .monospaced))
                           .padding(12)
                           .background(AppTheme.Colors.cardBackground)
                           .cornerRadius(8)
                           .overlay(
                               RoundedRectangle(cornerRadius: 8)
                                   .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                           )
                           .onChange(of: durationString) { _, newValue in
                               updateTimesFromDuration()
                           }
                   }
                   
                   Toggle(isOn: $isActive) {
                       HStack {
                           Image(systemName: "timer")
                               .foregroundColor(isActive ? .blue : .secondary)
                           Text("Currently Active")
                               .font(.system(size: 13, weight: .medium))
                       }
                   }
                   .toggleStyle(.switch)
                   .scaleEffect(0.8)
                   .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            
            Divider().opacity(0.5)
            
            // Footer Buttons
            HStack(spacing: 12) {
                Button {
                    deleteEntry()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(AppTheme.Gradients.accentGradient)
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.secondary.opacity(0.02))
        }
        .frame(width: 380, height: 520)
        .background(AppTheme.Colors.background)
    }
    
    private func updateDurationFromTimes() {
        let duration = endTime.timeIntervalSince(startTime)
        durationString = TimeEntry.formatDuration(duration)
    }
    
    private func updateTimesFromDuration() {
        let components = durationString.split(separator: ":").compactMap { Double($0) }
        var totalSeconds: TimeInterval = 0
        
        if components.count == 3 {
            totalSeconds = components[0] * 3600 + components[1] * 60 + components[2]
        } else if components.count == 2 {
            totalSeconds = components[0] * 60 + components[1]
        } else if components.count == 1 {
            totalSeconds = components[0]
        }
        
        endTime = startTime.addingTimeInterval(totalSeconds)
    }
    
    private func saveChanges() {
        timerManager.updateTimer(
            entry,
            startTime: startTime,
            endTime: isActive ? nil : endTime,
            description: taskDescription
        )
        dismiss()
    }
    
    private func deleteEntry() {
        timerManager.deleteTimer(entry)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let entry = TimeEntry(taskDescription: "Sample Task")
    
    return EditTimeEntryView(entry: entry)
        .modelContainer(container)
} 
