import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var timeEntries: [TimeEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = 64
    @State private var selectedEntry: TimeEntry?
    
    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<TimeEntry> { entry in
            entry.startTime < endOfDay
        }
        
        _timeEntries = Query(filter: predicate, sort: \TimeEntry.startTime)
    }
    
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
                    
                    // Entries
                    EntryLayoutView(
                        entries: filteredTimeEntries,
                        hourHeight: hourHeight,
                        date: date,
                        selectedEntry: $selectedEntry
                    )
                    
                    // Current Time Indicator
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(hourHeight: hourHeight)
                    }
                }
                .coordinateSpace(name: "timeline")
                .frame(maxWidth: .infinity)
                .padding(.leading, 64)
            }
            .toolbar {
                ToolbarItemGroup(placement: .secondaryAction) {
                    Button { withAnimation { hourHeight = max(40, hourHeight - 12) } } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(hourHeight <= 40)
                    
                    Slider(value: $hourHeight, in: 40...240)
                        .frame(width: 100)
                    
                    Button { withAnimation { hourHeight = min(240, hourHeight + 12) } } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(hourHeight >= 240)
                    
                    Divider()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "sum")
                            .font(.caption2)
                        Text(totalTimeFormatted)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
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
            let endTime = startTime.addingTimeInterval(1800) // 30 minutes
            timerManager.addEntry(description: "New Task", startTime: startTime, endTime: endTime, isActive: false)
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
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .red.opacity(0.3), radius: 4)
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
        }
        .offset(y: yOffset - 1)
        .zIndex(100)
    }
}

struct EntryLayoutView: View {
    let entries: [TimeEntry]
    let hourHeight: CGFloat
    let date: Date
    @Binding var selectedEntry: TimeEntry?
    
    var body: some View {
        let _ = entries.map { ($0.startTime, $0.endTime) }
        let groupedEntries = calculateHorizontalLayout()
        
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(groupedEntries, id: \.entry.id) { layout in
                    TimeEntryBlock(
                        entry: layout.entry,
                        hourHeight: hourHeight,
                        date: date,
                        selectedEntry: $selectedEntry
                    )
                    .frame(width: geo.size.width * layout.widthPercent, height: calculateHeight(for: layout.entry))
                    .offset(x: geo.size.width * layout.offsetXPercent, y: calculateY(for: layout.entry))
                }
            }
        }
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
        
        for entry in entries {
            if processedIds.contains(entry.id) { continue }
            
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
            
            group.sort { $0.startTime < $1.startTime }
            
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
    @Binding var selectedEntry: TimeEntry?
    
    @Environment(TimerManager.self) private var timerManager
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isResizing = false
    
    @State private var dragInitialStartTime: Date?
    @State private var dragInitialEndTime: Date?
    
    var body: some View {
        let _ = entry.isActive ? timerManager.lastTick : .distantPast
        let baseColor = entry.isActive ? AppTheme.Colors.activeTimer : AppTheme.Colors.completedTimer
        
        VStack(alignment: .leading, spacing: 2) {
            EntryContent(entry: entry)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    selectedEntry = entry
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
                .strokeBorder(baseColor.opacity(0.3), lineWidth: 1)
        )
        .popover(item: Binding(
            get: { selectedEntry?.id == entry.id ? selectedEntry : nil },
            set: { if $0 == nil { selectedEntry = nil } }
        )) { entry in
            EditTimeEntryView(entry: entry)
        }
        .overlay(alignment: .top) {
            if isDragging || isResizing { TimeLabel(date: entry.startTime, isTop: true) }
        }
        .overlay(alignment: .bottom) {
            if isDragging || isResizing { TimeLabel(date: entry.endTime ?? Date(), isTop: false) }
        }
        .contextMenu {
            Button("Duplicate") { timerManager.duplicateTimer(entry) }
            Divider()
            Button("Delete", role: .destructive) { timerManager.deleteTimer(entry) }
        }
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering } }
        .cursor(isHovering ? .pointingHand : .arrow)
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
                .onChanged { value in
                    if dragInitialStartTime == nil {
                        dragInitialStartTime = entry.startTime
                        dragInitialEndTime = entry.endTime ?? Date()
                    }
                    isDragging = true
                    updatePosition(offset: value.translation.height)
                }
                .onEnded { _ in
                    isDragging = false
                    dragInitialStartTime = nil
                    dragInitialEndTime = nil
                    timerManager.save()
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
        }
        .overlay(alignment: .bottom) { 
            ResizeHandle(
                isTop: false, 
                isHovering: isHovering, 
                isResizing: $isResizing, 
                onResize: updateEndTime,
                onEnded: handleResizeEnded
            ) 
        }
    }
    
    private func handleResizeEnded() {
        isResizing = false
        dragInitialStartTime = nil
        dragInitialEndTime = nil
        timerManager.save()
    }
    
    private func updatePosition(offset: CGFloat) {
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let timeDiff = (offset / hourHeight) * 3600.0
        let newStart = snap(baseStart.addingTimeInterval(timeDiff))
        let duration = baseEnd.timeIntervalSince(baseStart)
        entry.startTime = newStart
        entry.endTime = newStart.addingTimeInterval(duration)
    }
    
    private func updateStartTime(offset: CGFloat) {
        if dragInitialStartTime == nil { dragInitialStartTime = entry.startTime; dragInitialEndTime = entry.endTime ?? Date() }
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let newStart = snap(baseStart.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newStart < baseEnd.addingTimeInterval(-300) { entry.startTime = newStart }
    }
    
    private func updateEndTime(offset: CGFloat) {
        if dragInitialEndTime == nil { dragInitialEndTime = entry.endTime ?? Date(); dragInitialStartTime = entry.startTime }
        guard let baseStart = dragInitialStartTime, let baseEnd = dragInitialEndTime else { return }
        let newEnd = snap(baseEnd.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newEnd > baseStart.addingTimeInterval(300) { entry.endTime = newEnd; entry.isActive = false }
    }
    
    private func snap(_ date: Date) -> Date {
        let interval: TimeInterval = 300 // 5 mins
        return Date(timeIntervalSince1970: round(date.timeIntervalSince1970 / interval) * interval)
    }
}

struct EntryContent: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskDescription)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(entry.formattedDuration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(entry.isActive ? .blue : .secondary)
            }
            
            Spacer()
            
            if entry.isActive {
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
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    return DayView(date: Date())
        .modelContainer(container)
        .environment(manager)
}
