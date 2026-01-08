import SwiftUI
import SwiftData

struct EditTimeEntryView: View {
    @Environment(\.modelContext) private var modelContext
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
        
        let initialDuration = entry.duration
        let hours = Int(initialDuration) / 3600
        let minutes = Int(initialDuration) % 3600 / 60
        let seconds = Int(initialDuration) % 60
        self._durationString = State(initialValue: String(format: "%d:%02d:%02d", hours, minutes, seconds))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Close Button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            ScrollView {
                VStack {
                    // Task Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETAILS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("Task Description", text: $taskDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Time Range & Date
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in updateDurationFromTimes() }
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in updateDurationFromTimes() }
                        }
                        
                        DatePicker("", selection: $startTime, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.stepperField)
                            .frame(maxWidth: .infinity)
                    }
    
                   // Duration Section
                   VStack(alignment: .leading, spacing: 8) {
                       Text("DURATION")
                           .font(.system(size: 10, weight: .bold))
                           .foregroundColor(.secondary)
                       
                       TextField("0:00:00", text: $durationString)
                           .textFieldStyle(.plain)
                           .font(.system(size: 24, weight: .medium, design: .monospaced))
                           .padding(12)
                           .background(Color.secondary.opacity(0.05))
                           .cornerRadius(8)
                           .overlay(
                               RoundedRectangle(cornerRadius: 8)
                                   .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                           )
                           .onChange(of: durationString) { _, newValue in
                               updateTimesFromDuration()
                           }
                   }
                   
    
                 Toggle("Currently Active", isOn: $isActive).toggleStyle(.checkbox)
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Buttons
            HStack {
                Button(role: .destructive) {
                    deleteEntry()
                } label: {
                    Text("Delete")
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    saveChanges()
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.1))
        }
        .frame(width: 350, height: 500)
    }
    
    private func updateDurationFromTimes() {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        durationString = String(format: "%d:%02d:%02d", max(0, hours), max(0, minutes), max(0, seconds))
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
        entry.update(
            startTime: startTime,
            endTime: isActive ? nil : endTime,
            description: taskDescription
        )
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error)")
        }
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
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
