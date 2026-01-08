import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var timeEntries: [TimeEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = 60
    @State private var selectedEntry: TimeEntry?
    
    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Simpler predicate to fetch entries starting before the end of the day.
        // We will perform more precise overlap filtering in a computed property.
        let predicate = #Predicate<TimeEntry> { entry in
            entry.startTime < endOfDay
        }
        
        _timeEntries = Query(filter: predicate, sort: \TimeEntry.startTime)
    }
    
    // Computed property to handle precise overlap filtering in-memory.
    // This avoids complex SQL/Predicate macro issues.
    private var filteredTimeEntries: [TimeEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return timeEntries.filter { entry in
            let entryEnd = entry.endTime ?? Date.distantFuture
            return entryEnd >= startOfDay
        }
    }
    
    var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Background Grid
                        TimelineGrid(hourHeight: hourHeight)
                            .onTapGesture { location in
                                createEntryAt(location: location)
                            }
                        
                        // Entries (Using the filtered list)
                        EntryLayoutView(entries: filteredTimeEntries, hourHeight: hourHeight, date: date) { entry in
                            selectedEntry = entry
                        }
                        
                        // Current Time Indicator
                        if Calendar.current.isDateInToday(date) {
                            CurrentTimeIndicator(hourHeight: hourHeight)
                        }
                    }
                    .coordinateSpace(name: "timeline")
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 60) // Space for hour labels
                }
                .toolbar {
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Button { withAnimation { hourHeight = max(30, hourHeight - 10) } } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .disabled(hourHeight <= 30)
                        
                        Slider(value: $hourHeight, in: 30...200)
                            .frame(width: 80)
                        
                        Button { withAnimation { hourHeight = min(200, hourHeight + 10) } } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .disabled(hourHeight >= 200)
                        
                        Divider()
                        
                        Text("Total: \(totalTimeFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onAppear {
                    // Scroll to current hour or 08:00
                    let hour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(max(0, hour - 1), anchor: .top)
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            .sheet(item: $selectedEntry) { entry in
                    EditTimeEntryView(entry: entry)
                        .frame(minWidth: 400, minHeight: 450)
            }
        }
    
    private var totalTimeFormatted: String {
        // Use lastTick to ensure this re-calculates every second if there are active timers
        _ = timerManager.lastTick
        let totalSeconds = filteredTimeEntries.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func createEntryAt(location: CGPoint) {
        let hour = location.y / hourHeight
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Int(hour)
        components.minute = Int((hour.truncatingRemainder(dividingBy: 1)) * 60)
        
        if let startTime = calendar.date(from: components) {
            let newEntry = TimeEntry(taskDescription: "New Task", startTime: startTime)
            newEntry.endTime = startTime.addingTimeInterval(1800) // Default 30 mins
            modelContext.insert(newEntry)
            selectedEntry = newEntry
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
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 50, alignment: .trailing)
                        .offset(x: -55, y: -7)
                    
                    VStack(spacing: 0) {
                        Divider()
                            .opacity(0.3)
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
    @Environment(TimerManager.self) private var timerManager
    
    var body: some View {
        let now = timerManager.lastTick
        let calendar = Calendar.current
        let hour = CGFloat(calendar.component(.hour, from: now))
        let minute = CGFloat(calendar.component(.minute, from: now))
        let yOffset = (hour + minute / 60.0) * hourHeight
        
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .shadow(radius: 1)
                .offset(x: -3)
            
            Rectangle()
                .fill(.red)
                .frame(height: 1)
                .opacity(0.8)
        }
        .offset(y: yOffset - 0.5)
    }
}

struct EntryLayoutView: View {
    let entries: [TimeEntry]
    let hourHeight: CGFloat
    let date: Date
    let onSelect: (TimeEntry) -> Void
    
    var body: some View {
        // Force the layout to recalculate when any entry's time changes
        let _ = entries.map { ($0.startTime, $0.endTime) }
        let groupedEntries = calculateHorizontalLayout()
        
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(groupedEntries, id: \.entry.id) { layout in
                    TimeEntryBlock(
                        entry: layout.entry,
                        hourHeight: hourHeight,
                        date: date
                    )
                    .frame(width: geo.size.width * layout.widthPercent, height: calculateHeight(for: layout.entry))
                    .offset(x: geo.size.width * layout.offsetXPercent, y: calculateY(for: layout.entry))
                    .onTapGesture { 
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            onSelect(layout.entry)
                        }
                    }
                }
            }
        }
        .animation(.spring(), value: entries)
    }
    
    private func calculateY(for entry: TimeEntry) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let diff = entry.startTime.timeIntervalSince(startOfDay)
        return CGFloat(diff / 3600.0) * hourHeight
    }
    
    private func calculateHeight(for entry: TimeEntry) -> CGFloat {
        let duration = entry.duration
        return max(24, CGFloat(duration / 3600.0) * hourHeight)
    }
    
    private struct EntryLayout {
        let entry: TimeEntry
        let widthPercent: CGFloat
        let offsetXPercent: CGFloat
    }
    
    private func calculateHorizontalLayout() -> [EntryLayout] {
        guard !entries.isEmpty else { return [] }
        
        var layouts: [EntryLayout] = []
        var processedIds: Set<UUID> = []
        
        // Simple overlap grouping
        for entry in entries {
            if processedIds.contains(entry.id) { continue }
            
            // Find all entries that overlap with this one or each other in a chain
            var group = [entry]
            var changed = true
            while changed {
                changed = false
                for other in entries {
                    if !processedIds.contains(other.id) && !group.contains(where: { $0.id == other.id }) {
                        if group.contains(where: { $0.overlaps(with: other) }) {
                            group.append(other)
                            changed = true
                        }
                    }
                }
            }
            
            // Sort group by start time
            group.sort { $0.startTime < $1.startTime }
            
            // Assign columns
            var columns: [[TimeEntry]] = []
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
                    layouts.append(EntryLayout(
                        entry: item,
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

struct TimeEntryBlock: View {
    @Bindable var entry: TimeEntry
    let hourHeight: CGFloat
    let date: Date
    
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isResizing = false
    
    @State private var dragInitialStartTime: Date?
    @State private var dragInitialEndTime: Date?
    
    var body: some View {
        // Observe lastTick to refresh active timers
        let _ = entry.isActive ? timerManager.lastTick : .distantPast
        let baseColor = entry.isActive ? AppTheme.Colors.activeTimer : AppTheme.Colors.completedTimer
        
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(entry.taskDescription)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(2)
                
                Spacer()
                
                if entry.isActive {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                        .symbolEffect(.pulse)
                }
            }
            
            Text(entry.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .opacity(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.Gradients.activeGradient(for: baseColor))
                .shadow(color: Color.black.opacity(isDragging || isResizing ? 0.2 : 0.1), radius: isDragging || isResizing ? 4 : 2, x: 0, y: isDragging || isResizing ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .strokeBorder(baseColor.opacity(0.5), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if isDragging || isResizing {
                timeIndicatorLabel(date: entry.startTime, isTop: true)
            }
        }
        .overlay(alignment: .bottom) {
            if isDragging || isResizing {
                timeIndicatorLabel(date: entry.endTime ?? Date(), isTop: false)
            }
        }
        .contextMenu {
                Button("Edit") {
                    // Selection handled by parent tap
                }
                
                Button("Duplicate") {
                    duplicateEntry()
                }
                
                Divider()
                
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .cursor(isHovering ? .pointingHand : .arrow)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
                .onChanged { value in
                    if dragInitialStartTime == nil {
                        dragInitialStartTime = entry.startTime
                        dragInitialEndTime = entry.endTime ?? Date()
                    }
                    isDragging = true
                    updateTimeImmediate(offset: value.translation.height)
                }
                .onEnded { _ in
                    isDragging = false
                    dragInitialStartTime = nil
                    dragInitialEndTime = nil
                    try? modelContext.save()
                }
        )
        .overlay(alignment: .top) {
            resizeHandle(isTop: true)
                .offset(y: -10)
        }
        .overlay(alignment: .bottom) {
            resizeHandle(isTop: false)
                .offset(y: 10)
        }
    }
    
    private func timeIndicatorLabel(date: Date, isTop: Bool) -> some View {
        Text(formatTime(date))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(4)
            .offset(y: isTop ? -22 : 22)
            .zIndex(10)
            .allowsHitTesting(false) // CRITICAL: Prevent label from blocking mouse
    }
    
    @ViewBuilder
    private func resizeHandle(isTop: Bool) -> some View {
        ZStack {
            // Invisible larger hit area
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 20)
            
            // Visible indicator
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 4)
                .cornerRadius(2)
                .padding(.horizontal, 20)
                .opacity(isHovering || isResizing ? 1 : 0)
        }
        .contentShape(Rectangle())
        .cursor(.resizeUpDown)
        .highPriorityGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("timeline"))
                .onChanged { value in
                    if dragInitialStartTime == nil {
                        dragInitialStartTime = entry.startTime
                        dragInitialEndTime = entry.endTime ?? Date()
                    }
                    isResizing = true
                    if isTop {
                        updateStartTimeImmediate(offset: value.translation.height)
                    } else {
                        updateEndTimeImmediate(offset: value.translation.height)
                    }
                }
                .onEnded { _ in
                    isResizing = false
                    dragInitialStartTime = nil
                    dragInitialEndTime = nil
                    try? modelContext.save()
                }
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
    }
    
    private func duplicateEntry() {
        let newEntry = TimeEntry(taskDescription: entry.taskDescription, startTime: entry.startTime)
        newEntry.endTime = entry.endTime
        newEntry.isActive = false
        modelContext.insert(newEntry)
        try? modelContext.save()
    }
    
    private func calculateHeight() -> CGFloat {
        let duration = entry.duration
        return max(24, CGFloat(duration / 3600.0) * hourHeight)
    }
    
    private func updateTimeImmediate(offset: CGFloat) {
        let hourDiff = offset / hourHeight
        let timeDiff = hourDiff * 3600.0
        
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        
        let newStart = baseStart.addingTimeInterval(timeDiff)
        let snappedStart = snapToInterval(newStart)
        
        if snappedStart != entry.startTime {
            let duration = baseEnd.timeIntervalSince(baseStart)
            entry.startTime = snappedStart
            entry.endTime = snappedStart.addingTimeInterval(duration)
        }
    }
    
    private func updateStartTimeImmediate(offset: CGFloat) {
        let hourDiff = offset / hourHeight
        let timeDiff = hourDiff * 3600.0
        
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        
        let newStart = baseStart.addingTimeInterval(timeDiff)
        let snappedStart = snapToInterval(newStart)
        
        if snappedStart != entry.startTime {
            if snappedStart < baseEnd.addingTimeInterval(-300) {
                entry.startTime = snappedStart
            }
        }
    }
    
    private func updateEndTimeImmediate(offset: CGFloat) {
        let hourDiff = offset / hourHeight
        let timeDiff = hourDiff * 3600.0
        
        guard let baseEnd = dragInitialEndTime, let baseStart = dragInitialStartTime else { return }
        
        let newEnd = baseEnd.addingTimeInterval(timeDiff)
        let snappedEnd = snapToInterval(newEnd)
        
        if snappedEnd != entry.endTime {
            if snappedEnd > baseStart.addingTimeInterval(300) {
                entry.endTime = snappedEnd
                entry.isActive = false
            }
        }
    }
    
    private func snapToInterval(_ date: Date) -> Date {
        let interval: TimeInterval = 300 // 5 minutes
        let seconds = date.timeIntervalSince1970
        let snappedSeconds = round(seconds / interval) * interval
        return Date(timeIntervalSince1970: snappedSeconds)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    return DayView(date: Date())
        .modelContainer(container)
        .environment(manager)
}
