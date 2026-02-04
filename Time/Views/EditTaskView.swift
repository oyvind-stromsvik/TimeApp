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
    @State private var previousEndTime: Date?
    @State private var durationSnapshot: TimeInterval = 0
    @FocusState private var isDurationFocused: Bool

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

        self._durationString = State(initialValue: TaskDurationInput.format(task.duration))

        self.originalDescription = task.taskDescription
        self.originalStartTime = task.startTime
        self.originalEndTime = task.endTime ?? Date()
        self.originalIsActive = task.isActive
    }

    private var hasUnsavedChanges: Bool {
        // For active tasks, ignore endTime since it's managed by the system (current time)
        let endTimeChanged = !isActive && !originalIsActive && abs(endTime.timeIntervalSince(originalEndTime)) > 1
        let trimmedDuration = durationString.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedDuration = TaskDurationInput.format(endTime.timeIntervalSince(startTime))
        let durationChanged = !isActive && trimmedDuration != formattedDuration
        
        return taskDescription != originalDescription ||
               abs(startTime.timeIntervalSince(originalStartTime)) > 1 ||
               endTimeChanged ||
               durationChanged ||
               isActive != originalIsActive
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits {
                VStack(spacing: AppTheme.Spacing.xxxl) {
                    // Task Description
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
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
                            .font(.system(size: AppTheme.Typography.headline))
                            .editTaskField()
                            .onSubmit(saveChanges)
                    }

                    // Duration & Time Range
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label("DURATION", systemImage: "clock")
                            .appSectionHeader()

                        HStack(spacing: AppTheme.Spacing.sm) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in
                                    updateDurationFromTimes()
                                }
                                .editTaskField(padding: AppTheme.Spacing.xs, disabledStyle: isActive)

                            TextField("0:00:00", text: $durationString)
                                .textFieldStyle(.plain)
                                .font(.system(size: AppTheme.Typography.headline, weight: .semibold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .frame(width: 88, height: 16)
                                .layoutPriority(1)
                                .disabled(isActive)
                                .editTaskField(padding: AppTheme.Spacing.md, disabledStyle: isActive)
                                .focused($isDurationFocused)
                                .onChange(of: isDurationFocused) { _, focused in
                                    if focused {
                                        durationSnapshot = endTime.timeIntervalSince(startTime)
                                    }
                                }
                                .onSubmit {
                                    commitDurationInput()
                                    saveChanges()
                                }

                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in
                                    updateDurationFromTimes()
                                }
                                .editTaskField(padding: AppTheme.Spacing.xs, disabledStyle: isActive)
                        }
                        .onKeyPress(.return) {
                            saveChanges()
                            return .handled
                        }
                    }

                    Toggle(isOn: $isActive) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(isActive ? AppTheme.Colors.accent : .secondary)
                            Text("Is active")
                                .font(AppTheme.Typography.rowPrimaryText())
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppTheme.Spacing.lg)
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
            .padding(AppTheme.Spacing.lg)
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
        .onChange(of: taskDescription) {
            guard manager.popoverLocation != .none else { return }
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: durationString) { _, _ in
            guard manager.popoverLocation != .none else { return }
            manager.hasUnsavedChanges = hasUnsavedChanges
        }
        .onChange(of: startTime) {
            guard manager.popoverLocation != .none else { return }
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: endTime) {
            guard manager.popoverLocation != .none else { return }
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: isActive) { _, newValue in
            guard manager.popoverLocation != .none else { return }
            if newValue {
                // Task is becoming active
                previousEndTime = endTime // Save current end time
                endTime = Date()
                updateDurationFromTimes()
            } else {
                // Task is becoming inactive
                if let prev = previousEndTime {
                    endTime = prev // Restore previous end time
                    updateDurationFromTimes() // Update duration to reflect restored end time
                } else if originalIsActive == false {
                    // Fallback to original end time if we don't have a previous one
                    // (e.g. if we started editing a non-active task)
                   endTime = originalEndTime
                   updateDurationFromTimes()
                }
            }
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onDisappear {
            clearPreview()
        }
    }
    
    private func updateDurationFromTimes() {
        if isDurationFocused {
            return
        }
        let duration = endTime.timeIntervalSince(startTime)
        durationString = TaskDurationInput.format(duration)
    }

    private func updatePreview() {
        manager.previewTaskState = AppManager.TaskSnapshot(
            id: task.id,
            taskDescription: taskDescription,
            startTime: startTime,
            endTime: isActive ? nil : endTime,
            isActive: isActive
        )
    }

    private func clearPreview() {
        manager.previewTaskState = nil
    }

    private func commitDurationInput() {
        let trimmed = durationString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            durationString = TaskDurationInput.format(durationSnapshot)
            endTime = startTime.addingTimeInterval(durationSnapshot)
            return
        }

        guard let totalSeconds = TaskDurationInput.parse(trimmed) else {
            durationString = TaskDurationInput.format(durationSnapshot)
            endTime = startTime.addingTimeInterval(durationSnapshot)
            return
        }

        endTime = startTime.addingTimeInterval(totalSeconds)
        durationString = TaskDurationInput.format(totalSeconds)
    }
    
    private func saveChanges() {
        if !isActive {
            let currentDuration = endTime.timeIntervalSince(startTime)
            let formattedCurrent = TaskDurationInput.format(currentDuration)
            if durationString.trimmingCharacters(in: .whitespacesAndNewlines) != formattedCurrent || isDurationFocused {
                commitDurationInput()
            }
        }
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

private struct EditTaskFieldModifier: ViewModifier {
    let padding: CGFloat
    let isDisabledStyle: Bool

    func body(content: Content) -> some View {
        let background = isDisabledStyle
            ? AppTheme.Colors.fieldDisabledBackground.opacity(0.8)
            : AppTheme.Colors.fieldDisabledBackground

        content
            .padding(padding)
            .background(background)
            .cornerRadius(AppTheme.CornerRadius.field)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field)
                    .stroke(AppTheme.Colors.fieldBorder.opacity(0.9), lineWidth: 1)
            )
    }
}

private extension View {
    func editTaskField(padding: CGFloat = AppTheme.Spacing.lg, disabledStyle: Bool = false) -> some View {
        modifier(EditTaskFieldModifier(padding: padding, isDisabledStyle: disabledStyle))
    }
}
