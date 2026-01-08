//
//  TimerManager.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
class TimerManager {
    private var timer: Timer?
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // This will trigger UI updates for active timers
        }
    }
    
    func startNewTimer(description: String) {
        let newEntry = TimeEntry(taskDescription: description)
        modelContext.insert(newEntry)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving new timer: \(error)")
        }
    }
    
    func stopTimer(_ entry: TimeEntry) {
        entry.stop()
        
        do {
            try modelContext.save()
        } catch {
            print("Error stopping timer: \(error)")
        }
    }
    
    func deleteTimer(_ entry: TimeEntry) {
        modelContext.delete(entry)
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting timer: \(error)")
        }
    }
} 