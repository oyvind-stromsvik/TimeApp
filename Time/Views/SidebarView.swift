import SwiftUI
import SwiftData

struct SidebarView: View {
    let selectedDate: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @Query(filter: #Predicate<Task> { $0.isActive == true }, sort: \Task.startTime) private var activeTasks: [Task]
    @Query(sort: \Task.startTime, order: .reverse) private var allTasks: [Task]
    @State private var newTaskDescription = ""

    private var selectedDayTasks: [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allTasks.filter { task in
            task.startTime >= startOfDay && task.startTime < endOfDay && !task.isActive
        }
    }

    private var trackedDayTasks: [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allTasks.filter { task in
            let taskEnd = task.endTime ?? .distantFuture
            return task.startTime < endOfDay && taskEnd >= startOfDay
        }
    }

    private struct TaskGroup: Identifiable {
        var id: String { name }
        let name: String
        let tasks: [Task]
        let mostRecentStartTime: Date
    }

    private var sortedTaskGroups: [TaskGroup] {
        let grouped = Dictionary(grouping: selectedDayTasks) { $0.taskDescription }
        return grouped.map { name, tasks in
            let sortedTasks = tasks.sorted { $0.startTime > $1.startTime }
            return TaskGroup(
                name: name,
                tasks: sortedTasks,
                mostRecentStartTime: sortedTasks.first?.startTime ?? .distantPast
            )
        }.sorted { $0.mostRecentStartTime > $1.mostRecentStartTime }
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var tasksHeaderTitle: String {
        if isViewingToday {
            return "TODAY"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate).uppercased()
        }
    }

    private var totalTimeFormatted: String {
        _ = manager.lastTick
        let totalSeconds = trackedDayTasks.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.Spacing.md) {
                TextField("What are you working on?", text: $newTaskDescription)
                    .textFieldStyle(.plain)
                    .appCardField(padding: AppTheme.Spacing.md, cornerRadius: AppTheme.CornerRadius.md)
                    .frame(maxWidth: .infinity)
                    .onSubmit(startTask)

                Button(action: startTask) {
                    AppCircleIcon(
                        systemName: "play.fill",
                        size: 28,
                        iconSize: 11,
                        background: AppTheme.Gradients.accentGradient
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Divider() }

            ScrollViewReader { proxy in
                List {
                    // Hidden top target for scrolling
                    Color.clear
                        .frame(height: 0)
                        .id("top")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)

                    if !activeTasks.isEmpty {
                    Section {
                        ForEach(activeTasks) { task in
                            ActiveTaskRow(task: task)
                        }
                    } header: {
                        Text("ACTIVE TASKS")
                            .appSectionHeader()
                            .padding(.vertical, AppTheme.Spacing.md)
                    }
                }
                else {
                    VStack(spacing: AppTheme.Spacing.xxl) {
                        Image(systemName: "timer")
                            .font(.system(size: AppTheme.Typography.largeTitle, weight: .ultraLight))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextFaint))
                        Text("No Active Tasks")
                            .font(AppTheme.Typography.emptyStateTitle())
                            .foregroundStyle(.secondary)
                        Text("Start a new task to begin tracking time.")
                            .font(AppTheme.Typography.rowSecondaryText())
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextStrong))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.huge)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Section {
                    ForEach(sortedTaskGroups) { group in
                        if group.tasks.count > 1 {
                            TaskStackView(tasks: group.tasks)
                        } else if let task = group.tasks.first {
                            CompletedTaskRow(task: task)
                        }
                    }
                } header: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Text(tasksHeaderTitle)
                            .appSectionHeader()

                        Spacer()

                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "clock")
                                .font(AppTheme.Typography.sectionHeader())
                                .foregroundStyle(.secondary)
                            Text(totalTimeFormatted)
                                .appSectionHeader()
                        }
                    }
                    .padding(.trailing, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .onChange(of: activeTasks) { _, _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
        .background(AppTheme.Surfaces.sidebar)
    }

    private func startTask() {
        let description = newTaskDescription.isEmpty ? "New task" : newTaskDescription
        manager.addNewTask(description: description, startTime: Date(), endTime: nil, isActive: true, undoManager: undoManager)
        newTaskDescription = ""
    }
}

private struct TaskInlineEditor<DurationLeading: View>: View {
    @Bindable var task: Task
    let durationColor: Color
    let durationFont: Font
    let allowDurationEdit: Bool
    let durationLeadingSpacing: CGFloat
    let durationLeading: () -> DurationLeading

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var descriptionDraft: String
    @State private var durationDraft: String
    @State private var descriptionSnapshot: String = ""
    @State private var durationSnapshot: TimeInterval = 0
    @State private var isDescriptionHovering = false
    @State private var isDurationHovering = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case description
        case duration
    }

    init(
        task: Task,
        durationColor: Color,
        durationFont: Font,
        allowDurationEdit: Bool = true,
        durationLeadingSpacing: CGFloat = AppTheme.Spacing.sm,
        @ViewBuilder durationLeading: @escaping () -> DurationLeading
    ) {
        self.task = task
        self.durationColor = durationColor
        self.durationFont = durationFont
        self.allowDurationEdit = allowDurationEdit
        self.durationLeadingSpacing = durationLeadingSpacing
        self.durationLeading = durationLeading
        _descriptionDraft = State(initialValue: task.taskDescription)
        _durationDraft = State(initialValue: task.formattedDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.itemSpacing) {
            TextField("", text: $descriptionDraft)
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.rowPrimaryText())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .focused($focusedField, equals: .description)
                .padding(.vertical, 1)
                .padding(.horizontal, 3)
                .background(fieldBackground(isHovering: isDescriptionHovering, isFocused: focusedField == .description))
                .contentShape(Rectangle())
                .onHover { hovering in
                    isDescriptionHovering = hovering
                }
                .cursor(.iBeam)
                .onSubmit {
                    focusedField = nil
                }

            HStack(spacing: durationLeadingSpacing) {
                durationLeading()

                TextField("", text: $durationDraft)
                    .textFieldStyle(.plain)
                    .font(durationFont)
                    .foregroundStyle(durationColor)
                    .focused($focusedField, equals: .duration)
                    .disabled(!allowDurationEdit)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 3)
                    .background(
                        fieldBackground(
                            isHovering: isDurationHovering,
                            isFocused: focusedField == .duration,
                            isDisabled: !allowDurationEdit
                        )
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isDurationHovering = allowDurationEdit && hovering
                    }
                    .cursor(allowDurationEdit ? .iBeam : .arrow)
                    .onSubmit {
                        focusedField = nil
                    }
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .description && newValue != .description {
                commitDescription()
            }
            if oldValue == .duration && newValue != .duration {
                commitDuration()
            }
            if newValue == .description {
                descriptionSnapshot = task.taskDescription
                descriptionDraft = task.taskDescription
            }
            if newValue == .duration {
                durationSnapshot = task.duration
                durationDraft = TaskDurationInput.format(durationSnapshot)
            }
        }
        .onChange(of: task.taskDescription) { _, newValue in
            guard focusedField != .description else { return }
            descriptionDraft = newValue
        }
        .onChange(of: task.startTime) { _, _ in
            refreshDurationDisplay()
        }
        .onChange(of: task.endTime) { _, _ in
            refreshDurationDisplay()
        }
        .onChange(of: task.isActive) { _, _ in
            refreshDurationDisplay()
        }
        .onChange(of: manager.lastTick) { _, _ in
            guard task.isActive else { return }
            refreshDurationDisplay()
        }
    }

    private func refreshDurationDisplay() {
        guard focusedField != .duration else { return }
        durationDraft = task.formattedDuration
    }

    private func commitDescription() {
        let trimmed = descriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            descriptionDraft = descriptionSnapshot
            return
        }

        guard descriptionDraft != task.taskDescription else { return }
        manager.updateTask(
            task,
            startTime: task.startTime,
            endTime: task.endTime,
            description: descriptionDraft,
            undoManager: undoManager
        )
    }

    private func commitDuration() {
        guard allowDurationEdit else {
            refreshDurationDisplay()
            return
        }

        let trimmed = durationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            durationDraft = TaskDurationInput.format(durationSnapshot)
            refreshDurationDisplay()
            return
        }

        guard let totalSeconds = TaskDurationInput.parse(trimmed) else {
            durationDraft = TaskDurationInput.format(durationSnapshot)
            refreshDurationDisplay()
            return
        }

        if task.isActive {
            let newStartTime = Date().addingTimeInterval(-totalSeconds)
            manager.updateTask(
                task,
                startTime: newStartTime,
                endTime: nil,
                description: task.taskDescription,
                undoManager: undoManager
            )
        } else {
            let newEndTime = task.startTime.addingTimeInterval(totalSeconds)
            manager.updateTask(
                task,
                startTime: task.startTime,
                endTime: newEndTime,
                description: task.taskDescription,
                undoManager: undoManager
            )
        }

        refreshDurationDisplay()
    }

    private func fieldBackground(isHovering: Bool, isFocused: Bool, isDisabled: Bool = false) -> some View {
        let isActive = (isHovering || isFocused) && !isDisabled
        return RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs)
            .fill(isActive ? AppTheme.Colors.tertiaryFill : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs)
                    .strokeBorder(AppTheme.Colors.separator.opacity(isActive ? 0.45 : 0), lineWidth: 0.5)
            )
            .animation(AppTheme.Animation.standard, value: isActive)
    }
}

/// An active task in the sidebar.
struct ActiveTaskRow: View {
    @Bindable var task: Task

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager

    private var showingPopover: Bool {
        manager.popoverLocation == .sidebar(taskID: task.id)
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xl) {
            TaskInlineEditor(
                task: task,
                durationColor: AppTheme.Colors.activeTask,
                durationFont: .system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced)
            ) {
                Circle()
                    .fill(AppTheme.Colors.activeTask)
                    .frame(width: 6, height: 6)
                    .symbolEffect(.pulse, value: manager.lastTick)
                    .offset(x: 1)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    manager.stopTask(task, undoManager: undoManager)
                }
            } label: {
                AppCircleIcon(
                    systemName: "stop.fill",
                    size: 26,
                    iconSize: 10,
                    background: AppTheme.Colors.destructive
                )
                .cursor(.pointingHand)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .background(
            ZStack {
                // Base card background
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .fill(AppTheme.Colors.cardBackground)

                // Subtle accent tint to highlight active state
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.accent.opacity(0.35), AppTheme.Colors.accent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.55), lineWidth: 1)
            )
            .appShadow(AppTheme.Shadows.active)
        )
        .popover(
            isPresented: Binding(
                get: { showingPopover },
                set: { if !$0 { manager.closePopover() } }
            ),
            arrowEdge: .trailing
        ) {
            EditTaskView(task: task, manager: manager)
                .presentationCompactAdaptation(.none)
        }
        .contextMenu {
            Button("Edit") {
                manager.openPopover(for: task, from: .sidebar(taskID: task.id))
                manager.selectTask(task)
            }
            Divider()
            Button("Delete", role: .destructive) { manager.deleteTask(task, undoManager: undoManager) }
        }
    }
}

/// A stack of tasks with the same name that can be expanded/collapsed.
struct TaskStackView: View {
    let tasks: [Task]

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isArrowHovering = false

    private var totalDuration: TimeInterval {
        tasks.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stack header (collapsed view)
            HStack(spacing: AppTheme.Spacing.xl) {
                // Expand/collapse button
                Button {
                    isExpanded.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isArrowHovering ? AppTheme.Colors.tertiaryFill : Color.clear)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .cursor(.pointingHand)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isArrowHovering = hovering
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.itemSpacing) {
                    HStack {
                        Text(tasks[0].taskDescription)
                            .font(AppTheme.Typography.rowPrimaryText())
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        // Stack count badge
                        Text("\(tasks.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.textSecondary.opacity(0.7))
                            )
                    }

                    Text(Task.formatDuration(totalDuration))
                        .font(.system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                if isHovering && !isExpanded {
                    Button {
                        manager.addNewTask(
                            description: tasks[0].taskDescription,
                            startTime: Date(),
                            endTime: nil,
                            isActive: true,
                            undoManager: undoManager
                        )
                    } label: {
                        AppCircleIcon(
                            systemName: "play.fill",
                            size: 26,
                            iconSize: 10,
                            background: AppTheme.Gradients.accentGradient
                        )
                        .cursor(.pointingHand)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .background(
                ZStack {
                    // Card background
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.Colors.cardBackground)

                    // Stack effect - show multiple layers when collapsed
                    if !isExpanded {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.Colors.cardBackground)
                            .offset(x: 0, y: -2)
                            .opacity(0.5)

                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.Colors.cardBackground)
                            .offset(x: 0, y: -4)
                            .opacity(0.25)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .strokeBorder(AppTheme.Colors.separator.opacity(0.5), lineWidth: 0.5)
            )
            .appShadow(AppTheme.Shadows.soft)
            .onHover { hovering in
                isHovering = hovering
            }

            // Expanded task list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        CompletedTaskRow(task: task, isInStack: true)
                    }
                }
            }
        }
    }
}

/// A completed task row in the sidebar.
struct CompletedTaskRow: View {
    @Bindable var task: Task
    var isInStack: Bool = false

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isHovering = false

    private var showingPopover: Bool {
        manager.popoverLocation == .sidebar(taskID: task.id)
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xl) {
            TaskInlineEditor(
                task: task,
                durationColor: AppTheme.Colors.textSecondary,
                durationFont: .system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced),
                durationLeadingSpacing: 0
            ) {
                EmptyView()
            }

            Spacer()

            if isHovering {
                Button {
                    manager.addNewTask(
                        description: task.taskDescription,
                        startTime: Date(),
                        endTime: nil,
                        isActive: true,
                        undoManager: undoManager
                    )
                } label: {
                    AppCircleIcon(
                        systemName: "play.fill",
                        size: 26,
                        iconSize: 10,
                        background: AppTheme.Gradients.accentGradient
                    )
                    .cursor(.pointingHand)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, isInStack ? AppTheme.Spacing.sm : AppTheme.Spacing.md)
        .padding(.horizontal, isInStack ? AppTheme.Spacing.md : AppTheme.Spacing.lg)
        .background(
            Group {
                if isInStack {
                    // Simple background for tasks in stack
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.Colors.cardBackground.opacity(0.5))
                } else {
                    // Card-like appearance for standalone tasks
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .strokeBorder(AppTheme.Colors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .appShadow(AppTheme.Shadows.soft)
                }
            }
        )
        .animation(AppTheme.Animation.standard, value: isHovering)
        .popover(
            isPresented: Binding(
                get: { showingPopover },
                set: { if !$0 { manager.closePopover() } }
            ),
            arrowEdge: .trailing
        ) {
            EditTaskView(task: task, manager: manager)
                .presentationCompactAdaptation(.none)
        }
        .onHover { hovering in
            withAnimation(AppTheme.Animation.standard) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Edit") {
                manager.openPopover(for: task, from: .sidebar(taskID: task.id))
                manager.selectTask(task)
            }
            Divider()
            Button("Delete", role: .destructive) { manager.deleteTask(task, undoManager: undoManager) }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let manager = AppManager(modelContext: container.mainContext)
    let today = Date()
    
    let start = today.addingTimeInterval(-3600)
    let task = Task(taskDescription: "Daily Standup", startTime: start, isActive: true)
    container.mainContext.insert(task)
    
    let start2 = today
    let task2 = Task(taskDescription: "Working on UI Previews", startTime: start2, isActive: true)
    container.mainContext.insert(task2)
    
    return SidebarView(selectedDate: today)
        .modelContainer(container)
        .environment(manager)
}
