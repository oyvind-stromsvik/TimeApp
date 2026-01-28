import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import CoreGraphics

@MainActor
@Observable
class AppManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private var timerService: TimerService
    private var systemService: SystemService
    private var modelContext: ModelContext
    private var userDefaults: UserDefaults
    
    // Track when we last notified the user about being idle
    private var lastIdleAlert: Date = Date()
    private var lastAggressiveAlert: Date = Date()
    
    // Settings from UserDefaults
    private var idleThreshold: TimeInterval {
        let value = userDefaults.double(forKey: "idleThreshold")
        return max(value, 60) // Clamp to minimum 1 minute
    }
    
    private var aggressiveThreshold: TimeInterval {
        let value = userDefaults.double(forKey: "aggressiveThreshold")
        return max(value, 30) // Clamp to minimum 30 seconds
    }
    
    private var isAggressiveAlertEnabled: Bool {
        userDefaults.bool(forKey: "enableAggressiveAlerts")
    }

    private var isIdleDetectionEnabled: Bool {
        userDefaults.bool(forKey: "enableIdleDetection")
    }

    private var allowSimultaneousTasks: Bool {
        userDefaults.bool(forKey: "allowSimultaneousTasks")
    }

    private var askToStopActiveTasks: Bool {
        userDefaults.bool(forKey: "askToStopActiveTasks")
    }
    
    // This property is just to trigger UI updates for active tasks
    var lastTick: Date = Date()

    // UI binding for stop confirmation
    var showStopConfirmation: Bool = false
    private(set) var pendingTaskAction: (() -> Void)?
    private(set) var onCancelAction: (() -> Void)?

    // UI binding for aggressive alert
    var showAggressiveAlert: Bool = false {
        didSet {
            if showAggressiveAlert {
                NSApp.dockTile.badgeLabel = "!"
                NSApp.dockTile.display()
                NSApp.requestUserAttention(.criticalRequest)
                
                // Force windows to de-miniaturize
                NSApp.windows.forEach { window in
                    if window.isMiniaturized {
                        window.deminiaturize(nil)
                    }
                }
            } else {
                NSApp.dockTile.badgeLabel = nil
            }
        }
    }
    
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
             "sidebarWidth": AppTheme.sidebarDefaultWidth
        ])

        // Load persisted sidebar width
        self.sidebarWidth = userDefaults.double(forKey: "sidebarWidth") > 0
            ? userDefaults.double(forKey: "sidebarWidth")
            : AppTheme.sidebarDefaultWidth

        super.init()
        
        requestNotificationPermission()
        UNUserNotificationCenter.current().delegate = self
        startTimer()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
    
    // Delegate method to allow notifications while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle user clicking on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }

    private func startTimer() {
        timerService.onTick = { [weak self] in
            guard let self else { return }
            self.lastTick = Date()
            self.checkIdleStatus()
        }
        timerService.start(interval: 1.0)
    }

    /**
     Intended to annoy the user until they are actively tracking time on a task.
     They express purpose of this app is to always track time on at least one
     task at all points throughout the workday, ie. as long as the app is open,
     so we want to be as annoying as possible in that regard.
     */
    private func checkIdleStatus() {
        // Case 1: No active task -> Aggressively alert
        if activeTasks.isEmpty {
            guard isAggressiveAlertEnabled else { return }
            
            if Date().timeIntervalSince(lastAggressiveAlert) < aggressiveThreshold {
                return
            }
            
            NSApp.activate(ignoringOtherApps: true)
            showAggressiveAlert = true
            lastAggressiveAlert = Date()
        }
        // Case 2: Active task -> Check for idle
        else {
            // Reset aggressive alert timer while tasks are active
            // so it starts fresh when the task is stopped
            lastAggressiveAlert = Date()

            guard isIdleDetectionEnabled else { return }
            guard let idleTime = systemService.getIdleTime() else { return }
            
            if idleTime < idleThreshold || Date().timeIntervalSince(lastIdleAlert) < idleThreshold {
                return
            }
            
            sendIdleNotification()
            lastIdleAlert = Date()
            lastAggressiveAlert = Date()
        }
    }
    
    private func sendIdleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Are you working?"
        content.body = "You've been idle for a while with no active task. Click here to start tracking."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
        task.stop()
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
                newTask.isActive = true
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
                task.isActive = true
                self.save()
            }, onCancel: { [weak self] in
                guard let self else { return }
                before.apply(to: task)
                self.save()
            })
        } else {
            task.isActive = (endTime == nil)
            save()
        }

        let after = TaskSnapshot(task)
        guard before != after, let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.apply(snapshot: before, undoManager: undoManager, actionName: "Edit Task")
        }
        undoManager.setActionName("Edit Task")
    }
    
    func duplicateTask(_ task: Task, undoManager: UndoManager? = nil) {
        let newTask = Task(
            taskDescription: task.taskDescription,
            startTime: task.startTime,
            isActive: false
        )
        newTask.endTime = task.endTime
        modelContext.insert(newTask)
        save()

        if let undoManager {
            let snapshot = TaskSnapshot(newTask)
            undoManager.registerUndo(withTarget: self) { target in
                target.deleteTask(withId: snapshot.id, undoManager: undoManager, actionName: "Duplicate Task")
            }
            undoManager.setActionName("Duplicate Task")
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

