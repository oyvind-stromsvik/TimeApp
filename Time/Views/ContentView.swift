import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @State private var selectedDate = Date()
    
    var body: some View {
        @Bindable var bindableManager = manager
        
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
                TimerControlsView()
                    .background(.regularMaterial)
            }
            
            Divider()
            
            DayView(date: selectedDate, onDateChange: { selectedDate = $0 })
                .frame(minWidth: 100, idealWidth: AppTheme.mainWidth, maxWidth: .infinity)
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
        }
        .alert("Time to Track!", isPresented: $bindableManager.showAggressiveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have no active timers running.")
        }
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
