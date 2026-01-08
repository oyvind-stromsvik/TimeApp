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

    func stopTimer(_ task: Task) {
        task.stop()
        save()
    }

    func addNewTask(description: String, startTime: Date, endTime: Date? = nil, isActive: Bool = false) {
        let newTask = Task(taskDescription: description, startTime: startTime, isActive: isActive)
        newTask.endTime = endTime
        modelContext.insert(newTask)
        save()
    }

    func updateTask(_ task: Task, startTime: Date, endTime: Date?, description: String) {
        task.update(startTime: startTime, endTime: endTime, description: description)
        save()
    }
    
    func duplicateTask(_ task: Task) {
        let newTask = Task(
            taskDescription: task.taskDescription,
            startTime: task.startTime,
            hexColor: task.hexColor,
            isActive: false
        )
        newTask.endTime = task.endTime
        modelContext.insert(newTask)
        save()
    }
    
    func deleteTask(_ task: Task) {
        modelContext.delete(task)
        save()
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

