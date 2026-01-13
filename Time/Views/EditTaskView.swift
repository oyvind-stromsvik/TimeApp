import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    let task: Task
    let manager: AppManager

    @State private var taskDescription: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isActive: Bool
    @State private var durationString: String = ""
    @State private var showingDiscardAlert = false

    private let originalDescription: String
    private let originalStartTime: Date
    private let originalEndTime: Date
    private let originalIsActive: Bool

    init(task: Task, manager: AppManager) {
        self.task = task
        self.manager = manager
        self._taskDescription = State(initialValue: task.taskDescription)
        self._startTime = State(initialValue: task.startTime)
        self._endTime = State(initialValue: task.endTime ?? Date())
        self._isActive = State(initialValue: task.isActive)

        self._durationString = State(initialValue: Task.formatDuration(task.duration))

        self.originalDescription = task.taskDescription
        self.originalStartTime = task.startTime
        self.originalEndTime = task.endTime ?? Date()
        self.originalIsActive = task.isActive
    }

    private var hasUnsavedChanges: Bool {
        taskDescription != originalDescription ||
        abs(startTime.timeIntervalSince(originalStartTime)) > 1 ||
        abs(endTime.timeIntervalSince(originalEndTime)) > 1 ||
        isActive != originalIsActive
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits {
                VStack(spacing: 20) {
                    // Task Description
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label("DESCRIPTION", systemImage: "pencil.line")
                                .appSectionHeader()
                            
                            Spacer()
                            
                            // Close button
                            Button {
                                if hasUnsavedChanges {
                                    showingDiscardAlert = true
                                } else {
                                    manager.hasUnsavedChanges = false
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }

                        TextField("What are you working on?", text: $taskDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .appCardField(padding: 10, cornerRadius: 5)
                            .onSubmit(saveChanges)
                    }
                    
                    // Duration & Time Range
                    VStack(alignment: .leading, spacing: 5) {
                        Label("DURATION", systemImage: "clock")
                            .appSectionHeader()
                        
                        TextField("0:00:00", text: $durationString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .appCardField(padding: 10, cornerRadius: 5)
                            .onChange(of: durationString) { _, newValue in
                                updateTimesFromDuration()
                            }
                            .onSubmit(saveChanges)
                        HStack(spacing: 10) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in updateDurationFromTimes() }
                                .appCardField(padding: 5, cornerRadius: 5)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextMedium))
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in updateDurationFromTimes() }
                                .appCardField(padding: 5, cornerRadius: 5, disabledStyle: isActive)
                        }
                    }
       
                    Toggle(isOn: $isActive) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(isActive ? AppTheme.Colors.accent : .secondary)
                            Text("Is active")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
            }
            
            Divider().opacity(AppTheme.Opacity.divider)
            
            // Footer Buttons
            HStack {
                Button {
                    deleteTask()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundColor(.red)
                .buttonStyle(PressedButtonStyle())
                
                Spacer()
                
                Button {
                    saveChanges()
                } label: {
                    Text("Save")
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .padding(10)
            .background(AppTheme.Colors.footerBackground)
        }
        .frame(width: 300)
        .background(AppTheme.Colors.cardBackground)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                manager.hasUnsavedChanges = false
                dismiss()
            }
            Button("Save") {
                saveChanges()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Would you like to save or discard them?")
        }
        .onChange(of: taskDescription) { manager.hasUnsavedChanges = hasUnsavedChanges }
        .onChange(of: startTime) { manager.hasUnsavedChanges = hasUnsavedChanges }
        .onChange(of: endTime) { manager.hasUnsavedChanges = hasUnsavedChanges }
        .onChange(of: isActive) { manager.hasUnsavedChanges = hasUnsavedChanges }
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
            description: taskDescription,
            undoManager: undoManager
        )
        manager.hasUnsavedChanges = false
        dismiss()
    }
    
    private func deleteTask() {
        manager.deleteTask(task, undoManager: undoManager)
        dismiss()
    }
}

struct EditTaskViewPreview: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Task.self, configurations: config)

        let task = Task(taskDescription: "Sample Task")
        container.mainContext.insert(task)

        let manager = AppManager(modelContext: container.mainContext)

        return EditTaskView(task: task, manager: manager)
            .modelContainer(container)
            .environment(manager)
    }
}

#Preview {
    EditTaskViewPreview()
}
