import SwiftUI

// MARK: - Shared App Styles

private struct AppSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.sectionHeader())
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
            .background(isDisabledStyle ? AppTheme.Colors.fieldDisabledBackground : AppTheme.Colors.fieldBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.Colors.fieldBorder.opacity(0.9), lineWidth: 1)
            )
    }
}

extension View {
    func appCardField(padding: CGFloat = AppTheme.Spacing.lg, cornerRadius: CGFloat = AppTheme.CornerRadius.field, disabledStyle: Bool = false) -> some View {
        modifier(AppCardFieldModifier(padding: padding, cornerRadius: cornerRadius, isDisabledStyle: disabledStyle))
    }
}

private struct TaskRowModifier: ViewModifier {
    let isHovering: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, AppTheme.Spacing.rowPaddingVertical)
            .padding(.horizontal, AppTheme.Spacing.rowPaddingHorizontal)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.row))
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.row)
                    .fill(isHovering ? AppTheme.Colors.tertiaryFill : .clear)
            )
            .animation(AppTheme.Animation.standard, value: isHovering)
    }
}

extension View {
    func taskRowStyle(isHovering: Bool) -> some View {
        modifier(TaskRowModifier(isHovering: isHovering))
    }

    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(AppTheme.Gradients.secondaryGradient)
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct PressedButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.snappy(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Unsaved Changes Alert

private struct UnsavedChangesAlertModifier: ViewModifier {
    @Bindable var manager: AppManager

    func body(content: Content) -> some View {
        content
            .alert("Unsaved Changes", isPresented: $manager.showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    manager.discardChangesAndDeselect()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Do you want to discard them?")
            }
    }
}

extension View {
    /// Adds the standard unsaved changes alert using the centralized manager state.
    func unsavedChangesAlert(manager: AppManager) -> some View {
        modifier(UnsavedChangesAlertModifier(manager: manager))
    }
}
