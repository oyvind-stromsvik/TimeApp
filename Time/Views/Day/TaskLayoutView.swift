import SwiftUI

struct TaskLayoutView: View {
    let tasks: [Task]
    let hourHeight: CGFloat
    let date: Date
    var topOffset: CGFloat = 0

    @Environment(AppManager.self) private var manager

    // Compute whether we have any active tasks and a tick value to trigger redraws
    private var hasActiveTasks: Bool {
        tasks.contains { $0.isActive }
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
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let diff = task.startTime.timeIntervalSince(startOfDay)
        return (CGFloat(diff / 3600.0) * hourHeight) + topOffset
    }

    private func calculateHeight(for task: Task, at tick: Date) -> CGFloat {
        // For active tasks, compute duration from tick to ensure SwiftUI detects the change
        let duration: TimeInterval
        if task.isActive {
            duration = tick.timeIntervalSince(task.startTime)
        } else {
            duration = task.duration
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
                        if group.contains(where: { $0.overlaps(with: other, at: referenceTime) }) {
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
                    if !col.contains(where: { $0.overlaps(with: item, at: referenceTime) }) {
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
