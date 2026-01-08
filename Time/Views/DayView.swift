import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = 64
    @State private var selectedTask: Task?
    
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
                                selectedTask = nil
                            } else {
                                createTaskAtPosition(location: location)
                            }
                        }
                    
                    // Tasks
                    TaskLayoutView(
                        tasks: filteredTasks,
                        hourHeight: hourHeight,
                        date: date,
                        selectedTask: $selectedTask
                    )
                    
                    // Current Time Indicator
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(hourHeight: hourHeight)
                    }
                }
                .coordinateSpace(name: "timeline")
                .frame(maxWidth: .infinity)
                .padding(.top, hourHeight)
                .padding(.leading, 64)
            }
            .toolbar {
                ToolbarItemGroup(placement: .secondaryAction) {
                    Button { withAnimation { hourHeight = max(40, hourHeight - 20) } } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(hourHeight <= 40)

                    Slider(value: $hourHeight, in: 40...240)
                        .frame(width: 100)
                    
                    Button { withAnimation { hourHeight = min(240, hourHeight + 20) } } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(hourHeight >= 240)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(totalTimeFormatted)
                    }
                }
            }
            .onAppear {
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, hour - 1), anchor: .top)
            }
        }
        .background(AppTheme.Colors.background)
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
        components.minute = (minute / 5) * 5
        
        if let startTime = calendar.date(from: components) {
            let endTime = startTime.addingTimeInterval(1800) // 30 minutes
            manager.addNewTask(description: "New Task", startTime: startTime, endTime: endTime, isActive: false)
        }
    }
}

struct TimelineGrid: View {
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(width: 50, alignment: .trailing)
                        .offset(x: -58, y: -7)
                    
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 1)
                            .offset(x: -50)
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
}

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    @Environment(AppManager.self) private var manager
    
    var body: some View {
        let now = manager.lastTick
        let calendar = Calendar.current
        let hour = CGFloat(calendar.component(.hour, from: now))
        let minute = CGFloat(calendar.component(.minute, from: now))
        let yOffset = (hour + minute / 60.0) * hourHeight
        
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .red.opacity(0.5), radius: 4)
                .offset(x: -4)
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.red, .red.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .offset(x: -6)
        }
        .offset(y: yOffset - 1)
        .zIndex(100)
    }
}

struct TaskLayoutView: View {
    let tasks: [Task]
    let hourHeight: CGFloat
    let date: Date
    @Binding var selectedTask: Task?
    
    var body: some View {
        let _ = tasks.map { ($0.startTime, $0.endTime) }
        let groupedTasks = calculateHorizontalLayout()
        
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(groupedTasks, id: \.task.id) { layout in
                    TaskBlock(
                        task: layout.task,
                        hourHeight: hourHeight,
                        date: date,
                        selectedTask: $selectedTask
                    )
                    .frame(width: geo.size.width * layout.widthPercent, height: calculateHeight(for: layout.task))
                    .offset(x: geo.size.width * layout.offsetXPercent, y: calculateY(for: layout.task))
                }
            }
        }
    }
    
    private func calculateY(for task: Task) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let diff = task.startTime.timeIntervalSince(startOfDay)
        return CGFloat(diff / 3600.0) * hourHeight
    }
    
    private func calculateHeight(for task: Task) -> CGFloat {
        let duration = task.duration
        return max(24, CGFloat(duration / 3600.0) * hourHeight)
    }
    
    private struct TaskLayout {
        let task: Task
        let widthPercent: CGFloat
        let offsetXPercent: CGFloat
    }
    
    private func calculateHorizontalLayout() -> [TaskLayout] {
        guard !tasks.isEmpty else { return [] }
        
        var layouts: [TaskLayout] = []
        var processedIds: Set<UUID> = []
        
        for task in tasks {
            if processedIds.contains(task.id) { continue }
            
            var group = [task]
            var changed = true
            while changed {
                changed = false
                for other in tasks {
                    if !processedIds.contains(other.id) && !group.contains(where: { $0.id == other.id }) {
                        if group.contains(where: { $0.overlaps(with: other) }) {
                            group.append(other)
                            changed = true
                        }
                    }
                }
            }
            
            group.sort { $0.startTime < $1.startTime }
            
            var columns: [[Task]] = []
            for item in group {
                var assigned = false
                for (index, col) in columns.enumerated() {
                    if !col.contains(where: { $0.overlaps(with: item) }) {
                        columns[index].append(item)
                        assigned = true
                        break
                    }
                }
                if !assigned {
                    columns.append([item])
                }
            }
            
            let columnCount = CGFloat(columns.count)
            for (colIndex, col) in columns.enumerated() {
                for item in col {
                    layouts.append(TaskLayout(
                        task: item,
                        widthPercent: 1.0 / columnCount,
                        offsetXPercent: CGFloat(colIndex) / columnCount
                    ))
                    processedIds.insert(item.id)
                }
            }
        }
        
        return layouts
    }
}

struct TaskBlock: View {
    @Bindable var task: Task
    let hourHeight: CGFloat
    let date: Date
    @Binding var selectedTask: Task?
    
    @Environment(AppManager.self) private var manager
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isResizing = false
    
    @State private var dragInitialStartTime: Date?
    @State private var dragInitialEndTime: Date?
    
    var body: some View {
        let _ = task.isActive ? manager.lastTick : .distantPast
        let baseColor = task.isActive ? AppTheme.Colors.activeTimer : AppTheme.Colors.completedTimer
        
        VStack(alignment: .leading, spacing: 2) {
            TaskContent(task: task)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    selectedTask = task
                }
        )
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.Gradients.activeGradient(for: baseColor))
                .shadow(color: Color.black.opacity(isDragging || isResizing ? 0.15 : 0.05), 
                        radius: isDragging || isResizing ? 8 : 2, 
                        y: isDragging || isResizing ? 4 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(task.id == selectedTask?.id ? AppTheme.Colors.accent : baseColor.opacity(0.3),
                        lineWidth: task.id == selectedTask?.id ? 2 : 1)
        )
        .shadow(color: task.id == selectedTask?.id ? AppTheme.Colors.accent.opacity(0.3) : .clear, radius: 4)
        .popover(item: Binding(
            get: { selectedTask?.id == task.id ? selectedTask : nil },
            set: { if $0 == nil { selectedTask = nil } }
        )) { task in
            EditTaskView(task: task)
        }
        .overlay(alignment: .top) {
            if isDragging || isResizing { TimeLabel(date: task.startTime, isTop: true) }
        }
        .overlay(alignment: .bottom) {
            if isDragging || isResizing { TimeLabel(date: task.endTime ?? Date(), isTop: false) }
        }
        .contextMenu {
            Button("Duplicate") { manager.duplicateTask(task) }
            Divider()
            Button("Delete", role: .destructive) { manager.deleteTask(task) }
        }
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering } }
        .cursor(isHovering ? .pointingHand : .arrow)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
                .onChanged { value in
                    if dragInitialStartTime == nil {
                        dragInitialStartTime = task.startTime
                        dragInitialEndTime = task.endTime ?? Date()
                    }
                    isDragging = true
                    updatePosition(offset: value.translation.height)
                }
                .onEnded { _ in
                    isDragging = false
                    dragInitialStartTime = nil
                    dragInitialEndTime = nil
                    manager.save()
                }
        )
        .overlay(alignment: .top) { 
            ResizeHandle(
                isTop: true, 
                isHovering: isHovering, 
                isResizing: $isResizing, 
                onResize: updateStartTime,
                onEnded: handleResizeEnded
            )
            .offset(y: -8)
        }
        .overlay(alignment: .bottom) { 
            ResizeHandle(
                isTop: false, 
                isHovering: isHovering, 
                isResizing: $isResizing, 
                onResize: updateEndTime,
                onEnded: handleResizeEnded
            )
            .offset(y: 8)
        }
    }
    
    private func handleResizeEnded() {
        isResizing = false
        dragInitialStartTime = nil
        dragInitialEndTime = nil
        manager.save()
    }
    
    private func updatePosition(offset: CGFloat) {
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let timeDiff = (offset / hourHeight) * 3600.0
        let newStart = snap(baseStart.addingTimeInterval(timeDiff))
        let duration = baseEnd.timeIntervalSince(baseStart)
        task.startTime = newStart
        task.endTime = newStart.addingTimeInterval(duration)
    }
    
    private func updateStartTime(offset: CGFloat) {
        if dragInitialStartTime == nil { dragInitialStartTime = task.startTime; dragInitialEndTime = task.endTime ?? Date() }
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let newStart = snap(baseStart.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newStart < baseEnd.addingTimeInterval(-300) { task.startTime = newStart }
    }
    
    private func updateEndTime(offset: CGFloat) {
        if dragInitialEndTime == nil { dragInitialEndTime = task.endTime ?? Date(); dragInitialStartTime = task.startTime }
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let newEnd = snap(baseEnd.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newEnd > baseStart.addingTimeInterval(300) { task.endTime = newEnd; task.isActive = false }
    }
    
    private func snap(_ date: Date) -> Date {
        let interval: TimeInterval = 300 // 5 mins
        return Date(timeIntervalSince1970: round(date.timeIntervalSince1970 / interval) * interval)
    }
}

struct TaskContent: View {
    let task: Task
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.taskDescription)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(task.formattedDuration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(task.isActive ? .blue : .secondary)
            }
            
            Spacer()
            
            if task.isActive {
                Image(systemName: "timer")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse)
            }
        }
    }
}

struct TimeLabel: View {
    let date: Date
    let isTop: Bool
    
    var body: some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(4)
            .offset(y: isTop ? -26 : 26)
            .zIndex(10)
    }
}

struct ResizeHandle: View {
    let isTop: Bool
    let isHovering: Bool
    @Binding var isResizing: Bool
    let onResize: (CGFloat) -> Void
    let onEnded: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(height: 16)
            .overlay(
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 32, height: 3)
                    .opacity(isHovering || isResizing ? 1 : 0)
            )
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                    .onChanged { value in
                        isResizing = true
                        onResize(value.translation.height)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { hovering in
            if hovering { cursor.push() } else { NSCursor.pop() }
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
