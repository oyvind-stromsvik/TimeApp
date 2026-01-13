# Time

A beautiful, native macOS time tracking application built with Swift and SwiftUI. Inspired by the simplified experience of Toggl Track's day view, **Time** is designed to provide a productive, visual, and seamless way to manage your daily tasks.

## 🚀 Overview

**Time** focuses on a visual "Day View" that allows you to track exactly what you're currently working on. Whether you're tracking a single task or managing multiple overlapping projects, the application provides an intuitive interface to track your work in real-time or after the fact.

## ✨ Key Features

- **Visual Day Calendar**: 
    - Full 24-hour view (00:00 - 24:00).
    - Smooth zoom functionality to focus on specific time blocks (e.g., 08:00 - 16:00).
    - Beautiful, native macOS UI that feels right at home on macOS.

- **Interactive Time Tracking**:
    - **Multiple Timers**: Start and run as many timers as needed simultaneously.
    - **Overlapping Entries**: Support for parallel tasks, displayed side-by-side in the day view.
    - **Quick Add**: Click anywhere in the day view to instantly create or edit a time entry.

- **Seamless Editing & Organization**:
    - **Drag & Drop**: Intuitively drag and drop time entries to change their start and end times.
    - **Resizeable Blocks**: Grab the top or bottom edge of any entry to stretch or shrink its duration.
    - **Selection & Management**: Select entries to edit description, start time, end time, duration, delete them, or restart a timer for an existing task.

## 🛠 Tech Stack

- **Swift**: The powerful, modern language for Apple platforms.
- **SwiftUI**: A declarative framework for building beautiful, responsive user interfaces.
- **Native macOS Implementation**: Leverages native components for performance and the standard macOS "look and feel."

## Build Commands

This is an Xcode project (no Package.swift). Build and run with:

```bash
# Open in Xcode
open Time.xcodeproj

# Build from command line
xcodebuild build -scheme Time -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme Time -destination 'platform=macOS'
```

Requires Xcode 16+ and macOS 14.0+.

## Architecture

**Time** is a native macOS time tracking app built with Swift/SwiftUI and SwiftData for persistence.

### Core Components

- **TimeApp.swift** - App entry point. Initializes SwiftData ModelContainer and AppManager, provides both a main window and MenuBarExtra scene.

- **AppManager.swift** - Central state manager using `@Observable`. Handles:
  - Task CRUD operations via SwiftData
  - Timer lifecycle (1-second tick updates)
  - Undo/redo with NSUndoManager and TaskSnapshot pattern
  - System idle detection via CoreGraphics
  - Idle notifications (5-min threshold while tracking, 60-sec if no active timer)

- **Task.swift** - SwiftData model representing a time entry with title, start/end times, color, and optional notes.

- **AppTheme.swift** - Centralized design constants (hour height, snap intervals, colors, materials).

### View Hierarchy

```
ContentView (NavigationSplitView)
├── TimerControlsView (sidebar - active timers list)
└── DayView (detail - 24-hour scrollable timeline)
    ├── TimelineGrid (background grid)
    ├── CurrentTimeIndicator (red "now" line)
    └── TaskLayoutView (handles overlapping task layout)
        └── TaskBlock (individual task with drag/resize gestures)
            └── EditTaskView (popover for editing)
```

### Key Patterns

- **Centralized State**: AppManager holds `selectedTask`, `hasUnsavedChanges`, and `showingDiscardAlert` - use these instead of local @State
- **Task Selection**: Use `manager.selectTask()` for animated selection, or set `manager.selectedTask` directly when opening popovers
- **Task Creation**: Use `manager.createTask()` with `selectAfterCreation: true` to create and select in one call
- **Drag State**: TaskBlock uses a `DragState` struct to consolidate drag/resize state initialization
- **Popovers**: Single source of truth via `manager.popoverLocation` enum (`.none`, `.dayView(taskID:)`, `.sidebar(taskID:)`). Use `manager.openPopover(for:from:)` to open (handles unsaved changes check) and `manager.closePopover()` to close
- **View Modifiers**: Use `.unsavedChangesAlert(manager:)` for consistent discard alert handling
- **Animations**: Use `AppTheme.Animation.standard` instead of hardcoded `.snappy(duration: 0.18)`
- **5-Minute Snapping**: All timeline operations snap to 5-minute intervals
- **Menu Bar Integration**: Uses SwiftUI `MenuBarExtra` for always-visible timer status
