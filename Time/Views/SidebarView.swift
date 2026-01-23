import SwiftUI
import SwiftData

struct SidebarView: View {
    let selectedDate: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Query(filter: #Predicate<Task> { $0.isActive == true }, sort: \Task.startTime) private var activeTasks: [Task]
    @Query(sort: \Task.startTime, order: .reverse) private var allTasks: [Task]

    private var selectedDayTasks: [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allTasks.filter { task in
            task.startTime >= startOfDay && task.startTime < endOfDay && !task.isActive
        }
    }

    private var groupedTasks: [String: [Task]] {
        Dictionary(grouping: selectedDayTasks) { $0.taskDescription }
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var tasksHeaderTitle: String {
        if isViewingToday {
            return "TODAY'S TASKS"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate).uppercased()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
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

                if !selectedDayTasks.isEmpty {
                    Section {
                        ForEach(groupedTasks.keys.sorted(), id: \.self) { taskName in
                            let tasks = groupedTasks[taskName]!.sorted { $0.startTime > $1.startTime }
                            if tasks.count > 1 {
                                TaskStackView(tasks: tasks)
                            } else {
                                CompletedTaskRow(task: tasks[0])
                            }
                        }
                    } header: {
                        Text(tasksHeaderTitle)
                            .appSectionHeader()
                            .padding(.vertical, AppTheme.Spacing.md)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(AppTheme.Surfaces.sidebar)
    }
}

/// An active task in the sidebar.
struct ActiveTaskRow: View {
    @Bindable var task: Task

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isHovering = false

    private var showingPopover: Bool {
        manager.popoverLocation == .sidebar(taskID: task.id)
    }

    var body: some View {
        let _ = manager.lastTick
        HStack(spacing: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.itemSpacing) {
                Text(task.taskDescription)
                    .font(AppTheme.Typography.rowPrimaryText())
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Circle()
                        .fill(AppTheme.Colors.activeTask)
                        .frame(width: 6, height: 6)
                        .symbolEffect(.pulse, value: manager.lastTick)
                        .offset(x: 1)

                    Text(task.formattedDuration)
                        .font(.system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.activeTask)
                        .symbolEffect(.pulse)
                }
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
                    .fill(AppTheme.Colors.accent.opacity(0.03))

                // Hover effect
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .fill(isHovering ? AppTheme.Colors.tertiaryFill : .clear)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.25), lineWidth: 1)
            )
            .appShadow(AppTheme.Shadows.active)
        )
        .animation(AppTheme.Animation.standard, value: isHovering)
        .onTapGesture {
            manager.openPopover(for: task, from: .sidebar(taskID: task.id))
            manager.selectTask(task)
        }
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
            Button("Duplicate") { manager.duplicateTask(task, undoManager: undoManager) }
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

                    // Hover effect
                    if isHovering {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.Colors.tertiaryFill)
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
            VStack(alignment: .leading, spacing: AppTheme.Spacing.itemSpacing) {
                Text(task.taskDescription)
                    .font(AppTheme.Typography.rowPrimaryText())
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(task.formattedDuration)
                    .font(.system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
                        .fill(isHovering ? AppTheme.Colors.tertiaryFill : AppTheme.Colors.cardBackground.opacity(0.5))
                } else {
                    // Card-like appearance for standalone tasks
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .strokeBorder(AppTheme.Colors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .appShadow(AppTheme.Shadows.soft)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .fill(isHovering ? AppTheme.Colors.tertiaryFill : .clear)
                        )
                }
            }
        )
        .animation(AppTheme.Animation.standard, value: isHovering)
        .onTapGesture {
            manager.openPopover(for: task, from: .sidebar(taskID: task.id))
            manager.selectTask(task)
        }
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
            Button("Duplicate") { manager.duplicateTask(task, undoManager: undoManager) }
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

