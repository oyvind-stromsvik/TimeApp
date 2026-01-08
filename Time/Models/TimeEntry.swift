import Foundation
import SwiftData

@Model
final class TimeEntry: Identifiable {
    var id: UUID
    var taskDescription: String
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    
    // Optional color for visual distinction
    var hexColor: String?
    
    var duration: TimeInterval {
        if isActive {
            return Date().timeIntervalSince(startTime)
        } else if let end = endTime {
            return end.timeIntervalSince(startTime)
        }
        return 0
    }
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(max(0, duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDuration: String {
        Self.formatDuration(duration)
    }
    
    init(taskDescription: String, startTime: Date = Date(), hexColor: String? = nil, isActive: Bool = true) {
        self.id = UUID()
        self.taskDescription = taskDescription
        self.startTime = startTime
        self.endTime = nil
        self.isActive = isActive
        self.hexColor = hexColor
    }
    
    func stop() {
        self.endTime = Date()
        self.isActive = false
    }
    
    func update(startTime: Date, endTime: Date?, description: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.taskDescription = description
        self.isActive = (endTime == nil)
    }
    
    // Helper to check if this entry overlaps with another on the same day
    func overlaps(with other: TimeEntry) -> Bool {
        let selfEnd = endTime ?? Date()
        let otherEnd = other.endTime ?? Date()
        return startTime < otherEnd && other.startTime < selfEnd
    }
}
