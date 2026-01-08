import Foundation
import SwiftUI
import SwiftData

@Observable
class TimerManager {
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
        addEntry(description: description, startTime: startTime, isActive: true)
    }
    
    func addEntry(description: String, startTime: Date, endTime: Date? = nil, isActive: Bool = false) {
        let newEntry = TimeEntry(taskDescription: description, startTime: startTime, isActive: isActive)
        newEntry.endTime = endTime
        modelContext.insert(newEntry)
        save()
    }
    
    func stopTimer(_ entry: TimeEntry) {
        entry.stop()
        save()
    }
    
    func deleteTimer(_ entry: TimeEntry) {
        modelContext.delete(entry)
        save()
    }
    
    func duplicateTimer(_ entry: TimeEntry) {
        let newEntry = TimeEntry(
            taskDescription: entry.taskDescription,
            startTime: entry.startTime,
            hexColor: entry.hexColor,
            isActive: false
        )
        newEntry.endTime = entry.endTime
        modelContext.insert(newEntry)
        save()
    }
    
    func updateTimer(_ entry: TimeEntry, startTime: Date, endTime: Date?, description: String) {
        entry.update(startTime: startTime, endTime: endTime, description: description)
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

