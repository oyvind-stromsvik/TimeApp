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
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Background Grid
                    TimelineGrid(hourHeight: hourHeight)
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
                        date: date
                    )

                    // Current Time Indicator
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(hourHeight: hourHeight)
                    }
                }
                .coordinateSpace(name: "timeline")
                .frame(maxWidth: .infinity)
                .padding(.leading, AppTheme.Timeline.leadingGutterWidth)
            }
            .background(AppTheme.Colors.background)
            .onAppear {
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, hour - AppTheme.Timeline.initialScrollHourOffset), anchor: .top)
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    let _ = manager.lastTick
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(totalTimeFormatted)
                        .font(.system(size: AppTheme.Typography.bodyEmphasized, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
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
    
    private var totalTimeFormatted: String {
        _ = manager.lastTick
        let totalSeconds = filteredTasks.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func createTaskAtPosition(location: CGPoint) {
        print("create task at \(location)")
        let hour = location.y / hourHeight
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Int(hour)
        let minute = Int((hour.truncatingRemainder(dividingBy: 1)) * 60)
        components.minute = (minute / AppTheme.Timing.snapMinutes) * AppTheme.Timing.snapMinutes

        if let startTime = calendar.date(from: components) {
            let endTime = startTime.addingTimeInterval(AppTheme.Timing.defaultNewTaskDuration)
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
