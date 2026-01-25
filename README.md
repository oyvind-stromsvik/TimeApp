# TimeApp

A native macOS time tracking app built with Swift and SwiftUI, using SwiftData for persistence. The app was inspired by Toggl Track, which was the app I've been using previously, but it and other time tracking apps don't support tracking time on multiple tasks simultaneously. This was the main reason for making this app. I use active timers tracking my workday and I wanted the ability to run multiple at once if I was in a meeting while working on something else, or waiting for automations to finish on one task while working on another.

_**Note:**  A large part of this app and this README was vibed, hence all the nonsense in both code and descriptions._

## Key Features

- **24-Hour Timeline View**: Full calendar day visualization
- **Quick Add**: Click anywhere in the timeline to instantly create or edit a time entry
- **Drag & Drop**: Intuitively drag time entries to change their start and end times
- **Resizable Blocks**: Grab the top or bottom edge of any entry to adjust its duration
- **Multiple Simultaneous Tasks**: Run multiple tasks concurrently (configurable in settings)
- **Overlapping Entries**: Parallel tasks displayed side-by-side in the day view
- **Active Task Display**: Running tasks highlighted in sidebar and menu bar
- **Selection & Management**: Select entries to edit description, start time, end time, duration, delete them, or restart tasks
- **Task Grouping**: Similar-named tasks automatically stack in the sidebar
- **Date Navigation**: Previous/Next day buttons and "Today" quick access
- **Undo/Redo**: Full support for undoing and redoing operations
- **Idle Detection**: Get notified when the system has been idle for a configurable threshold (default: 5 minutes)
- **Aggressive Alerts**: Optional alerts to start tracking when no task is running (default: 60 seconds)
- **Menu Bar Integration**: Always-visible timer in the menu bar with quick access to active tasks
- **Persistent Storage**: All tasks automatically saved using SwiftData
- **Configurable Settings**: Configure idle detection, alerts, task behavior from the settings view

## Requirements

- **macOS**: 14.0 or later
- **Xcode**: 16+ (for building from source)
- **Swift**: 5.0

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Time
   ```

2. Open in Xcode:
   ```bash
   open Time.xcodeproj
   ```

3. Build and run:
   - Select the "Time" scheme
   - Press `Cmd + R` to build and run

### Command Line Build

```bash
# Build from command line
xcodebuild build -scheme Time -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme Time -destination 'platform=macOS'
```

## Usage

### Creating and Managing Tasks

1. **Create a Task**: Click anywhere in the timeline to create a new task at that time
2. **Enter Description**: Type a description for your task in the popover
3. **Adjust Times**: Use the time pickers or drag the task block to set start/end times
4. **Start Tracking**: Click "Start" to begin tracking time from the current moment
5. **Stop Tracking**: Click "Stop" on an active task or start a new task

### Editing Tasks

- **Move**: Drag a task block up or down the timeline to change its start time
- **Resize**: Drag the top or bottom edge to adjust the task's duration
- **Edit Details**: Click on any task to open the editor popover
- **Delete**: Select a task and press Delete or use the delete button in the popover
- **Restart**: Click the restart button on a previous task to start a new instance

### Settings

Access Settings from the menu bar to configure:

- **Idle Detection**: Enable/disable idle time notifications and set threshold (default: 5 minutes)
- **Aggressive Alerts**: Enable/disable reminders when no task is running
- **Simultaneous Tasks**: Allow or prevent multiple active tasks at once
- **Task Confirmation**: Choose whether to confirm before stopping active tasks when starting a new one

### Menu Bar

The menu bar extra shows:
- Active task timer (or "No active task")
- Quick access to all running tasks
- Click to view and manage active tasks

## Tech Stack

- **Swift 5.0**: Primary programming language
- **SwiftUI**: Declarative UI framework for building responsive interfaces
- **SwiftData**: Modern data persistence layer (replaces Core Data)
- **AppKit**: Native macOS integration (NSWindow, NSApp, NSUndoManager)
- **UserNotifications**: System notifications for idle and aggressive alerts
- **CoreGraphics**: System idle time detection via CGEventSource

## Architecture

**Time** is a native macOS app built with modern Swift technologies, following clean architecture patterns.

### Core Components

- **TimeApp.swift** - App entry point. Initializes SwiftData ModelContainer and AppManager, provides both a main window and MenuBarExtra scene.

- **AppManager.swift** - Central state manager using `@Observable`. Handles:
  - Task CRUD operations via SwiftData
  - Timer lifecycle (1-second tick updates)
  - Undo/redo with NSUndoManager and TaskSnapshot pattern
  - System idle detection via CoreGraphics
  - Idle notifications (5-min threshold while tracking, 60-sec if no active task)
  - Selection and popover state management

- **Task.swift** - SwiftData model representing a time entry with:
  - Properties: id, description, startTime, endTime, isActive
  - Computed: duration, formattedDuration, overlap detection helpers

- **AppTheme.swift** - Centralized design constants:
  - Snap intervals (5 minutes)
  - Hour height (default 64, range 40-240)
  - Pastel color palette (10 colors)
  - Standard animations (snappy, 0.18 seconds)
  - Sidebar sizing (default 280, min 200, max 500)

### View Hierarchy

```
ContentView (NavigationSplitView)
├── SidebarView (sidebar - active tasks list, date navigation)
└── DayView (detail - 24-hour scrollable timeline)
    ├── TimelineGrid (background grid with hour markers)
    ├── CurrentTimeIndicator (red "now" line)
    └── TaskLayoutView (handles overlapping task layout)
        └── TaskBlock (individual task with drag/resize gestures)
            └── EditTaskView (popover for editing task details)

MenuBarExtra
└── MenuBarLabel (timer display)
    └── MenuBarTaskList (quick task management)
```

### Project Structure

```
Time/
├── App/
│   ├── TimeApp.swift          # App entry point and scene configuration
│   └── AppTheme.swift         # Design system and constants
├── Managers/
│   ├── AppManager.swift       # Central state management (582 lines)
│   └── Services.swift         # Service abstractions (Timer, System)
├── Models/
│   └── Task.swift             # SwiftData task model
└── Views/
    ├── ContentView.swift      # Main navigation split view
    ├── DayView.swift          # 24-hour timeline view
    ├── SidebarView.swift      # Task list sidebar
    ├── EditTaskView.swift     # Task editor popover
    ├── SettingsView.swift     # Preferences window
    ├── MenuBarLabel.swift     # Menu bar timer display
    ├── MenuBarTaskList.swift  # Menu bar quick task list
    ├── Shared/
    │   └── AppStyles.swift    # Common style modifiers
    └── Day/
        ├── TaskBlock.swift            # Draggable/resizable task
        ├── TaskLayoutView.swift       # Overlapping layout logic
        ├── TimelineGrid.swift         # Background grid rendering
        ├── CurrentTimeIndicator.swift # "Now" indicator line
        └── View+Cursor.swift          # Cursor customization
```

### Key Patterns

- **Centralized State**: AppManager holds `selectedTask`, `hasUnsavedChanges`, and `showingDiscardAlert` - use these instead of local @State
- **Task Selection**: Use `manager.selectTask()` for animated selection, or set `manager.selectedTask` directly when opening popovers
- **Task Creation**: Use `manager.createTask()` with `selectAfterCreation: true` to create and select in one call
- **Drag State**: TaskBlock uses a `DragState` struct to consolidate drag/resize state initialization
- **Popovers**: Single source of truth via `manager.popoverLocation` enum (`.none`, `.dayView(taskID:)`, `.sidebar(taskID:)`). Use `manager.openPopover(for:from:)` to open (handles unsaved changes check) and `manager.closePopover()` to close
- **View Modifiers**: Use `.unsavedChangesAlert(manager:)` for consistent discard alert handling
- **Animations**: Use `AppTheme.Animation.standard` instead of hardcoded values
- **5-Minute Snapping**: All timeline operations snap to 5-minute intervals
- **Menu Bar Integration**: Uses SwiftUI `MenuBarExtra` for always-visible timer status
- **Service Abstraction**: Protocol-based services (TimerService, SystemService) for testability
- **Observable Pattern**: Reactive state management with `@Observable` macro
- **Environment Injection**: SwiftUI environment for dependency management

## Bundle Information

- **Bundle ID**: `TwiiK.Time`
- **Product Name**: Time
- **Platform**: macOS 14.0+
- **Category**: Productivity / Time Tracking

## Development

### Testing

Run unit tests in Xcode:
```bash
Cmd + U
```

Or from command line:
```bash
xcodebuild test -scheme Time -destination 'platform=macOS'
```
