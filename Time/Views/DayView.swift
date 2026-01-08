import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var timeEntries: [TimeEntry]
    @Environment(\.modelContext) private var modelContext
    
    // Zoom/Scale: Height of one hour in points
    @State private var hourHeight: CGFloat = 60
    @State private var selectedEntry: TimeEntry?
    @State private var showingEditSheet = false
    
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
                            showingEditSheet = true
                        }
                        
                        // Current Time Indicator
                        if Calendar.current.isDateInToday(date) {
                            CurrentTimeIndicator(hourHeight: hourHeight)
                        }
                    }
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
            .sheet(isPresented: $showingEditSheet) {
                if let entry = selectedEntry {
                    EditTimeEntryView(entry: entry)
                        .frame(minWidth: 400, minHeight: 450)
                }
            }
        }
    
    private var totalTimeFormatted: String {
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
            modelContext.insert(newEntry)
            selectedEntry = newEntry
            showingEditSheet = true
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
    @State private var now = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
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
        .onReceive(timer) { _ in now = Date() }
    }
}

struct EntryLayoutView: View {
    let entries: [TimeEntry]
    let hourHeight: CGFloat
    let date: Date
    let onSelect: (TimeEntry) -> Void
    
    var body: some View {
        let groupedEntries = calculateHorizontalLayout()
        
        ZStack(alignment: .topLeading) {
            ForEach(groupedEntries, id: \.entry.id) { layout in
                TimeEntryBlock(
                    entry: layout.entry,
                    hourHeight: hourHeight,
                    date: date,
                    widthPercent: layout.widthPercent,
                    offsetXPercent: layout.offsetXPercent
                )
                .onTapGesture { 
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        onSelect(layout.entry)
                    }
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity))
            }
        }
        .animation(.spring(), value: entries)
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
    let widthPercent: CGFloat
    let offsetXPercent: CGFloat
    
    @Environment(\.modelContext) private var modelContext
    @State private var dragOffset: CGFloat = 0
    @State private var resizeOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let y = calculateY()
            let h = calculateHeight()
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
            .frame(width: geo.size.width * widthPercent, height: h + resizeOffset)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(AppTheme.Gradients.activeGradient(for: baseColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .strokeBorder(baseColor.opacity(0.5), lineWidth: 1)
            )
            .offset(x: geo.size.width * offsetXPercent, y: y + dragOffset)
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        updateTime(offset: value.translation.height)
                        dragOffset = 0
                    }
            )
            .overlay(alignment: .bottom) {
                // Resize Handle
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 12)
                    .contentShape(Rectangle())
                    .cursor(.resizeUpDown)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                resizeOffset = value.translation.height
                            }
                            .onEnded { value in
                                updateDuration(offset: value.translation.height)
                                resizeOffset = 0
                            }
                    )
            }
        }
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
    
    private func calculateY() -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let diff = entry.startTime.timeIntervalSince(startOfDay)
        return CGFloat(diff / 3600.0) * hourHeight
    }
    
    private func calculateHeight() -> CGFloat {
        let duration = entry.duration
        return max(20, CGFloat(duration / 3600.0) * hourHeight)
    }
    
    private func updateTime(offset: CGFloat) {
        let hourDiff = offset / hourHeight
        let timeDiff = hourDiff * 3600.0
        entry.startTime = entry.startTime.addingTimeInterval(timeDiff)
        if let currentEnd = entry.endTime {
            entry.endTime = currentEnd.addingTimeInterval(timeDiff)
        }
        try? modelContext.save()
    }
    
    private func updateDuration(offset: CGFloat) {
        let hourDiff = offset / hourHeight
        let timeDiff = hourDiff * 3600.0
        let currentEnd = entry.endTime ?? Date()
        entry.endTime = currentEnd.addingTimeInterval(timeDiff)
        entry.isActive = false
        try? modelContext.save()
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
    DayView(date: Date())
        .modelContainer(for: TimeEntry.self, inMemory: true)
} 
