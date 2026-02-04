import SwiftUI

struct TaskLayoutView: View {
    let tasks: [Task]
    let hourHeight: CGFloat
    let date: Date
    var topOffset: CGFloat = 0

    @Environment(AppManager.self) private var manager

    // Compute whether we have any active tasks and a tick value to trigger redraws
    private var hasActiveTasks: Bool {
        tasks.contains { $0.isActive } || (manager.previewTaskState?.isActive ?? false)
    }

    private var currentTick: Date {
        hasActiveTasks ? manager.lastTick : .distantPast
    }

    var body: some View {
        let tick = currentTick // Capture tick to create dependency
        let referenceTime = tick == .distantPast ? Date() : tick
        let groupedTasks = calculateHorizontalLayout(at: referenceTime, tick: tick)

        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(groupedTasks, id: \.task.id) { layout in
                    TaskBlock(
                        task: layout.task,
                        hourHeight: hourHeight,
                        date: date
                    )
                    .frame(width: geo.size.width * layout.widthPercent, height: calculateHeight(for: layout.task, at: tick))
                    .offset(x: geo.size.width * layout.offsetXPercent, y: calculateY(for: layout.task))
                    .animation(AppTheme.Animation.standard, value: manager.selectedTask?.id)
                }
            }
        }
    }

    private func calculateY(for task: Task) -> CGFloat {
        let params = manager.resolveParams(for: task)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let diff = params.startTime.timeIntervalSince(startOfDay)
        return (CGFloat(diff / 3600.0) * hourHeight) + topOffset
    }

    private func calculateHeight(for task: Task, at tick: Date) -> CGFloat {
        let params = manager.resolveParams(for: task)
        // For active tasks, compute duration from tick to ensure SwiftUI detects the change
        let duration: TimeInterval
        if params.isActive {
            duration = tick.timeIntervalSince(params.startTime)
        } else {
            // Recalculate duration from params
            if let end = params.endTime {
                duration = end.timeIntervalSince(params.startTime)
            } else {
                duration = task.duration // Fallback
            }
        }
        return max(AppTheme.Timeline.minTaskHeight, CGFloat(duration / 3600.0) * hourHeight)
    }

    private struct TaskLayout {
        let task: Task
        let widthPercent: CGFloat
        let offsetXPercent: CGFloat
    }

    private func calculateHorizontalLayout(at referenceTime: Date, tick: Date) -> [TaskLayout] {
        guard !tasks.isEmpty else { return [] }

        var layouts: [TaskLayout] = []
        var processedIds: Set<UUID> = []
        var rangeCache: [UUID: (start: CGFloat, end: CGFloat)] = [:]

        func visualRange(for task: Task) -> (start: CGFloat, end: CGFloat) {
            if let cached = rangeCache[task.id] {
                return cached
            }
            let startY = calculateY(for: task)
            let height = calculateHeight(for: task, at: tick)
            let range = (start: startY, end: startY + height)
            rangeCache[task.id] = range
            return range
        }

        for task in tasks {
            if processedIds.contains(task.id) { continue }

            var group = [task]
            var changed = true
            while changed {
                changed = false
                for other in tasks {
                    if !processedIds.contains(other.id) && !group.contains(where: { $0.id == other.id }) {
                        let otherRange = visualRange(for: other)
                        let overlapsGroup = group.contains { existing in
                            let existingRange = visualRange(for: existing)
                            return existingRange.start < otherRange.end && otherRange.start < existingRange.end
                        }

                        if overlapsGroup {
                            group.append(other)
                            changed = true
                        }
                    }
                }
            }
            
            // Sort by resolved start time
            group.sort { 
                manager.resolveParams(for: $0).startTime < manager.resolveParams(for: $1).startTime 
            }

            var columns: [[Task]] = []
            for item in group {
                var assigned = false
                let itemRange = visualRange(for: item)

                for (index, col) in columns.enumerated() {
                    // Check if item overlaps with any task in this column
                    let overlaps = col.contains { existing in
                        let existingRange = visualRange(for: existing)
                        return itemRange.start < existingRange.end && existingRange.start < itemRange.end
                    }
                    
                    if !overlaps {
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
