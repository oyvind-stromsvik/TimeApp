import SwiftUI

// MARK: - Shared App Styles

private struct AppSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
    }
}

extension View {
    func appSectionHeader() -> some View {
        modifier(AppSectionHeaderModifier())
    }
}

private struct AppCardFieldModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let isDisabledStyle: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(isDisabledStyle ? AppTheme.Colors.fieldDisabledBackground : AppTheme.Colors.cardBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.Colors.fieldBorder, lineWidth: 1)
            )
    }
}

extension View {
    func appCardField(padding: CGFloat = 10, cornerRadius: CGFloat = 8, disabledStyle: Bool = false) -> some View {
        modifier(AppCardFieldModifier(padding: padding, cornerRadius: cornerRadius, isDisabledStyle: disabledStyle))
    }
}

struct AppCircleIcon: View {
    let systemName: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 12
    var weight: Font.Weight = .bold
    var foreground: Color = .white
    var background: AnyShapeStyle

    init(
        systemName: String,
        size: CGFloat = 32,
        iconSize: CGFloat = 12,
        weight: Font.Weight = .bold,
        foreground: Color = .white,
        background: some ShapeStyle
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.weight = weight
        self.foreground = foreground
        self.background = AnyShapeStyle(background)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: weight))
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(background))
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(AppTheme.Gradients.accentGradient)
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct AppDestructiveButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppTheme.Colors.destructive)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.Colors.destructive.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.Colors.destructive.opacity(0.25), lineWidth: 1)
            )
    }
}
