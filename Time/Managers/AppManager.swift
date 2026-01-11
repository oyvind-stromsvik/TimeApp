import Foundation
import SwiftUI
import SwiftData

@Observable
class AppManager {
    private var timer: Timer?
    private var modelContext: ModelContext
    
    // This property is just to trigger UI updates for active timers
    var lastTick: Date = Date()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.lastTick = Date()
        }
    }
    
    func startNewTimer(description: String, startTime: Date = Date()) {
        addNewTask(description: description, startTime: startTime, isActive: true)
    }

    fileprivate struct TaskSnapshot: Equatable {
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

    func stopTimer(_ task: Task, undoManager: UndoManager? = nil) {
        let before = TaskSnapshot(task)
        task.stop()
        save()

        // Only register if something actually changed.
        let after = TaskSnapshot(task)
        if before != after {
            undoManager?.registerUndo(withTarget: self) { target in
                target.apply(snapshot: before, undoManager: undoManager, actionName: "Stop Timer")
            }
            undoManager?.setActionName("Stop Timer")
        }
    }

    @discardableResult
    func addNewTask(description: String, startTime: Date, endTime: Date? = nil, isActive: Bool = false, undoManager: UndoManager? = nil) -> Task {
        let newTask = Task(taskDescription: description, startTime: startTime, isActive: isActive)
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

        return newTask
    }

    func updateTask(_ task: Task, startTime: Date, endTime: Date?, description: String, undoManager: UndoManager? = nil) {
        let before = TaskSnapshot(task)
        task.update(startTime: startTime, endTime: endTime, description: description)
        save()

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
        if fetchTask(id: snapshot.id) != nil {
            apply(snapshot: snapshot, undoManager: undoManager, actionName: actionName)
            return
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

