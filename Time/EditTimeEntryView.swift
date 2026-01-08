//
//  EditTimeEntryView.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import SwiftUI
import SwiftData

struct EditTimeEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let entry: TimeEntry
    
    @State private var taskDescription: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isActive: Bool
    
    init(entry: TimeEntry) {
        self.entry = entry
        self._taskDescription = State(initialValue: entry.taskDescription)
        self._startTime = State(initialValue: entry.startTime)
        self._endTime = State(initialValue: entry.endTime ?? Date())
        self._isActive = State(initialValue: entry.isActive)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Description", text: $taskDescription)
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    
                    if !isActive {
                        DatePicker("End Time", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Currently Active", isOn: $isActive)
                        .onChange(of: isActive) { _, newValue in
                            if newValue {
                                endTime = Date()
                            }
                        }
                }
                
                Section("Duration") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !isActive {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            deleteEntry()
                        }
                    }
                }
            }
            .navigationTitle("Edit Time Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private var formattedDuration: String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func saveChanges() {
        if isActive {
            entry.update(startTime: startTime, endTime: Date(), description: taskDescription)
            entry.isActive = true
        } else {
            entry.update(startTime: startTime, endTime: endTime, description: taskDescription)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error)")
        }
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting entry: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let entry = TimeEntry(taskDescription: "Sample Task")
    
    return EditTimeEntryView(entry: entry)
        .modelContainer(container)
} 