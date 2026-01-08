//
//  TimeEntry.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var taskDescription: String
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    init(taskDescription: String, startTime: Date = Date()) {
        self.id = UUID()
        self.taskDescription = taskDescription
        self.startTime = startTime
        self.endTime = nil
        self.isActive = true
    }
    
    func stop() {
        self.endTime = Date()
        self.isActive = false
    }
    
    func update(startTime: Date, endTime: Date, description: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.taskDescription = description
        self.isActive = false
    }
}
