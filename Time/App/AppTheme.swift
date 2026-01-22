import SwiftUI

struct AppTheme {
    static let cardCornerRadius: CGFloat = 5
    static let mainWidth: CGFloat = 280

    // Sidebar sizing
    static let sidebarDefaultWidth: CGFloat = 280
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 500
    static let sidebarCollapseThreshold: CGFloat = 100

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

    struct Animation {
        /// Standard snappy animation used throughout the app.
        static let standard = SwiftUI.Animation.snappy(duration: 0.18)
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

    struct Typography {
        // Base font sizes
        static let caption: CGFloat = 9           // TimeLabel timestamps
        static let caption2: CGFloat = 10         // Section headers
        static let body: CGFloat = 11             // Secondary text
        static let bodyEmphasized: CGFloat = 12   // Task blocks
        static let callout: CGFloat = 13          // Primary row text
        static let subheadline: CGFloat = 14      // Empty state
        static let headline: CGFloat = 15         // Headers
        static let title: CGFloat = 20            // Duration display
        static let largeTitle: CGFloat = 40       // Empty state icons

        // Semantic font helpers
        static func sectionHeader() -> Font {
            .system(size: caption2, weight: .medium)
        }

        static func taskDescription() -> Font {
            .system(size: bodyEmphasized)
        }

        static func rowPrimaryText() -> Font {
            .system(size: callout)
        }

        static func rowSecondaryText() -> Font {
            .system(size: body)
        }

        static func timeLabel() -> Font {
            .system(size: caption, weight: .medium, design: .monospaced)
        }

        static func durationDisplay() -> Font {
            .system(size: title, weight: .semibold, design: .monospaced)
        }

        static func emptyStateTitle() -> Font {
            .system(size: subheadline, weight: .medium)
        }
    }

    struct Spacing {
        // Base scale
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16
        static let xxxl: CGFloat = 20
        static let huge: CGFloat = 40

        // Semantic aliases for common use cases
        static let cardPaddingVertical: CGFloat = md      // 8
        static let cardPaddingHorizontal: CGFloat = lg    // 10
        static let rowPaddingVertical: CGFloat = xs       // 4
        static let rowPaddingHorizontal: CGFloat = sm     // 6
        static let itemSpacing: CGFloat = xs              // 4
        static let sectionSpacing: CGFloat = xl           // 12
        static let formFieldSpacing: CGFloat = md         // 8
    }

    struct CornerRadius {
        // Base scale
        static let xs: CGFloat = 4
        static let sm: CGFloat = 5
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 10

        // Semantic aliases
        static let card: CGFloat = sm           // 5
        static let field: CGFloat = sm          // 5
        static let button: CGFloat = xl         // 10
        static let row: CGFloat = lg            // 8
        static let timeLabel: CGFloat = xs      // 4
    }

    struct Colors {
        static let accent = Color.accentColor
        static let activeTimer = Color.accentColor
        static let completedTimer = Color(nsColor: .secondaryLabelColor).opacity(0.9)

        static let destructive = Color(nsColor: .systemRed)
        static let nowIndicator = Color(nsColor: .systemRed)

        static var separator: Color { Color(nsColor: .separatorColor) }
        static var tertiaryFill: Color { Color(nsColor: .tertiaryLabelColor).opacity(0.18) }

        static var fieldBackground: Color { Color(nsColor: .textBackgroundColor) }
        static var fieldDisabledBackground: Color { Color(nsColor: .controlBackgroundColor).opacity(0.6) }
        static var fieldBorder: Color { Color(nsColor: .separatorColor) }
        static var footerBackground: Color { Color(nsColor: .windowBackgroundColor).opacity(0.001) }

        static let timeLabelBackground = Color.black.opacity(AppTheme.Opacity.timeLabelBackground)
        static let resizeHandle = Color(nsColor: .tertiaryLabelColor)
        static let gridLine = Color(nsColor: .separatorColor).opacity(0.55)
        
        static var background: Color {
            Color(NSColor.white)
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

        static let pastelPalette: [NSColor] = [
            NSColor(red: 0.92, green: 0.75, blue: 0.75, alpha: 1.0), // Muted Rose
            NSColor(red: 0.75, green: 0.85, blue: 0.92, alpha: 1.0), // Muted Sky
            NSColor(red: 0.75, green: 0.92, blue: 0.85, alpha: 1.0), // Muted Mint
            NSColor(red: 0.92, green: 0.85, blue: 0.75, alpha: 1.0), // Muted Apricot
            NSColor(red: 0.85, green: 0.75, blue: 0.92, alpha: 1.0), // Muted Lavender
            NSColor(red: 0.75, green: 0.92, blue: 0.92, alpha: 1.0), // Muted Teal
            NSColor(red: 0.92, green: 0.92, blue: 0.75, alpha: 1.0), // Muted Lemon
            NSColor(red: 0.92, green: 0.75, blue: 0.85, alpha: 1.0), // Muted Pink
            NSColor(red: 0.82, green: 0.88, blue: 0.82, alpha: 1.0), // Muted Sage
            NSColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 1.0)  // Muted Periwinkle
        ]

        static func taskBaseColor(task: Task) -> Color {
            // Stable-ish palette derived from UUID so tasks don't all look gray.
            let idx = abs(task.id.uuidString.hashValue) % pastelPalette.count
            return Color(nsColor: pastelPalette[idx])
        }
    }

    struct Surfaces {
        static let sidebar: Material = .thick
        static let panel: Material = .regular
        static let card: Material = .thin
        static let popover: Material = .regular
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
        static let active = Shadow(color: Color.black.opacity(AppTheme.Opacity.shadowActive), radius: 8, x: 0, y: 4)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
