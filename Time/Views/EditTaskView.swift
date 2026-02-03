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

        self._durationString = State(initialValue: Self.formatDurationForInput(task.duration))

        self.originalDescription = task.taskDescription
        self.originalStartTime = task.startTime
        self.originalEndTime = task.endTime ?? Date()
        self.originalIsActive = task.isActive
    }

    private var hasUnsavedChanges: Bool {
        // For active tasks, ignore endTime since it's managed by the system (current time)
        let endTimeChanged = !isActive && !originalIsActive && abs(endTime.timeIntervalSince(originalEndTime)) > 1
        
        return taskDescription != originalDescription ||
               abs(startTime.timeIntervalSince(originalStartTime)) > 1 ||
               endTimeChanged ||
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
                            .appCardField()
                            .onSubmit(saveChanges)
                    }

                    // Duration & Time Range
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label("DURATION", systemImage: "clock")
                            .appSectionHeader()

                        TextField("0:00:00", text: $durationString)
                            .textFieldStyle(.plain)
                            .font(AppTheme.Typography.durationDisplay())
                            .disabled(isActive)
                            .appCardField(disabledStyle: isActive)
                            .focused($isDurationFocused)
                            .onChange(of: isDurationFocused) { _, focused in
                                if focused {
                                    durationSnapshot = endTime.timeIntervalSince(startTime)
                                } else {
                                    commitDurationInput()
                                }
                            }
                            .onSubmit {
                                commitDurationInput()
                                saveChanges()
                            }
                        HStack(spacing: AppTheme.Spacing.lg) {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .onChange(of: startTime) { _, _ in updateDurationFromTimes() }
                                .appCardField(padding: AppTheme.Spacing.xs, disabledStyle: isActive)

                            Image(systemName: "arrow.right")
                                .font(.system(size: AppTheme.Typography.callout, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextMedium))

                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.stepperField)
                                .frame(maxWidth: .infinity)
                                .disabled(isActive)
                                .onChange(of: endTime) { _, _ in updateDurationFromTimes() }
                                .appCardField(padding: AppTheme.Spacing.xs, disabledStyle: isActive)
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
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: startTime) {
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: endTime) {
            manager.hasUnsavedChanges = hasUnsavedChanges
            updatePreview()
        }
        .onChange(of: isActive) { _, newValue in
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
        durationString = Self.formatDurationForInput(duration)
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
            durationString = Self.formatDurationForInput(durationSnapshot)
            endTime = startTime.addingTimeInterval(durationSnapshot)
            return
        }

        guard let totalSeconds = parseDurationInput(trimmed) else {
            durationString = Self.formatDurationForInput(durationSnapshot)
            endTime = startTime.addingTimeInterval(durationSnapshot)
            return
        }

        endTime = startTime.addingTimeInterval(totalSeconds)
        durationString = Self.formatDurationForInput(totalSeconds)
    }

    private func parseDurationInput(_ input: String) -> TimeInterval? {
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ":"))
        guard input.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return nil
        }

        let parts = input.split(separator: ":", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 3 else {
            return nil
        }

        var values: [Int] = []
        for part in parts {
            guard !part.isEmpty, let value = Int(part), value >= 0 else {
                return nil
            }
            values.append(value)
        }

        switch values.count {
        case 1:
            return TimeInterval(values[0] * 60)
        case 2:
            return TimeInterval(values[0] * 3600 + values[1] * 60)
        case 3:
            return TimeInterval(values[0] * 3600 + values[1] * 60 + values[2])
        default:
            return nil
        }
    }

    private static func formatDurationForInput(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(max(0, duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
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
