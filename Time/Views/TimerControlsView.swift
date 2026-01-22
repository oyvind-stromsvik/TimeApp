import SwiftUI
import SwiftData

struct TimerControlsView: View {
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
                            ActiveTimerRow(task: task)
                        }
                    } header: {
                        Text("ACTIVE TIMERS")
                            .appSectionHeader()
                            .padding(.vertical, AppTheme.Spacing.md)
                    }
                }
                else {
                    VStack(spacing: AppTheme.Spacing.xxl) {
                        Image(systemName: "timer")
                            .font(.system(size: AppTheme.Typography.largeTitle, weight: .ultraLight))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextFaint))


                        Text("No Active Timers")
                            .font(AppTheme.Typography.emptyStateTitle())
                            .foregroundStyle(.secondary)
                        Text("Start a new timer to begin tracking time.")
                            .font(AppTheme.Typography.rowSecondaryText())
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextStrong))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.huge)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if !selectedDayTasks.isEmpty {
                    Section {
                        ForEach(selectedDayTasks) { task in
                            CompletedTaskRow(task: task)
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

/// An active task/timer in the sidebar.
struct ActiveTimerRow: View {
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
                        .fill(AppTheme.Colors.activeTimer)
                        .frame(width: 6, height: 6)
                        .symbolEffect(.pulse, value: manager.lastTick)
                        .offset(x: 1)

                    Text(task.formattedDuration)
                        .font(.system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.activeTimer)
                        .symbolEffect(.pulse)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    manager.stopTimer(task, undoManager: undoManager)
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
        .taskRowStyle(isHovering: isHovering)
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
            isHovering = hovering
        }
    }
}

/// A completed task row in the sidebar.
struct CompletedTaskRow: View {
    @Bindable var task: Task

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isHovering = false

    private var showingPopover: Bool {
        manager.popoverLocation == .sidebar(taskID: task.id)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: task.startTime)
        if let end = task.endTime {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        }
        return start
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.itemSpacing) {
                Text(task.taskDescription)
                    .font(AppTheme.Typography.rowPrimaryText())
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(timeRange)
                        .font(.system(size: AppTheme.Typography.body, weight: .regular, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Text("•")
                        .font(.system(size: AppTheme.Typography.body))
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Text(task.formattedDuration)
                        .font(.system(size: AppTheme.Typography.body, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
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
                .transition(.scale.combined(with: .opacity))
            }
        }
        .taskRowStyle(isHovering: isHovering)
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
            isHovering = hovering
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
    
    return TimerControlsView(selectedDate: today)
        .modelContainer(container)
        .environment(manager)
}

