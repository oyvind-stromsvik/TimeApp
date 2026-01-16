import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    let onDateChange: (Date) -> Void
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(AppManager.self) private var manager
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = AppTheme.Timeline.defaultHourHeight
    @State private var popoverJustClosed = false
    
    init(date: Date) {
        self.date = date
        self.onDateChange = { _ in }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<Task> { task in
            task.startTime < endOfDay
        }
        
        _tasks = Query(filter: predicate, sort: \Task.startTime)
    }

    init(date: Date, onDateChange: @escaping (Date) -> Void) {
        self.date = date
        self.onDateChange = onDateChange
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
            // Secondary Toolbar
            HStack(spacing: 20) {
                // Date Navigation
                HStack(spacing: 1) {
                    Button {
                        onDateChange(previousDay(from: date))
                    } label: {
                        Image(systemName: "chevron.left")
                            .imageScale(.medium)
                            .frame(width: 28, height: 26)
                    }
                    
                    Divider().frame(height: 16)
                    
                    Button {
                        onDateChange(Date())
                    } label: {
                        Text("Today")
                            .font(.system(size: 13, weight: .medium))
                            .frame(height: 26)
                            .padding(.horizontal, 8)
                    }

                    Divider().frame(height: 16)
                    
                    Button {
                        onDateChange(nextDay(from: date))
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .frame(width: 28, height: 26)
                    }
                }
                .buttonStyle(.borderless)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                
                Text(formattedDateForHeader(date))
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                // Zoom Controls
                HStack(spacing: 10) {
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
                        .frame(width: 100)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Divider() }

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
        }
        .background(AppTheme.Colors.background)
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 6) {
                    let _ = manager.lastTick
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(totalTimeFormatted)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .padding(.horizontal, 6)
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

    private func formattedDateForTitlebar(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
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
    
    return DayView(date: today)
        .modelContainer(container)
        .environment(manager)
}
