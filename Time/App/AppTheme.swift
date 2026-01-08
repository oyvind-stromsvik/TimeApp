import SwiftUI

struct AppTheme {
    static let cornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 8
    
    struct Colors {
        static let accent = Color.blue
        static let activeTimer = Color.blue
        static let completedTimer = Color.green
        
        static var sidebarBackground: Color {
            Color(NSColor.windowBackgroundColor)
        }
        
        static var cardBackground: Color {
            Color(NSColor.controlBackgroundColor)
        }
    }
    
    struct Gradients {
        static func activeGradient(for color: Color) -> LinearGradient {
            LinearGradient(
                gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    struct Shadows {
        static let soft = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
