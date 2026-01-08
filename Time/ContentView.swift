//
//  ContentView.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with timer controls
            VStack(spacing: 0) {
                // Date selector
                HStack {
                    Button(action: { showingDatePicker = true }) {
                        HStack {
                            Text(selectedDate, format: .dateTime.day().month().year())
                                .font(.headline)
                            
                            Image(systemName: "calendar")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Divider()
                
                // Timer controls
                TimerControlsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 350)
            .navigationTitle("Time Tracker")
        } detail: {
            // Day view
            DayView(date: selectedDate)
                .navigationTitle("Day View")
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate, isPresented: $showingDatePicker)
        }
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Select Date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
}
