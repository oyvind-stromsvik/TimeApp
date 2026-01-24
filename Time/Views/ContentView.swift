import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @Environment(\.undoManager) private var undoManager
    @State private var selectedDate = Date()
    @State private var newTaskDescription = ""
    @State private var hourHeight: CGFloat = AppTheme.Timeline.defaultHourHeight
    @AppStorage("allowSimultaneousTasks") private var allowSimultaneousTasks: Bool = true

    var body: some View {
        @Bindable var bindableManager = manager

        VStack(spacing: 0) {
            // Secondary Toolbar - spans full width over sidebar
            HStack(spacing: AppTheme.Spacing.xxxl) {
                // Date Navigation
                HStack(spacing: 1) {
                    Button {
                        selectedDate = previousDay(from: selectedDate)
                    } label: {
                        Image(systemName: "chevron.left")
                            .imageScale(.medium)
                            .frame(width: 28, height: 26)
                    }

                    Divider().frame(height: AppTheme.Spacing.xxl)

                    Button {
                        selectedDate = Date()
                    } label: {
                        Text("Today")
                            .font(AppTheme.Typography.rowPrimaryText())
                            .frame(height: 26)
                            .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    Divider().frame(height: AppTheme.Spacing.xxl)

                    Button {
                        selectedDate = nextDay(from: selectedDate)
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .frame(width: 28, height: 26)
                    }
                }
                .buttonStyle(.borderless)
                .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md).fill(Color.secondary.opacity(0.1)))

                Text(formattedDateForHeader(selectedDate))
                    .font(.system(size: AppTheme.Typography.headline, weight: .semibold))

                Spacer()

                // Zoom Controls
                HStack(spacing: AppTheme.Spacing.lg) {
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            hourHeight = max(AppTheme.Timeline.minHourHeight, hourHeight - AppTheme.Timeline.hourHeightStep)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(hourHeight <= AppTheme.Timeline.minHourHeight)

                    Slider(value: $hourHeight, in: AppTheme.Timeline.minHourHeight...AppTheme.Timeline.maxHourHeight)
                        .frame(width: 100)
                        .controlSize(.mini)

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            hourHeight = min(AppTheme.Timeline.maxHourHeight, hourHeight + AppTheme.Timeline.hourHeightStep)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(hourHeight >= AppTheme.Timeline.maxHourHeight)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xxl)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Divider() }

            HStack(spacing: 0) {
                SidebarContainer(
                    isVisible: Binding(
                        get: { manager.isSidebarVisible },
                        set: { manager.isSidebarVisible = $0 }
                    ),
                    width: Binding(
                        get: { manager.sidebarWidth },
                        set: { manager.sidebarWidth = $0 }
                    )
                ) {
                    SidebarView(selectedDate: selectedDate)
                        .background(.regularMaterial)
                }

                Divider()

                DayView(date: selectedDate, onDateChange: { selectedDate = $0 }, hourHeight: $hourHeight)
                    .frame(minWidth: 100, idealWidth: AppTheme.mainWidth, maxWidth: .infinity)
            }
        }
        .coordinateSpace(name: "contentArea")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.isSidebarVisible.toggle()
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: AppTheme.Spacing.md) {
                    TextField("What are you working on?", text: $newTaskDescription)
                        .textFieldStyle(.plain)
                        .appCardField(padding: AppTheme.Spacing.md, cornerRadius: AppTheme.CornerRadius.md)
                        .frame(width: 300)
                        .onSubmit(startTask)

                    Button(action: startTask) {
                        AppCircleIcon(
                            systemName: "play.fill",
                            size: 28,
                            iconSize: 11,
                            background: AppTheme.Gradients.accentGradient
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog(
            "Stop active tasks?",
            isPresented: $bindableManager.showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Others") {
                manager.confirmStopAndStart()
            }
            Button("Keep All") {
                manager.confirmKeepAndStart()
            }
            Button("Cancel", role: .cancel) {
                manager.cancelPendingTask()
            }
        } message: {
            Text("You already have active tasks running. Would you like to stop them before starting the new one?")
        }
    }

    private func startTask() {
        let description = newTaskDescription.isEmpty ? "New task" : newTaskDescription
        manager.addNewTask(description: description, startTime: Date(), endTime: nil, isActive: true, undoManager: undoManager)
        newTaskDescription = ""
    }

    private func previousDay(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
    }

    private func nextDay(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private func formattedDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter.string(from: date)
    }
}

// MARK: - Sidebar Container with Resize

private struct SidebarContainer<Content: View>: View {
    @Binding var isVisible: Bool
    @Binding var width: CGFloat
    @ViewBuilder let content: Content

    @GestureState private var dragState: DragState = .inactive

    private enum DragState {
        case inactive
        case dragging(width: CGFloat, collapsed: Bool)

        var isDragging: Bool {
            if case .dragging = self { return true }
            return false
        }

        var isCollapsed: Bool {
            if case .dragging(_, let collapsed) = self { return collapsed }
            return false
        }

        var width: CGFloat? {
            if case .dragging(let w, _) = self { return w }
            return nil
        }
    }

    private var effectiveWidth: CGFloat {
        dragState.width ?? width
    }

    private var displayWidth: CGFloat {
        if dragState.isDragging && dragState.isCollapsed {
            return 0
        }
        return effectiveWidth
    }

    var body: some View {
        Group {
            if isVisible || dragState.isDragging {
                content
                    .frame(width: displayWidth)
                    .clipped()
                    .overlay(alignment: .trailing) {
                        resizeHandle
                    }
            }
        }
    }

    private var resizeHandle: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .offset(x: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("contentArea"))
                    .updating($dragState) { value, state, _ in
                        let newWidth = value.location.x
                        let collapsed = newWidth < AppTheme.sidebarCollapseThreshold
                        let clampedWidth = min(max(newWidth, AppTheme.sidebarMinWidth), AppTheme.sidebarMaxWidth)
                        state = .dragging(width: clampedWidth, collapsed: collapsed)
                    }
                    .onEnded { value in
                        let finalWidth = value.location.x
                        if finalWidth < AppTheme.sidebarCollapseThreshold {
                            isVisible = false
                        } else {
                            width = min(max(finalWidth, AppTheme.sidebarMinWidth), AppTheme.sidebarMaxWidth)
                        }
                    }
            )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let manager = AppManager(modelContext: container.mainContext)
    let today = Date()
    
    let start1 = today.addingTimeInterval(-10000)
    let end1 = today.addingTimeInterval(-7200)
    let task1 = Task(taskDescription: "Daily Standup", startTime: start1, isActive: false)
    task1.endTime = end1
    container.mainContext.insert(task1)
    
    let start2 = today.addingTimeInterval(-3600)
    let task2 = Task(taskDescription: "Working on UI Previews", startTime: start2, isActive: true)
    container.mainContext.insert(task2)
    
    return ContentView()
        .modelContainer(container)
        .environment(manager)
}
