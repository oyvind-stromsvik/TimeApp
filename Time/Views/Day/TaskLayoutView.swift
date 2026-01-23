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
        let referenceTime = Date() // Use consistent time for layout calculations
        let groupedTasks = calculateHorizontalLayout(at: referenceTime)

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

    private func calculateHorizontalLayout(at referenceTime: Date) -> [TaskLayout] {
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
                        // Check for overlaps using resolved params
                        let taskParams = manager.resolveParams(for: task)
                        let otherParams = manager.resolveParams(for: other)
                        
                        // We need a temporary overlap check that respects the preview params
                        // Since Task.overlaps isn't easily mockable without changing the Task model,
                        // let's do a basic range check here using the resolved params.
                        let taskStart = taskParams.startTime
                        let taskEnd = taskParams.isActive 
                            ? referenceTime // Active tasks effectively end at 'now' for overlap purposes in layout
                            : (taskParams.endTime ?? Date.distantFuture)
                        
                        let otherStart = otherParams.startTime
                        let otherEnd = otherParams.isActive 
                            ? referenceTime
                            : (otherParams.endTime ?? Date.distantFuture)

                        if taskStart < otherEnd && otherStart < taskEnd {
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
                let itemParams = manager.resolveParams(for: item)
                let itemStart = itemParams.startTime
                let itemEnd = itemParams.isActive ? referenceTime : (itemParams.endTime ?? Date.distantFuture)

                for (index, col) in columns.enumerated() {
                    // Check if item overlaps with any task in this column
                    let overlaps = col.contains { existing in
                        let existingParams = manager.resolveParams(for: existing)
                        let existingStart = existingParams.startTime
                        let existingEnd = existingParams.isActive ? referenceTime : (existingParams.endTime ?? Date.distantFuture)
                        
                        return itemStart < existingEnd && existingStart < itemEnd
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
