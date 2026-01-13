import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @Query(filter: #Predicate<Task> { $0.isActive == true }, sort: \Task.startTime) private var activeTasks: [Task]

    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("START NEW TIMER")
                    .appSectionHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                HStack(spacing: 8) {
                    TextField("What are you working on?", text: $newTimerDescription)
                        .textFieldStyle(.plain)
                        .appCardField(padding: 10, cornerRadius: 8)
                        .onSubmit(startTimer)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.Colors.separator.opacity(0.35), lineWidth: 1)
                        }
                    
                    Button(action: startTimer) {
                        AppCircleIcon(
                            systemName: "play.fill",
                            size: 32,
                            iconSize: 12,
                            background: AppTheme.Gradients.accentGradient
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(newTimerDescription.isEmpty ? 0.98 : 1)
                    .animation(AppTheme.Animation.standard, value: newTimerDescription.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            if activeTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "timer")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextFaint))
                    
                    
                    Text("No Active Timers")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start a new timer to begin tracking time.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.secondaryTextStrong))
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
                            .appSectionHeader()
                            .padding(.vertical, 8)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.Surfaces.sidebar)
    }
    
    private func startTimer() {
        let description = newTimerDescription.isEmpty ? "New task" : newTimerDescription
        manager.addNewTask(description: description, startTime: Date(), endTime: nil, isActive: true, undoManager: undoManager)
        newTimerDescription = ""
    }
}

/// An active task/timer in the sidebar.
struct ActiveTimerRow: View {
    @Bindable var task: Task

    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var isHovering = false

    private var showingPopover: Bool {
        manager.popoverLocation == .sidebar(taskID: task.id)
    }

    var body: some View {
        let _ = manager.lastTick
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Colors.activeTimer)
                        .frame(width: 6, height: 6)
                        .symbolEffect(.pulse, value: manager.lastTick)
                        .offset(x: 1)

                    Text(task.formattedDuration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.activeTimer)
                        .symbolEffect(.pulse)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    manager.stopTimer(task, undoManager: undoManager)
                }
            } label: {
                AppCircleIcon(
                    systemName: "stop.fill",
                    size: 26,
                    iconSize: 10,
                    background: AppTheme.Colors.destructive
                )
                .cursor(.pointingHand)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? AppTheme.Colors.tertiaryFill : .clear)
        )
        .animation(AppTheme.Animation.standard, value: isHovering)
        .onTapGesture {
            manager.openPopover(for: task, from: .sidebar(taskID: task.id))
            manager.selectTask(task)
        }
        .popover(
            isPresented: Binding(
                get: { showingPopover },
                set: { if !$0 { manager.closePopover() } }
            ),
            arrowEdge: .trailing
        ) {
            EditTaskView(task: task, manager: manager)
                .presentationCompactAdaptation(.none)
        }
        .onHover { hovering in
            isHovering = hovering
        }
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

