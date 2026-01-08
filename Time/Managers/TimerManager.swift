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
        let newEntry = TimeEntry(taskDescription: description, startTime: startTime)
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
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}
 
