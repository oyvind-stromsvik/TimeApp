//
//  DayView.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    @Query private var timeEntries: [TimeEntry]
    @State private var selectedEntry: TimeEntry?
    @State private var showingEditSheet = false
    
    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<TimeEntry> { entry in
            entry.startTime >= startOfDay && entry.startTime < endOfDay
        }
        
        _timeEntries = Query(filter: predicate, sort: \TimeEntry.startTime)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(date, format: .dateTime.day().month().year())
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Total: \(totalTimeFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Time grid
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24) { hour in
                        HourRow(hour: hour, entries: entriesForHour(hour), date: date)
                            .onTapGesture {
                                // Could add functionality to start a timer at this hour
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let entry = selectedEntry {
                EditTimeEntryView(entry: entry)
            }
        }
    }
    
    private var totalTimeFormatted: String {
        let totalSeconds = timeEntries.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func entriesForHour(_ hour: Int) -> [TimeEntry] {
        let calendar = Calendar.current
        let startOfHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour)!
        
        return timeEntries.filter { entry in
            entry.startTime < endOfHour && (entry.endTime ?? Date()) > startOfHour
        }
    }
}

struct HourRow: View {
    let hour: Int
    let entries: [TimeEntry]
    let date: Date
    @State private var selectedEntry: TimeEntry?
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Hour label
            VStack {
                Text(String(format: "%02d:00", hour))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                Spacer()
            }
            .frame(width: 60, height: 60)
            
            // Time entries
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 60)
                
                ForEach(entries) { entry in
                    TimeEntryBlock(entry: entry, date: date)
                        .onTapGesture {
                            selectedEntry = entry
                            showingEditSheet = true
                        }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let entry = selectedEntry {
                EditTimeEntryView(entry: entry)
            }
        }
    }
}

struct TimeEntryBlock: View {
    let entry: TimeEntry
    let date: Date
    
    var body: some View {
        let position = calculatePosition()
        
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.taskDescription)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(entry.formattedDuration)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(entry.isActive ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(entry.isActive ? Color.blue : Color.green, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: position.y)
        .frame(height: position.height)
    }
    
    private func calculatePosition() -> (y: CGFloat, height: CGFloat) {
        let calendar = Calendar.current
        
        let startMinutes = calendar.component(.minute, from: entry.startTime)
        let startSeconds = calendar.component(.second, from: entry.startTime)
        let startOffset = CGFloat(startMinutes * 60 + startSeconds) / 3600.0 * 60.0
        
        let endTime = entry.endTime ?? Date()
        let endMinutes = calendar.component(.minute, from: endTime)
        let endSeconds = calendar.component(.second, from: endTime)
        let endOffset = CGFloat(endMinutes * 60 + endSeconds) / 3600.0 * 60.0
        
        let height = max(20, endOffset - startOffset)
        
        return (y: startOffset, height: height)
    }
}

#Preview {
    DayView(date: Date())
        .modelContainer(for: TimeEntry.self, inMemory: true)
} 