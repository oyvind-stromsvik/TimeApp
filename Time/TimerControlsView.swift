//
//  TimerControlsView.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TimeEntry> { $0.isActive == true }, sort: \TimeEntry.startTime) private var activeEntries: [TimeEntry]
    
    @State private var showingNewTimerSheet = false
    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Active Timers")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingNewTimerSheet = true }) {
                    Label("New Timer", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if activeEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No active timers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start a new timer to begin tracking your time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Active timers list
                LazyVStack(spacing: 12) {
                    ForEach(activeEntries) { entry in
                        ActiveTimerRow(entry: entry)
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingNewTimerSheet) {
            NewTimerSheet(description: $newTimerDescription, isPresented: $showingNewTimerSheet)
        }
    }
}

struct ActiveTimerRow: View {
    @Environment(\.modelContext) private var modelContext
    let entry: TimeEntry
    @State private var currentTime = Date()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.taskDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Started: \(entry.startTime, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedDuration)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(.blue)
                
                Text("Running")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Button(action: stopTimer) {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            // Update the timer display every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
    
    private func stopTimer() {
        entry.stop()
        
        do {
            try modelContext.save()
        } catch {
            print("Error stopping timer: \(error)")
        }
    }
}

struct NewTimerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var description: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Timer Details") {
                    TextField("What are you working on?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        description = ""
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startNewTimer()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func startNewTimer() {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let newEntry = TimeEntry(taskDescription: trimmedDescription)
        modelContext.insert(newEntry)
        
        do {
            try modelContext.save()
            description = ""
            isPresented = false
        } catch {
            print("Error starting new timer: \(error)")
        }
    }
}

#Preview {
    TimerControlsView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
} 