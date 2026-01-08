import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TimerControlsView()
                .navigationSplitViewColumnWidth(min: 100, ideal: AppTheme.sidebarWidth, max: 400)
        } detail: {
            DayView(date: selectedDate)
                .frame(minWidth: 100, idealWidth: AppTheme.mainWidth, maxWidth: .infinity)
                .toolbar {
                    if columnVisibility == .detailOnly {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                                }
                            } label: {
                                Label("Toggle Sidebar", systemImage: "sidebar.left")
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .frame(width: 140)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDate = Date()
                            }
                        } label: {
                            Label("Today", systemImage: "calendar")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    // Add sample data for preview
    let today = Date()
    let calendar = Calendar.current
    
    // Morning entry
    let start1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end1 = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let entry1 = TimeEntry(taskDescription: "Daily Standup", startTime: start1, isActive: false)
    entry1.endTime = end1
    container.mainContext.insert(entry1)
    
    // Active entry
    let start2 = today.addingTimeInterval(-3600)
    let entry2 = TimeEntry(taskDescription: "Working on UI Previews", startTime: start2, isActive: true)
    container.mainContext.insert(entry2)
    
    return ContentView()
        .modelContainer(container)
        .environment(manager)
}
