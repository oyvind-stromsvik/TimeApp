import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Query(filter: #Predicate<Task> { $0.isActive == true }, sort: \Task.startTime) private var activeTasks: [Task]
    
    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("START NEW TIMER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                HStack(spacing: 8) {
                    TextField("What are you working on?", text: $newTimerDescription)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                        .onSubmit(startTimer)
                    
                    Button(action: startTimer) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Gradients.accentGradient)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            if activeTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "timer")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("No Active Timers")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start a new timer to begin tracking time.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(activeTasks) { task in
                            ActiveTimerRow(task: task)
                        }
                    } header: {
                        Text("ACTIVE TIMERS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(AppTheme.Colors.sidebarBackground)
    }
    
    private func startTimer() {
        let description = newTimerDescription.isEmpty ? "New task" : newTimerDescription
        manager.startNewTimer(description: description)
        newTimerDescription = ""
    }
}

/**
 * An active task/timer in the sidebar.
 */
struct ActiveTimerRow: View {
    @Bindable var task: Task
    @Environment(AppManager.self) private var manager
    @State private var isHovering = false
    
    var body: some View {
        let _ = manager.lastTick
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .symbolEffect(.pulse, value: manager.lastTick)
                        .offset(x: 1)
                    
                    Text(task.formattedDuration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                        .symbolEffect(.pulse)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    manager.stopTimer(task)
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(1))
                    .clipShape(Circle())
                    .cursor(.pointingHand)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let manager = AppManager(modelContext: container.mainContext)
    let today = Date()
    
    let start = today.addingTimeInterval(-3600)
    let task = Task(taskDescription: "Daily Standup", startTime: start, isActive: true)
    container.mainContext.insert(task)
    
    let start2 = today
    let task2 = Task(taskDescription: "Working on UI Previews", startTime: start2, isActive: true)
    container.mainContext.insert(task2)
    
    return TimerControlsView()
        .modelContainer(container)
        .environment(manager)
}
