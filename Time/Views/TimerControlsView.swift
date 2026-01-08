import SwiftUI
import SwiftData

struct TimerControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    @Query(filter: #Predicate<TimeEntry> { $0.isActive == true }, sort: \TimeEntry.startTime) private var activeEntries: [TimeEntry]
    
    @State private var newTimerDescription = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Start Field
            VStack(alignment: .leading, spacing: 8) {
                Text("TRACK NEW TASK")
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
                            .background {
                                if newTimerDescription.isEmpty {
                                    Color.secondary.opacity(0.3)
                                } else {
                                    AppTheme.Gradients.accentGradient
                                }
                            }
                            .clipShape(Circle())
                            .shadow(color: Color.blue.opacity(newTimerDescription.isEmpty ? 0 : 0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTimerDescription.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            if activeEntries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "timer")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("No Active Timers")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start a task to begin tracking time.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(activeEntries) { entry in
                            ActiveTimerRow(entry: entry)
                        }
                    } header: {
                        Text("ACTIVE TASKS")
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
        guard !newTimerDescription.isEmpty else { return }
        timerManager.startNewTimer(description: newTimerDescription)
        newTimerDescription = ""
    }
}

struct ActiveTimerRow: View {
    @Bindable var entry: TimeEntry
    @Environment(TimerManager.self) private var timerManager
    
    var body: some View {
        let _ = timerManager.lastTick
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.taskDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .symbolEffect(.pulse, value: timerManager.lastTick)
                    
                    Text(entry.formattedDuration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    timerManager.stopTimer(entry)
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.red.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TimeEntry.self, configurations: config)
    let manager = TimerManager(modelContext: container.mainContext)
    
    return TimerControlsView()
        .modelContainer(container)
        .environment(manager)
}
