import SwiftUI
import SwiftData

struct TaskBlock: View {
    @Bindable var task: Task
    let hourHeight: CGFloat
    let date: Date
    @Binding var selectedTask: Task?
    @Binding var hasUnsavedChanges: Bool

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isResizing = false

    @State private var dragInitialStartTime: Date?
    @State private var dragInitialEndTime: Date?
    @State private var dragInitialIsActive: Bool?
    @State private var dragInitialDuration: TimeInterval?

    var body: some View {
        let _ = task.isActive ? manager.lastTick : .distantPast
        let tintColor = task.isActive ? AppTheme.Colors.activeTimer : AppTheme.Colors.taskBaseColor(task: task)
        let isSelected = task.id == selectedTask?.id
        let isInteracting = isDragging || isResizing

        VStack(alignment: .leading, spacing: 2) {
            TaskContent(task: task)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedTask = task
                    }
                }
        )
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.background)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(task.isActive ? 0.5 : 0.5), tintColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? AppTheme.Colors.accent.opacity(0.95) : AppTheme.Colors.separator.opacity(isHovering ? 0.55 : 0.35),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .shadow(
                    color: Color.black.opacity(isInteracting ? 0.14 : (isHovering ? 0.10 : 0.06)),
                    radius: isInteracting ? 12 : (isHovering ? 8 : 4),
                    x: 0,
                    y: isInteracting ? 7 : (isHovering ? 5 : 2)
                )
        }
        .scaleEffect(isInteracting ? 1.02 : (isHovering ? 1.01 : 1))
        .animation(.snappy(duration: 0.18), value: isHovering)
        .animation(.snappy(duration: 0.18), value: isSelected)
        .animation(.snappy(duration: 0.18), value: isInteracting)
        .popover(item: Binding(
            get: { selectedTask?.id == task.id ? selectedTask : nil },
            set: { if $0 == nil { selectedTask = nil } }
        )) { task in
            EditTaskView(task: task, hasUnsavedChanges: $hasUnsavedChanges)
                .presentationCompactAdaptation(.none)
        }
        .overlay(alignment: .top) {
            if isDragging || isResizing { TimeLabel(date: task.startTime, isTop: true) }
        }
        .overlay(alignment: .bottom) {
            if isDragging || isResizing { TimeLabel(date: task.endTime ?? Date(), isTop: false) }
        }
        .contextMenu {
            Button("Duplicate") { manager.duplicateTask(task, undoManager: undoManager) }
            Divider()
            Button("Delete", role: .destructive) { manager.deleteTask(task, undoManager: undoManager) }
        }
        .onHover { hovering in isHovering = hovering }
        .cursor((isHovering && !isInteracting) ? .pointingHand : .arrow)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
                .onChanged { value in
                    if dragInitialStartTime == nil {
                        dragInitialStartTime = task.startTime
                        dragInitialEndTime = task.endTime
                        dragInitialIsActive = task.isActive
                        let endForDuration = task.endTime ?? Date()
                        dragInitialDuration = endForDuration.timeIntervalSince(task.startTime)
                    }
                    isDragging = true
                    updatePosition(offset: value.translation.height)
                }
                .onEnded { _ in
                    if let oldStartTime = dragInitialStartTime,
                       let oldIsActive = dragInitialIsActive {
                        manager.registerUndoForTimeChange(
                            taskID: task.id,
                            oldStartTime: oldStartTime,
                            oldEndTime: dragInitialEndTime,
                            oldIsActive: oldIsActive,
                            undoManager: undoManager,
                            actionName: "Move Task"
                        )
                    }
                    isDragging = false
                    dragInitialStartTime = nil
                    dragInitialEndTime = nil
                    dragInitialIsActive = nil
                    dragInitialDuration = nil
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
        if let oldStartTime = dragInitialStartTime,
           let oldIsActive = dragInitialIsActive {
            manager.registerUndoForTimeChange(
                taskID: task.id,
                oldStartTime: oldStartTime,
                oldEndTime: dragInitialEndTime,
                oldIsActive: oldIsActive,
                undoManager: undoManager,
                actionName: "Resize Task"
            )
        }
        isResizing = false
        dragInitialStartTime = nil
        dragInitialEndTime = nil
        dragInitialIsActive = nil
        dragInitialDuration = nil
        manager.save()
    }

    private func updatePosition(offset: CGFloat) {
        guard let baseStart = dragInitialStartTime, let duration = dragInitialDuration else { return }
        let timeDiff = (offset / hourHeight) * 3600.0
        let newStart = snap(baseStart.addingTimeInterval(timeDiff))
        task.startTime = newStart
        if dragInitialEndTime != nil {
            task.endTime = newStart.addingTimeInterval(duration)
        } else {
            task.endTime = nil
        }
        if let dragInitialIsActive {
            task.isActive = dragInitialIsActive
        }
    }

    private func updateStartTime(offset: CGFloat) {
        if dragInitialStartTime == nil {
            dragInitialStartTime = task.startTime
            dragInitialEndTime = task.endTime
            dragInitialIsActive = task.isActive
            let endForDuration = task.endTime ?? Date()
            dragInitialDuration = endForDuration.timeIntervalSince(task.startTime)
        }
        guard let baseStart = dragInitialStartTime else { return }
        let baseEnd = dragInitialEndTime ?? Date()
        let newStart = snap(baseStart.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newStart < baseEnd.addingTimeInterval(-AppTheme.Timing.minimumTaskDuration) { task.startTime = newStart }
    }

    private func updateEndTime(offset: CGFloat) {
        if dragInitialEndTime == nil {
            dragInitialEndTime = task.endTime
            dragInitialStartTime = task.startTime
            dragInitialIsActive = task.isActive
            let endForDuration = task.endTime ?? Date()
            dragInitialDuration = endForDuration.timeIntervalSince(task.startTime)
        }
        guard let baseStart = dragInitialStartTime else { return }
        let baseEnd = dragInitialEndTime ?? Date()
        let newEnd = snap(baseEnd.addingTimeInterval((offset / hourHeight) * 3600.0))
        if newEnd > baseStart.addingTimeInterval(AppTheme.Timing.minimumTaskDuration) {
            task.endTime = newEnd
            task.isActive = false
        }
    }

    private func snap(_ date: Date) -> Date {
        let interval = AppTheme.Timing.snapInterval
        return Date(timeIntervalSince1970: round(date.timeIntervalSince1970 / interval) * interval)
    }
}

struct TaskContent: View {
    let task: Task

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.taskDescription)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(task.formattedDuration)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(task.isActive ? AppTheme.Colors.activeTimer : .secondary)
            }

            Spacer()

            if task.isActive {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.activeTimer)
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
            .background(AppTheme.Colors.timeLabelBackground)
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
                    .fill(AppTheme.Colors.resizeHandle)
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
