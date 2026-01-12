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
    @State private var selectedTask: Task?
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var popoverJustClosed = false

    @State private var showingCalendarPopover = false
    @State private var showingZoomPopover = false
    
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
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Background Grid
                        TimelineGrid(hourHeight: hourHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                if selectedTask != nil {
                                    if hasUnsavedChanges {
                                        showingDiscardAlert = true
                                    } else {
                                        withAnimation(.snappy(duration: 0.18)) {
                                            selectedTask = nil
                                        }
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
        .navigationTitle(formattedDateForTitlebar(date))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ViewThatFits {
                    HStack(spacing: 6) {
                        Button {
                            onDateChange(previousDay(from: date))
                        } label: {
                            Label("Previous Day", systemImage: "chevron.left")
                        }

                        Button {
                            onDateChange(nextDay(from: date))
                        } label: {
                            Label("Next Day", systemImage: "chevron.right")
                        }

                        Button {
                            onDateChange(Date())
                        } label: {
                            Text("Today")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .controlSize(.small)

                    Menu {
                        Button {
                            onDateChange(previousDay(from: date))
                        } label: {
                            Label("Previous Day", systemImage: "chevron.left")
                        }
                        Button {
                            onDateChange(nextDay(from: date))
                        } label: {
                            Label("Next Day", systemImage: "chevron.right")
                        }
                        Divider()
                        Button {
                            onDateChange(Date())
                        } label: {
                            Label("Today", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .help("Day navigation")
                }
            }

            ToolbarItem(placement: .principal) {
                Button {
                    showingCalendarPopover.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(formattedDateForHeader(date))
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingCalendarPopover, arrowEdge: .top) {
                    calendarPopover
                }
            }

            ToolbarItem(placement: .automatic) {
                ViewThatFits {
                    Button {
                        showingZoomPopover.toggle()
                    } label: {
                        Label("Zoom", systemImage: "magnifyingglass")
                    }
                    .help("Zoom timeline")
                    .popover(isPresented: $showingZoomPopover, arrowEdge: .top) {
                        zoomPopover
                    }

                    Menu {
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                hourHeight = max(AppTheme.Timeline.minHourHeight, hourHeight - AppTheme.Timeline.hourHeightStep)
                            }
                        } label: {
                            Label("Zoom Out", systemImage: "minus.magnifyingglass")
                        }
                        .disabled(hourHeight <= AppTheme.Timeline.minHourHeight)

                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                hourHeight = min(AppTheme.Timeline.maxHourHeight, hourHeight + AppTheme.Timeline.hourHeightStep)
                            }
                        } label: {
                            Label("Zoom In", systemImage: "plus.magnifyingglass")
                        }
                        .disabled(hourHeight >= AppTheme.Timeline.maxHourHeight)

                        Divider()

                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                hourHeight = AppTheme.Timeline.defaultHourHeight
                            }
                        } label: {
                            Label("Reset Zoom", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .help("Zoom timeline")
                }
            }

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
            withAnimation(.snappy(duration: 0.18)) {
                let newTask = manager.addNewTask(description: "New Task", startTime: startTime, endTime: endTime, isActive: false, undoManager: undoManager)
                selectedTask = newTask
            }
        }
    }

    private var calendarPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "",
                selection: Binding(
                    get: { date },
                    set: { newDate in
                        onDateChange(newDate)
                    }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Button("Close") { showingCalendarPopover = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Today") {
                    onDateChange(Date())
                    showingCalendarPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(.regularMaterial)
    }

    private var zoomPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Zoom")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        hourHeight = AppTheme.Timeline.defaultHourHeight
                    }
                } label: {
                    Text("Reset")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        hourHeight = max(AppTheme.Timeline.minHourHeight, hourHeight - AppTheme.Timeline.hourHeightStep)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(hourHeight <= AppTheme.Timeline.minHourHeight)

                Slider(value: $hourHeight, in: AppTheme.Timeline.minHourHeight...AppTheme.Timeline.maxHourHeight)
                    .frame(width: 180)

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        hourHeight = min(AppTheme.Timeline.maxHourHeight, hourHeight + AppTheme.Timeline.hourHeightStep)
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(hourHeight >= AppTheme.Timeline.maxHourHeight)
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(.regularMaterial)
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
