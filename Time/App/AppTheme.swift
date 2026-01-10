import SwiftUI

struct AppTheme {
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
    static let sidebarWidth: CGFloat = 280
    static let mainWidth: CGFloat = 280

    struct Opacity {
        static let verySubtleBackground: Double = 0.02
        static let subtleBackground: Double = 0.05
        static let border: Double = 0.1
        static let divider: Double = 0.5

        static let secondaryTextFaint: Double = 0.3
        static let secondaryTextMedium: Double = 0.5
        static let secondaryTextStrong: Double = 0.6

        static let resizeHandle: Double = 0.4
        static let timeLabelBackground: Double = 0.85

        static let shadowResting: Double = 0.05
        static let shadowActive: Double = 0.15
        static let shadowFloating: Double = 0.1
    }

    struct Timing {
        /// Snap all timeline interactions to this interval (seconds).
        static let snapInterval: TimeInterval = 5 * 60

        /// Minimum allowed duration when resizing tasks (seconds).
        static let minimumTaskDuration: TimeInterval = 5 * 60

        /// Default duration when creating a task by clicking the timeline.
        static let defaultNewTaskDuration: TimeInterval = 30 * 60

        /// Convenience for minute-based snapping.
        static let snapMinutes: Int = 5
    }

    struct Timeline {
        static let hoursPerDay: Int = 24

        /// Default zoom level: height of one hour in points.
        static let defaultHourHeight: CGFloat = 64
        static let minHourHeight: CGFloat = 40
        static let maxHourHeight: CGFloat = 240
        static let hourHeightStep: CGFloat = 20

        /// Geometry for the left-side time labels / gutter.
        static let leadingGutterWidth: CGFloat = 64
        static let hourLabelWidth: CGFloat = 50
        static let hourLabelOffsetX: CGFloat = -58
        static let hourLabelOffsetY: CGFloat = -7
        static let hourLineOffsetX: CGFloat = -50

        /// Layout tweaks.
        static let minTaskHeight: CGFloat = 24

        /// On appear, scroll to (currentHour - this offset).
        static let initialScrollHourOffset: Int = 1
    }
    
    struct Colors {
        static let accent = Color.blue
        static let activeTimer = Color.blue
        static let completedTimer = Color(nsColor: .secondaryLabelColor).opacity(0.8)

        static let destructive = Color.red
        static let nowIndicator = Color.red

        static let fieldBackground = Color.secondary.opacity(AppTheme.Opacity.subtleBackground)
        static let fieldDisabledBackground = Color.secondary.opacity(AppTheme.Opacity.subtleBackground)
        static let fieldBorder = Color.secondary.opacity(AppTheme.Opacity.border)
        static let footerBackground = Color.secondary.opacity(AppTheme.Opacity.verySubtleBackground)

        static let timeLabelBackground = Color.black.opacity(AppTheme.Opacity.timeLabelBackground)
        static let resizeHandle = Color.secondary.opacity(AppTheme.Opacity.resizeHandle)
        static let gridLine = Color.secondary.opacity(AppTheme.Opacity.border)
        
        static var background: Color {
            Color(NSColor.windowBackgroundColor)
        }
        
        static var sidebarBackground: Color {
            Color(NSColor.windowBackgroundColor)
        }
        
        static var cardBackground: Color {
            Color(NSColor.controlBackgroundColor)
        }
        
        static var textPrimary: Color {
            Color(NSColor.labelColor)
        }
        
        static var textSecondary: Color {
            Color(NSColor.secondaryLabelColor)
        }
        
        static let timerPulse = Color.blue.opacity(0.5)
    }
    
    struct Gradients {
        static func activeGradient(for color: Color) -> LinearGradient {
            LinearGradient(
                gradient: Gradient(colors: [color.opacity(0.15), color.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static let accentGradient = LinearGradient(
            colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )

        static let destructiveGradient = LinearGradient(
            colors: [AppTheme.Colors.destructive, AppTheme.Colors.destructive.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    struct Shadows {
        static let soft = Shadow(color: Color.black.opacity(AppTheme.Opacity.shadowResting), radius: 6, x: 0, y: 3)
        static let floating = Shadow(color: Color.black.opacity(AppTheme.Opacity.shadowFloating), radius: 10, x: 0, y: 5)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
