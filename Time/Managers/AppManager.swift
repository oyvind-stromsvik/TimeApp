import Foundation
import SwiftUI
import SwiftData
import CoreGraphics

@MainActor
@Observable
class AppManager: NSObject {
    private var timerService: TimerService
    private var systemService: SystemService
    private var modelContext: ModelContext
    private var userDefaults: UserDefaults
    
    // Track when we last notified the user about being idle
    private var lastIdleAlert: Date = Date()
    private var lastNoActiveTasksAlert: Date = Date()
    private var lastTrackingCheckAlert: Date = Date()
    private var lastStopTime: Date = .distantPast

    private var idleStart: Date?
    private var isIdleFrozen: Bool = false
    var idleDuration: TimeInterval = 0
    var idleStartTime: Date? { idleStart }

    enum FocusModal: String, Identifiable, Equatable {
        case idle
        case noActiveTasks
        case trackingCheck

        var id: String { rawValue }
    }

    var focusModal: FocusModal?
    
    // Settings from UserDefaults
    private var idleThreshold: TimeInterval {
        let value = userDefaults.double(forKey: "idleThreshold")
        return max(value, 60) // Clamp to minimum 1 minute
    }
    
    private var noActiveTasksThreshold: TimeInterval {
        let value = userDefaults.double(forKey: "aggressiveThreshold")
        return max(value, 30) // Clamp to minimum 30 seconds
    }
    
    private var isNoActiveTasksAlertEnabled: Bool {
        userDefaults.bool(forKey: "enableAggressiveAlerts")
    }

    private var isIdleDetectionEnabled: Bool {
        userDefaults.bool(forKey: "enableIdleDetection")
    }

    private var trackingCheckInterval: TimeInterval {
        let value = userDefaults.double(forKey: "trackingCheckInterval")
        return max(value, 60) // Allow 1 minute while debugging
    }

    private var isTrackingCheckEnabled: Bool {
        userDefaults.bool(forKey: "enableTrackingCheck")
    }

    private var allowSimultaneousTasks: Bool {
        userDefaults.bool(forKey: "allowSimultaneousTasks")
    }

    private var askToStopActiveTasks: Bool {
        userDefaults.bool(forKey: "askToStopActiveTasks")
    }

    // MARK: - Time Step Settings

    var timeStepMinutes: Int {
        let value = userDefaults.integer(forKey: "timeStepMinutes")
        return value > 0 ? value : 5 // Default to 5 if not set
    }

    var timeStepInterval: TimeInterval {
        TimeInterval(timeStepMinutes * 60)
    }

    var defaultNewTaskDuration: TimeInterval {
        let value = userDefaults.double(forKey: "defaultNewTaskDuration")
        return value > 0 ? value : 1800.0 // Default to 30 minutes
    }

    func snapDate(_ date: Date) -> Date {
        let interval = timeStepInterval
        return Date(timeIntervalSince1970: round(date.timeIntervalSince1970 / interval) * interval)
    }
    
    // This property is just to trigger UI updates for active tasks
    var lastTick: Date = Date()

    // UI binding for stop confirmation
    var showStopConfirmation: Bool = false
    private(set) var pendingTaskAction: (() -> Void)?
    private(set) var onCancelAction: (() -> Void)?

    // UI binding for sidebar visibility and width
    var isSidebarVisible: Bool = true
    var sidebarWidth: CGFloat {
        didSet {
            userDefaults.set(sidebarWidth, forKey: "sidebarWidth")
        }
    }

    // MARK: - Centralized Selection State
    var selectedTask: Task?
    var hasUnsavedChanges: Bool = false
    var showingDiscardAlert: Bool = false

    // MARK: - Popover State
    enum PopoverLocation: Equatable {
        case none
        case dayView(taskID: UUID)
        case sidebar(taskID: UUID)
    }
    var popoverLocation: PopoverLocation = .none

    func openPopover(for task: Task, from location: PopoverLocation) {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        }
        else {
            popoverLocation = location
        }
    }

    func closePopover() {
        print("Close popover")
        popoverLocation = .none
        hasUnsavedChanges = false
    }

    init(modelContext: ModelContext, 
         timerService: TimerService = DefaultTimerService(),
         systemService: SystemService = DefaultSystemService(),
         userDefaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.timerService = timerService
        self.systemService = systemService
        self.userDefaults = userDefaults

        // Register default settings if not set
        userDefaults.register(defaults: [
             "idleThreshold": 300.0,
             "aggressiveThreshold": 60.0,
             "enableAggressiveAlerts": true,
             "enableIdleDetection": true,
             "enableTrackingCheck": false,
             "trackingCheckInterval": 1800.0,
             "menuBarDurationMode": MenuBarDurationMode.activeOnly.rawValue,
             "sidebarWidth": AppTheme.sidebarDefaultWidth,
             "timeStepMinutes": 5,
             "defaultNewTaskDuration": 1800.0
        ])

        // Load persisted sidebar width
        self.sidebarWidth = userDefaults.double(forKey: "sidebarWidth") > 0
            ? userDefaults.double(forKey: "sidebarWidth")
            : AppTheme.sidebarDefaultWidth

        super.init()
        startTimer()
    }

    private func startTimer() {
        timerService.onTick = { [weak self] in
            guard let self else { return }
            self.lastTick = Date()
            self.checkIdleStatus()
        }
        timerService.start(interval: 1.0)
    }

    private func presentFocusModal(_ modal: FocusModal) {
        guard focusModal == nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { window in
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
        focusModal = modal
    }

    private func beginIdleModal(idleTime: TimeInterval) {
        idleStart = Date().addingTimeInterval(-idleTime)
        idleDuration = idleTime
        isIdleFrozen = false
        presentFocusModal(.idle)
    }

    private func updateIdleDurationIfNeeded() {
        guard focusModal == .idle, let idleStart else { return }
        guard let idleTime = systemService.getIdleTime() else { return }

        if idleTime < idleThreshold {
            if !isIdleFrozen {
                idleDuration = Date().timeIntervalSince(idleStart)
                isIdleFrozen = true
            }
        } else {
            idleDuration = max(idleDuration, idleTime)
        }
    }

    private func checkIdleStatus() {
        if focusModal == .idle {
            updateIdleDurationIfNeeded()
            return
        }

        if focusModal != nil {
            return
        }

        var idleTime: TimeInterval?
        if isIdleDetectionEnabled || isTrackingCheckEnabled {
            idleTime = systemService.getIdleTime()
        }

        if activeTasks.isEmpty {
            lastTrackingCheckAlert = Date()
            guard isNoActiveTasksAlertEnabled else { return }

            if Date().timeIntervalSince(lastNoActiveTasksAlert) < noActiveTasksThreshold {
                return
            }

            lastNoActiveTasksAlert = Date()
            presentFocusModal(.noActiveTasks)
            return
        }

        lastNoActiveTasksAlert = Date()

        if isIdleDetectionEnabled, let idleTime {
            if idleTime >= idleThreshold && Date().timeIntervalSince(lastIdleAlert) >= idleThreshold {
                lastIdleAlert = Date()
                beginIdleModal(idleTime: idleTime)
                return
            }
        }

        guard isTrackingCheckEnabled else { return }

        if let idleTime, idleTime >= idleThreshold {
            return
        }

        if Date().timeIntervalSince(lastTrackingCheckAlert) >= trackingCheckInterval {
            lastTrackingCheckAlert = Date()
            presentFocusModal(.trackingCheck)
        }
    }

    private func resetIdleState() {
        idleStart = nil
        idleDuration = 0
        isIdleFrozen = false
    }

    private func discardIdleTime() {
        guard idleDuration > 0 else { return }
        let now = Date()
        for task in activeTasks {
            let adjustedStart = task.startTime.addingTimeInterval(idleDuration)
            task.startTime = min(adjustedStart, now)
        }
        save()
    }

    private func resetTrackingCheckTimer() {
        lastTrackingCheckAlert = Date()
    }

    private func roundedUpToMinute(_ date: Date) -> Date {
        let seconds = date.timeIntervalSinceReferenceDate
        let roundedSeconds = ceil(seconds / 60.0) * 60.0
        return Date(timeIntervalSinceReferenceDate: roundedSeconds)
    }

    private func roundedDownToMinute(_ date: Date) -> Date {
        let seconds = date.timeIntervalSinceReferenceDate
        let roundedSeconds = floor(seconds / 60.0) * 60.0
        return Date(timeIntervalSinceReferenceDate: roundedSeconds)
    }

    private func snappedStartTimeForNewActiveTask(_ startTime: Date) -> Date {
        let roundedStart = roundedDownToMinute(startTime)
        guard !allowSimultaneousTasks else { return roundedStart }
        return max(roundedStart, lastStopTime)
    }

    func keepIdleTime() {
        resetIdleState()
        focusModal = nil
        lastIdleAlert = Date()
        lastTrackingCheckAlert = Date()
    }

    func discardIdleTimeAndContinue() {
        discardIdleTime()
        resetIdleState()
        focusModal = nil
        lastIdleAlert = Date()
        lastTrackingCheckAlert = Date()
    }

    func dismissNoActiveTasksAlert() {
        focusModal = nil
        lastNoActiveTasksAlert = Date()
    }

    func dismissTrackingCheckAlert() {
        focusModal = nil
        lastTrackingCheckAlert = Date()
    }
    
    var previewTaskState: TaskSnapshot?

    struct TaskSnapshot: Equatable {
        let id: UUID
        let taskDescription: String
        let startTime: Date
        let endTime: Date?
        let isActive: Bool

        init(id: UUID, taskDescription: String, startTime: Date, endTime: Date?, isActive: Bool) {
            self.id = id
            self.taskDescription = taskDescription
            self.startTime = startTime
            self.endTime = endTime
            self.isActive = isActive
        }

        init(_ task: Task) {
            self.id = task.id
            self.taskDescription = task.taskDescription
            self.startTime = task.startTime
            self.endTime = task.endTime
            self.isActive = task.isActive
        }

        func apply(to task: Task) {
            task.id = id
            task.taskDescription = taskDescription
            task.startTime = startTime
            task.endTime = endTime
            task.isActive = isActive
        }
    }

    private func fetchTask(id: UUID) -> Task? {
        let predicate = #Predicate<Task> { task in
            task.id == id
        }
        let descriptor = FetchDescriptor<Task>(predicate: predicate)
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    func resolveParams(for task: Task) -> (startTime: Date, endTime: Date?, isActive: Bool) {
        if let preview = previewTaskState, preview.id == task.id {
            return (preview.startTime, preview.endTime, preview.isActive)
        }
        return (task.startTime, task.endTime, task.isActive)
    }

    var activeTasks: [Task] {
        let descriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.isActive })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func totalDurationForTasks(named description: String) -> TimeInterval {
        let predicate = #Predicate<Task> { task in
            task.taskDescription == description
        }
        let descriptor = FetchDescriptor<Task>(predicate: predicate)
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.reduce(0) { $0 + $1.duration }
    }

    func totalDurationForTasks(named description: String, on day: Date) -> TimeInterval {
        let predicate = #Predicate<Task> { task in
            task.taskDescription == description
        }
        let descriptor = FetchDescriptor<Task>(predicate: predicate)
        let tasks = (try? modelContext.fetch(descriptor)) ?? []

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let now = Date()

        return tasks.reduce(0) { total, task in
            let taskEnd = task.endTime ?? now
            let overlapStart = max(task.startTime, dayStart)
            let overlapEnd = min(taskEnd, dayEnd)
            let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
            return total + overlap
        }
    }

    func stopAllActiveTasks() {
        for task in activeTasks {
            stopTask(task, undoManager: nil)
        }
    }

    private func enforceSingleActiveTask() {
        if !allowSimultaneousTasks {
            stopAllActiveTasks()
        }
    }

    private func handleActiveTaskConflict(action: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        if allowSimultaneousTasks && askToStopActiveTasks && !activeTasks.isEmpty {
            pendingTaskAction = action
            onCancelAction = onCancel
            showStopConfirmation = true
        } else {
            if !allowSimultaneousTasks {
                stopAllActiveTasks()
            }
            action()
        }
    }

    func confirmStopAndStart() {
        stopAllActiveTasks()
        pendingTaskAction?()
        pendingTaskAction = nil
        onCancelAction = nil
        showStopConfirmation = false
    }

    func confirmKeepAndStart() {
        pendingTaskAction?()
        pendingTaskAction = nil
        onCancelAction = nil
        showStopConfirmation = false
    }

    func cancelPendingTask() {
        onCancelAction?()
        pendingTaskAction = nil
        onCancelAction = nil
        showStopConfirmation = false
    }

    // MARK: - Selection Management

    func selectTask(_ task: Task?, animated: Bool = true) {
        print("Select task: \(String(describing: task?.taskDescription ?? "nil"))")
        if animated {
            withAnimation(AppTheme.Animation.standard) {
                selectedTask = task
            }
        }
        else {
            selectedTask = task
        }
    }

    func tryDeselectTask() {
        print("Try to deselect task")
        if hasUnsavedChanges {
            showingDiscardAlert = true
        }
        else {
            selectTask(nil);
        }
    }

    func discardChangesAndDeselect() {
        print("Discard changes and deselect task")
        hasUnsavedChanges = false
        selectTask(nil);
    }

    private func apply(snapshot: TaskSnapshot, undoManager: UndoManager?, actionName: String) {
        guard let task = fetchTask(id: snapshot.id) else { return }

        let current = TaskSnapshot(task)
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                target.apply(snapshot: current, undoManager: undoManager, actionName: actionName)
            }
            undoManager.setActionName(actionName)
        }

        snapshot.apply(to: task)
        save()
    }

    func registerUndoForTimeChange(
        taskID: UUID,
        oldStartTime: Date,
        oldEndTime: Date?,
        oldIsActive: Bool,
        undoManager: UndoManager?,
        actionName: String
    ) {
        guard let undoManager, let task = fetchTask(id: taskID) else { return }

        // Only register if the user actually changed something.
        if task.startTime == oldStartTime && task.endTime == oldEndTime && task.isActive == oldIsActive {
            return
        }

        undoManager.registerUndo(withTarget: self) { target in
            target.applyTimeChange(
                taskID: taskID,
                startTime: oldStartTime,
                endTime: oldEndTime,
                isActive: oldIsActive,
                undoManager: undoManager,
                actionName: actionName
            )
        }
        undoManager.setActionName(actionName)
    }

    private func applyTimeChange(
        taskID: UUID,
        startTime: Date,
        endTime: Date?,
        isActive: Bool,
        undoManager: UndoManager?,
        actionName: String
    ) {
        guard let task = fetchTask(id: taskID) else { return }

        let currentStartTime = task.startTime
        let currentEndTime = task.endTime
        let currentIsActive = task.isActive

        if let undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                target.applyTimeChange(
                    taskID: taskID,
                    startTime: currentStartTime,
                    endTime: currentEndTime,
                    isActive: currentIsActive,
                    undoManager: undoManager,
                    actionName: actionName
                )
            }
            undoManager.setActionName(actionName)
        }

        task.startTime = startTime
        task.endTime = endTime
        task.isActive = isActive
        save()
    }

    func stopTask(_ task: Task, undoManager: UndoManager? = nil) {
        let before = TaskSnapshot(task)
        let roundedEndTime = roundedUpToMinute(Date())
        task.endTime = roundedEndTime
        task.isActive = false
        lastStopTime = max(lastStopTime, roundedEndTime)
        save()

        // Only register if something actually changed.
        let after = TaskSnapshot(task)
        if before != after {
            undoManager?.registerUndo(withTarget: self) { target in
                target.apply(snapshot: before, undoManager: undoManager, actionName: "Stop Task")
            }
            undoManager?.setActionName("Stop Task")
        }
    }

    @discardableResult
    func addNewTask(description: String, startTime: Date, endTime: Date? = nil, isActive: Bool = false, undoManager: UndoManager? = nil) -> Task {
        let newTask = Task(taskDescription: description, startTime: startTime, isActive: false)
        newTask.endTime = endTime
        modelContext.insert(newTask)
        save()

        if let undoManager {
            let snapshot = TaskSnapshot(newTask)
            undoManager.registerUndo(withTarget: self) { target in
                target.deleteTask(withId: snapshot.id, undoManager: undoManager, actionName: "Add Task")
            }
            undoManager.setActionName("Add Task")
        }

        if isActive {
            handleActiveTaskConflict(action: { [weak self] in
                guard let self else { return }
                newTask.startTime = self.snappedStartTimeForNewActiveTask(newTask.startTime)
                newTask.isActive = true
                self.resetTrackingCheckTimer()
                self.save()
            }, onCancel: { [weak self] in
                guard let self else { return }
                self.modelContext.delete(newTask)
                self.save()
            })
        }

        return newTask
    }

    /// Creates a new task and optionally selects it. This is the unified entry point for task creation.
    @discardableResult
    func createTask(description: String, startTime: Date, endTime: Date? = nil, isActive: Bool = false, selectAfterCreation: Bool = false,  undoManager: UndoManager? = nil) -> Task {
        let task = addNewTask(
            description: description,
            startTime: startTime,
            endTime: endTime,
            isActive: isActive,
            undoManager: undoManager
        )

        if selectAfterCreation {
            openPopover(for: task, from: .dayView(taskID: task.id))
            selectTask(task);
        }

        return task
    }

    func updateTask(_ task: Task, startTime: Date, endTime: Date?, description: String, undoManager: UndoManager? = nil) {
        let before = TaskSnapshot(task)
        let wasActive = task.isActive
        
        let shouldBecomeActive = (endTime == nil)
        
        // Update basic fields but keep inactive if we need to ask
        task.startTime = startTime
        task.endTime = endTime
        task.taskDescription = description
        
        if shouldBecomeActive && !task.isActive {
            // Task wants to become active. Reset isActive to false for now while we check conflicts.
            task.isActive = false 
            save()
            
            handleActiveTaskConflict(action: { [weak self] in
                guard let self else { return }
                task.startTime = self.snappedStartTimeForNewActiveTask(task.startTime)
                task.isActive = true
                self.resetTrackingCheckTimer()
                self.save()
            }, onCancel: { [weak self] in
                guard let self else { return }
                before.apply(to: task)
                self.save()
            })
        } else {
            task.isActive = (endTime == nil)
            if task.isActive {
                task.startTime = snappedStartTimeForNewActiveTask(task.startTime)
            }
            save()

            if !wasActive && task.isActive {
                resetTrackingCheckTimer()
            }
        }

        let after = TaskSnapshot(task)
        guard before != after, let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.apply(snapshot: before, undoManager: undoManager, actionName: "Edit Task")
        }
        undoManager.setActionName("Edit Task")
    }
    
    func duplicateTask(_ task: Task, from location: PopoverLocation, undoManager: UndoManager? = nil) {
        let newTask = Task(
            taskDescription: task.taskDescription,
            startTime: task.startTime,
            isActive: false
        )
        // For active tasks, use current time as end time to preserve duration
        newTask.endTime = task.isActive ? Date() : task.endTime
        modelContext.insert(newTask)
        save()

        // Open popover for the new task
        let newLocation: PopoverLocation = switch location {
        case .dayView: .dayView(taskID: newTask.id)
        case .sidebar: .sidebar(taskID: newTask.id)
        case .none: .none
        }
        if newLocation != .none {
            popoverLocation = newLocation
            selectTask(newTask)
        }

        if let undoManager {
            let snapshot = TaskSnapshot(newTask)
            undoManager.registerUndo(withTarget: self) { target in
                target.deleteTask(withId: snapshot.id, undoManager: undoManager, actionName: "Duplicate Task")
            }
            undoManager.setActionName("Duplicate Task")
        }
    }

    func splitTask(_ task: Task, from location: PopoverLocation, undoManager: UndoManager? = nil) {
        let effectiveEndTime = task.isActive ? Date() : (task.endTime ?? Date())
        let midpoint = task.startTime.addingTimeInterval(effectiveEndTime.timeIntervalSince(task.startTime) / 2)

        // Store original task's start time for undo
        let originalStartTime = task.startTime
        let originalTaskId = task.id

        // Create new task for the first half
        let newTask = Task(
            taskDescription: task.taskDescription,
            startTime: task.startTime,
            isActive: false
        )
        newTask.endTime = midpoint
        modelContext.insert(newTask)

        // Update original task's start time to midpoint (so it becomes the second half)
        task.startTime = midpoint
        save()

        // Open popover for the new task
        let newLocation: PopoverLocation = switch location {
        case .dayView: .dayView(taskID: newTask.id)
        case .sidebar: .sidebar(taskID: newTask.id)
        case .none: .none
        }
        if newLocation != .none {
            popoverLocation = newLocation
            selectTask(newTask)
        }

        if let undoManager {
            let newTaskSnapshot = TaskSnapshot(newTask)
            undoManager.registerUndo(withTarget: self) { target in
                target.undoSplitTask(
                    newTaskId: newTaskSnapshot.id,
                    originalTaskId: originalTaskId,
                    originalStartTime: originalStartTime,
                    undoManager: undoManager
                )
            }
            undoManager.setActionName("Split Task")
        }
    }

    private func undoSplitTask(newTaskId: UUID, originalTaskId: UUID, originalStartTime: Date, undoManager: UndoManager?) {
        // Delete the new task created by split
        guard let newTask = fetchTask(id: newTaskId) else { return }
        let newTaskSnapshot = TaskSnapshot(newTask)
        modelContext.delete(newTask)

        // Restore original task's start time
        if let originalTask = fetchTask(id: originalTaskId) {
            let currentStartTime = originalTask.startTime
            originalTask.startTime = originalStartTime
            save()

            // Register redo
            if let undoManager {
                undoManager.registerUndo(withTarget: self) { target in
                    target.redoSplitTask(
                        newTaskSnapshot: newTaskSnapshot,
                        originalTaskId: originalTaskId,
                        splitStartTime: currentStartTime,
                        undoManager: undoManager
                    )
                }
                undoManager.setActionName("Split Task")
            }
        } else {
            save()
        }
    }

    private func redoSplitTask(newTaskSnapshot: TaskSnapshot, originalTaskId: UUID, splitStartTime: Date, undoManager: UndoManager?) {
        // Recreate the split task
        let newTask = Task(
            taskDescription: newTaskSnapshot.taskDescription,
            startTime: newTaskSnapshot.startTime,
            isActive: newTaskSnapshot.isActive
        )
        newTask.id = newTaskSnapshot.id
        newTask.endTime = newTaskSnapshot.endTime
        modelContext.insert(newTask)

        // Update original task's start time back to midpoint
        if let originalTask = fetchTask(id: originalTaskId) {
            let originalStartTime = originalTask.startTime
            originalTask.startTime = splitStartTime
            save()

            // Register undo
            if let undoManager {
                undoManager.registerUndo(withTarget: self) { target in
                    target.undoSplitTask(
                        newTaskId: newTaskSnapshot.id,
                        originalTaskId: originalTaskId,
                        originalStartTime: originalStartTime,
                        undoManager: undoManager
                    )
                }
                undoManager.setActionName("Split Task")
            }
        } else {
            save()
        }
    }
    
    func deleteTask(_ task: Task, undoManager: UndoManager? = nil) {
        let snapshot = TaskSnapshot(task)
        deleteTask(withId: snapshot.id, undoManager: undoManager, actionName: "Delete Task", snapshotForUndo: snapshot)
    }

    private func deleteTask(withId id: UUID, undoManager: UndoManager?, actionName: String, snapshotForUndo: TaskSnapshot? = nil) {
        guard let task = fetchTask(id: id) else { return }
        let snapshot = snapshotForUndo ?? TaskSnapshot(task)
        modelContext.delete(task)
        save()

        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreDeletedTask(snapshot: snapshot, undoManager: undoManager, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func restoreDeletedTask(snapshot: TaskSnapshot, undoManager: UndoManager?, actionName: String) {
        // If it already exists, just apply values.
        if let existing = fetchTask(id: snapshot.id) {
            if snapshot.isActive && !existing.isActive {
                enforceSingleActiveTask()
            }
            apply(snapshot: snapshot, undoManager: undoManager, actionName: actionName)
            return
        }

        if snapshot.isActive {
            enforceSingleActiveTask()
        }
        let restored = Task(taskDescription: snapshot.taskDescription, startTime: snapshot.startTime, isActive: snapshot.isActive)
        restored.id = snapshot.id
        restored.endTime = snapshot.endTime
        modelContext.insert(restored)
        save()

        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.deleteTask(withId: snapshot.id, undoManager: undoManager, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }
    
    func save() {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            print("Error saving: \(error.localizedDescription)")
            // Future: could post notification or update state to show error in UI
        }
    }
}
