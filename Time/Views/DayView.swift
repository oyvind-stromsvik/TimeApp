import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(AppManager.self) private var manager
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = AppTheme.Timeline.defaultHourHeight
    @State private var selectedTask: Task?
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var popoverJustClosed = false
    
    init(date: Date) {
        self.date = date
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
                        .onTapGesture { location in
                            if selectedTask != nil {
                                if hasUnsavedChanges {
                                    showingDiscardAlert = true
                                } else {
                                    selectedTask = nil
                                }
                            } else if !popoverJustClosed {
                                createTaskAtPosition(location: location)
                            }
                        }
                    
                    // Tasks
                    TaskLayoutView(
                        tasks: filteredTasks,
                        hourHeight: hourHeight,
                        date: date,
                        selectedTask: $selectedTask,
                        hasUnsavedChanges: $hasUnsavedChanges
                    )
                    
                    // Current Time Indicator
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(hourHeight: hourHeight)
                    }
                }
                .coordinateSpace(name: "timeline")
                .frame(maxWidth: .infinity)
                .padding(.top, hourHeight)
                .padding(.leading, AppTheme.Timeline.leadingGutterWidth)
            }
            .toolbar {
                ToolbarItemGroup(placement: .secondaryAction) {
                    Button { withAnimation { hourHeight = max(AppTheme.Timeline.minHourHeight, hourHeight - AppTheme.Timeline.hourHeightStep) } } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(hourHeight <= AppTheme.Timeline.minHourHeight)

                    Slider(value: $hourHeight, in: AppTheme.Timeline.minHourHeight...AppTheme.Timeline.maxHourHeight)
                        .frame(width: 100)
                    
                    Button { withAnimation { hourHeight = min(AppTheme.Timeline.maxHourHeight, hourHeight + AppTheme.Timeline.hourHeightStep) } } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(hourHeight >= AppTheme.Timeline.maxHourHeight)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(totalTimeFormatted)
                    }
                }
            }
            .onAppear {
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, hour - AppTheme.Timeline.initialScrollHourOffset), anchor: .top)
            }
        }
        .background(AppTheme.Colors.background)
        .onChange(of: selectedTask) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                popoverJustClosed = true
                DispatchQueue.main.async {
                    popoverJustClosed = false
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                hasUnsavedChanges = false
                selectedTask = nil
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to discard them?")
        }
    }
    
    private var totalTimeFormatted: String {
        _ = manager.lastTick
        let totalSeconds = filteredTasks.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func createTaskAtPosition(location: CGPoint) {
        let hour = location.y / hourHeight
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Int(hour)
        let minute = Int((hour.truncatingRemainder(dividingBy: 1)) * 60)
        components.minute = (minute / AppTheme.Timing.snapMinutes) * AppTheme.Timing.snapMinutes

        if let startTime = calendar.date(from: components) {
            let endTime = startTime.addingTimeInterval(AppTheme.Timing.defaultNewTaskDuration)
            let newTask = manager.addNewTask(description: "New Task", startTime: startTime, endTime: endTime, isActive: false, undoManager: undoManager)
            selectedTask = newTask
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
    
    return DayView(date: today)
        .modelContainer(container)
        .environment(manager)
}
