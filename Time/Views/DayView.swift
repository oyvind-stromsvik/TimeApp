import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    let onDateChange: (Date) -> Void
    @Binding var hourHeight: CGFloat
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(AppManager.self) private var manager

    @State private var popoverJustClosed = false
    @AppStorage("timelineLayoutMode") private var timelineLayoutMode: TimelineLayoutMode = .cards
    @State private var isZoomPopoverVisible = false

    init(date: Date, onDateChange: @escaping (Date) -> Void, hourHeight: Binding<CGFloat>) {
        self.date = date
        self.onDateChange = onDateChange
        self._hourHeight = hourHeight
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Task> { task in
            task.startTime < endOfDay
        }

        _tasks = Query(filter: predicate, sort: \Task.startTime)
    }
    
    private var filteredTasks: [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            let taskEnd = task.endTime ?? Date.distantFuture
            return taskEnd >= startOfDay
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            timelineToolbar

            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Background Grid
                        TimelineGrid(hourHeight: hourHeight, topOffset: hourHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                print("Timeline view tapped")
                                if manager.selectedTask != nil {
                                    print("has task, deselecting")
                                    manager.tryDeselectTask()
                                }
                                else {
                                    createTaskAtPosition(location: location)
                                }
                            }

                        // Tasks
                        TaskLayoutView(
                            tasks: filteredTasks,
                            hourHeight: hourHeight,
                            date: date,
                            useMinimumHeight: timelineLayoutMode.usesMinimumHeight,
                            topOffset: hourHeight
                        )

                        // Current Time Indicator
                        if Calendar.current.isDateInToday(date) {
                            CurrentTimeIndicator(hourHeight: hourHeight, topOffset: hourHeight)
                        }
                    }
                    .coordinateSpace(name: "timeline")
                    .frame(maxWidth: .infinity)
                    .padding(.leading, AppTheme.Timeline.leadingGutterWidth)
                    .padding(.trailing, AppTheme.Spacing.lg)
                }
                .background(AppTheme.Colors.background)
                .onAppear {
                    let hour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(max(0, hour - AppTheme.Timeline.initialScrollHourOffset), anchor: .top)
                }
            }
        }
        .onChange(of: manager.selectedTask) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                popoverJustClosed = true
                DispatchQueue.main.async {
                    popoverJustClosed = false
                }
            }
        }
        .unsavedChangesAlert(manager: manager)
    }

    private var timelineToolbar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.md) {
                HStack(spacing: 1) {
                    Button {
                        onDateChange(previousDay(from: date))
                    } label: {
                        Image(systemName: "chevron.left")
                            .imageScale(.medium)
                            .frame(width: 26, height: 24)
                    }

                    Divider().frame(height: AppTheme.Spacing.xxl)

                    Button {
                        onDateChange(Date())
                    } label: {
                        Text("Today")
                            .font(AppTheme.Typography.rowPrimaryText())
                            .frame(height: 24)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    }

                    Divider().frame(height: AppTheme.Spacing.xxl)

                    Button {
                        onDateChange(nextDay(from: date))
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .frame(width: 26, height: 24)
                    }
                }
                .buttonStyle(.borderless)
                .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md).fill(Color.secondary.opacity(0.1)))

                Text(formattedDateForHeader(date))
                    .font(.system(size: AppTheme.Typography.callout))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                ForEach(TimelineLayoutMode.allCases) { mode in
                    Button {
                        timelineLayoutMode = mode
                    } label: {
                        Image(systemName: mode.iconName)
                            .font(.system(size: AppTheme.Typography.callout, weight: .semibold))
                            .foregroundStyle(
                                timelineLayoutMode == mode
                                    ? AppTheme.Colors.textPrimary
                                    : AppTheme.Colors.textSecondary
                            )
                            .frame(width: 32, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .fill(timelineLayoutMode == mode ? AppTheme.Colors.tertiaryFill : .clear)
                    )
                    .accessibilityLabel(mode.label)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(AppTheme.Colors.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.separator.opacity(0.6), lineWidth: 1)
            )

            Button {
                isZoomPopoverVisible.toggle()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: AppTheme.Typography.callout, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(AppTheme.Colors.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.separator.opacity(0.6), lineWidth: 1)
            )
            .popover(isPresented: $isZoomPopoverVisible, arrowEdge: .top) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            hourHeight = max(AppTheme.Timeline.minHourHeight, hourHeight - AppTheme.Timeline.hourHeightStep)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(hourHeight <= AppTheme.Timeline.minHourHeight)

                    Slider(value: $hourHeight, in: AppTheme.Timeline.minHourHeight...AppTheme.Timeline.maxHourHeight)
                        .frame(width: 120)
                        .controlSize(.mini)

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            hourHeight = min(AppTheme.Timeline.maxHourHeight, hourHeight + AppTheme.Timeline.hourHeightStep)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(hourHeight >= AppTheme.Timeline.maxHourHeight)
                }
                .padding(AppTheme.Spacing.md)
                .frame(width: 220)
            }
        }
        .padding(.leading, AppTheme.Spacing.lg)
        .padding(.trailing, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm + 1)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }
    
    private func createTaskAtPosition(location: CGPoint) {
        print("create task at \(location)")
        // Subtract hourHeight because we added it as top padding
        let hour = (location.y - hourHeight) / hourHeight
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Int(hour)
        let minute = Int((hour.truncatingRemainder(dividingBy: 1)) * 60)
        components.minute = (minute / manager.timeStepMinutes) * manager.timeStepMinutes

        if let startTime = calendar.date(from: components) {
            let endTime = startTime.addingTimeInterval(manager.defaultNewTaskDuration)
            manager.createTask(
                description: "New Task",
                startTime: startTime,
                endTime: endTime,
                isActive: false,
                selectAfterCreation: true,
                undoManager: undoManager
            )
        }
    }

    private func previousDay(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
    }

    private func nextDay(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private func formattedDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter.string(from: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let manager = AppManager(modelContext: container.mainContext)
    let today = Date()
    
    let start1 = today.addingTimeInterval(-12000)
    let end1 = today.addingTimeInterval(-8000)
    let task1 = Task(taskDescription: "Morning Standup & Planning", startTime: start1, isActive: false)
    task1.endTime = end1
    container.mainContext.insert(task1)
    
    let start2 = today.addingTimeInterval(-7200)
    let end2 = today.addingTimeInterval(-3600)
    let task2 = Task(taskDescription: "UI Design Refinement", startTime: start2, isActive: false)
    task2.endTime = end2
    container.mainContext.insert(task2)
    
    let start3 = today.addingTimeInterval(-1800)
    let task3 = Task(taskDescription: "Implementing Previews", startTime: start3, isActive: true)
    container.mainContext.insert(task3)
    
    return PreviewWrapper(manager: manager, container: container, today: today)
}

private struct PreviewWrapper: View {
    let manager: AppManager
    let container: ModelContainer
    let today: Date
    @State private var hourHeight: CGFloat = AppTheme.Timeline.defaultHourHeight

    var body: some View {
        DayView(date: today, onDateChange: { _ in }, hourHeight: $hourHeight)
            .modelContainer(container)
            .environment(manager)
    }
}

private enum TimelineLayoutMode: String, CaseIterable, Identifiable {
    case cards
    case actual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cards:
            return "Cards"
        case .actual:
            return "Actual"
        }
    }

    var iconName: String {
        switch self {
        case .cards:
            return "rectangle.grid.1x2"
        case .actual:
            return "list.bullet.rectangle"
        }
    }

    var usesMinimumHeight: Bool {
        self == .cards
    }
}
