import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    let task: Task
    
    @State private var taskDescription: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isActive: Bool
    @State private var durationString: String = ""
    
    init(task: Task) {
        self.task = task
        self._taskDescription = State(initialValue: task.taskDescription)
        self._startTime = State(initialValue: task.startTime)
        self._endTime = State(initialValue: task.endTime ?? Date())
        self._isActive = State(initialValue: task.isActive)
        
        self._durationString = State(initialValue: Task.formatDuration(task.duration))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Task")
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
            .padding(10)
            
            Divider().opacity(0.5)
            
            ViewThatFits {
                VStack(spacing: 20) {
                    // Task Description
                    VStack(alignment: .leading, spacing: 5) {
                        Label("DESCRIPTION", systemImage: "pencil.line")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("What are you working on?", text: $taskDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(10)
                            .background(AppTheme.Colors.cardBackground)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Time Range
                    VStack(alignment: .leading, spacing: 5) {
                        Label("DURATION", systemImage: "clock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("0:00:00", text: $durationString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .padding(10)
                            .background(AppTheme.Colors.cardBackground)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                            .onChange(of: durationString) { _, newValue in
                                updateTimesFromDuration()
                            }
                        HStack(spacing: 10) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in updateDurationFromTimes() }
                                .padding(5)
                                .background(AppTheme.Colors.cardBackground)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in updateDurationFromTimes() }
                                .padding(5)
                                .background(isActive ? Color.secondary.opacity(0.05) : AppTheme.Colors.cardBackground)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        }
                    }
       
                    Toggle(isOn: $isActive) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(isActive ? .blue : .secondary)
                            Text("Is active")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
            }
            
            Divider().opacity(0.5)
            
            // Footer Buttons
            HStack(spacing: 50) {
                Button {
                    deleteTask()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(AppTheme.Gradients.accentGradient)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.02))
        }
        .frame(width: 300)
        .background(AppTheme.Colors.background)
    }
    
    private func updateDurationFromTimes() {
        let duration = endTime.timeIntervalSince(startTime)
        durationString = Task.formatDuration(duration)
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
        manager.updateTask(
            task,
            startTime: startTime,
            endTime: isActive ? nil : endTime,
            description: taskDescription
        )
        dismiss()
    }
    
    private func deleteTask() {
        manager.deleteTask(task)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    
    let task = Task(taskDescription: "Sample Task")
    container.mainContext.insert(task)
    
    let manager = AppManager(modelContext: container.mainContext)
    
    return EditTaskView(task: task)
        .modelContainer(container)
        .environment(manager)
}
