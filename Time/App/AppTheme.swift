import SwiftUI

struct AppTheme {
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
    static let sidebarWidth: CGFloat = 280
    static let mainWidth: CGFloat = 280
    
    struct Colors {
        static let accent = Color.blue
        static let activeTimer = Color.blue
        static let completedTimer = Color(nsColor: .secondaryLabelColor).opacity(0.8)
        
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
            colors: [.blue, .blue.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    struct Shadows {
        static let soft = Shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        static let floating = Shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func premiumCard(color: Color = AppTheme.Colors.cardBackground) -> some View {
        self.padding(12)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.Shadows.soft.color, radius: AppTheme.Shadows.soft.radius, x: AppTheme.Shadows.soft.x, y: AppTheme.Shadows.soft.y)
    }
    
    func glassBackground() -> some View {
        self.background(.ultraThinMaterial)
    }
}
