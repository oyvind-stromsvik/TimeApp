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
        VStack(spacing: 0) {
            // Header with Zoom Controls
            HStack {
                Text(date, format: .dateTime.weekday(.wide).day().month())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button { withAnimation { hourHeight = max(30, hourHeight - 10) } } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(hourHeight <= 30)
                    
                    Slider(value: $hourHeight, in: 30...200)
                        .frame(width: 100)
                    
                    Button { withAnimation { hourHeight = min(200, hourHeight + 10) } } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(hourHeight >= 200)
                }
                .padding(.horizontal)
                
                Text("Total: \(totalTimeFormatted)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
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
                .onAppear {
                    // Scroll to current hour or 08:00
                    let hour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(max(0, hour - 1), anchor: .top)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let entry = selectedEntry {
                EditTimeEntryView(entry: entry)
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
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                        .offset(x: -55, y: -7)
                    
                    VStack(spacing: 0) {
                        Divider()
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
                .frame(width: 8, height: 8)
                .offset(x: -4)
            
            Rectangle()
                .fill(.red)
                .frame(height: 2)
        }
        .offset(y: yOffset - 1)
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
                .onTapGesture { onSelect(layout.entry) }
            }
        }
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskDescription)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                Text(entry.formattedDuration)
                    .font(.system(size: 10))
                    .opacity(0.8)
            }
            .padding(8)
            .frame(width: geo.size.width * widthPercent, height: h + resizeOffset)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(entry.isActive ? Color.blue.opacity(0.3) : Color.green.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(entry.isActive ? Color.blue : Color.green, lineWidth: 1.5)
                    )
            )
            .offset(x: geo.size.width * offsetXPercent, y: y + dragOffset)
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
                    .frame(height: 10)
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
