import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var manager
    @State private var selectedDate = Date()
    @State private var hourHeight: CGFloat = AppTheme.Timeline.defaultHourHeight
    @AppStorage("allowSimultaneousTasks") private var allowSimultaneousTasks: Bool = true

    private var windowMinWidth: CGFloat {
        let sidebarWidth = manager.isSidebarVisible ? max(manager.sidebarWidth, AppTheme.sidebarMinWidth) : 0
        return AppTheme.mainViewMinWidth + sidebarWidth
    }

    var body: some View {
        @Bindable var bindableManager = manager

        VStack(spacing: 0) {
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
                    .frame(minWidth: AppTheme.mainViewMinWidth, maxWidth: .infinity)
            }
        }
        .background(WindowTitleHider(minWidth: windowMinWidth))
        .coordinateSpace(name: "contentArea")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 18, weight: .light))
                }
                .padding(.top, 4)
                .keyboardShortcut("0", modifiers: .command)
            }
        }
        .toolbarBackground(.regularMaterial, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
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
        .sheet(item: $bindableManager.focusModal) { modal in
            switch modal {
            case .idle:
                IdleAlertModalView(
                    idleDuration: manager.idleDuration,
                    idleStartTime: manager.idleStartTime,
                    onDiscard: { manager.discardIdleTimeAndContinue() },
                    onKeep: { manager.keepIdleTime() }
                )
            case .noActiveTasks:
                NoActiveTasksModalView {
                    manager.dismissNoActiveTasksAlert()
                }
            case .trackingCheck:
                TrackingCheckModalView(
                    onConfirm: { manager.dismissTrackingCheckAlert() },
                    onSwitch: {
                        manager.stopAllActiveTasks()
                        manager.dismissTrackingCheckAlert()
                    }
                )
            }
        }
    }

}

private struct WindowTitleHider: NSViewRepresentable {
    let minWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(window: nsView.window, minWidth: minWidth)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var titleObservation: NSKeyValueObservation?
        private var minWidth: CGFloat = 0

        func update(window: NSWindow?, minWidth: CGFloat) {
            guard let window else { return }
            if window != self.window {
                removeObservers()
                self.window = window
                self.minWidth = minWidth
                addObservers(for: window)
            }
            if self.minWidth != minWidth {
                self.minWidth = minWidth
            }
            apply(to: window, minWidth: minWidth)
        }

        private func addObservers(for window: NSWindow) {
            let center = NotificationCenter.default
            let applyHandler: (Notification) -> Void = { [weak self] _ in
                guard let self, let window = self.window else { return }
                self.apply(to: window, minWidth: self.minWidth)
            }
            observers.append(center.addObserver(forName: NSWindow.didUpdateNotification, object: window, queue: .main, using: applyHandler))
            observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main, using: applyHandler))
            observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main, using: applyHandler))

            titleObservation = window.observe(\.title, options: [.new]) { [weak self] window, _ in
                guard let self else { return }
                self.apply(to: window, minWidth: self.minWidth)
            }
        }

        private func apply(to window: NSWindow, minWidth: CGFloat) {
            if window.contentMinSize.width != minWidth {
                let contentMinSize = NSSize(width: minWidth, height: window.contentMinSize.height)
                window.contentMinSize = contentMinSize
                window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentMinSize)).size
            }
            window.toolbar?.showsBaselineSeparator = false
            if window.toolbarStyle != .unified {
                window.toolbarStyle = .unified
            }
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
            titleObservation = nil
        }

        deinit {
            removeObservers()
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
