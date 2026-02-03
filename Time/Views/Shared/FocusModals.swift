import SwiftUI

private struct FocusModalLayout<Actions: View>: View {
    let title: String
    let message: String
    let detail: String?
    let systemImage: String
    let accent: Color
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.12))
                    )

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(message)
                        .font(.system(size: AppTheme.Typography.callout))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let detail {
                Text(detail)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(AppTheme.Colors.fieldBackground)
                    )
            }

            HStack(spacing: AppTheme.Spacing.lg) {
                actions
            }
        }
        .frame(minWidth: 300)
        .padding(AppTheme.Spacing.huge)
    }
}

struct IdleAlertModalView: View {
    let idleDuration: TimeInterval
    let onDiscard: () -> Void
    let onKeep: () -> Void

    var body: some View {
        FocusModalLayout(
            title: "You Have Been Idle",
            message: "Do you want to discard your idle time or keep it?",
            detail: formattedIdleDuration(idleDuration),
            systemImage: "clock",
            accent: AppTheme.Colors.destructive
        ) {
            Button("Discard") {
                onDiscard()
            }
            .buttonStyle(AppSecondaryButtonStyle())
            
            Button("Keep Time") {
                onKeep()
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .interactiveDismissDisabled()
    }

    private func formattedIdleDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int(round(duration / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(totalMinutes) min idle"
        }

        if minutes == 0 {
            return "\(hours) hr idle"
        }

        return "\(hours) hr \(minutes) min idle"
    }
}

struct NoActiveTasksModalView: View {
    let onDismiss: () -> Void

    var body: some View {
        FocusModalLayout(
            title: "No Active Tasks",
            message: "Nothing is currently tracking time. That's no good and you know it.",
            detail: nil,
            systemImage: "timer",
            accent: AppTheme.Colors.accent
        ) {
            Button("Yes, I do") {
                onDismiss()
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .interactiveDismissDisabled()
    }
}

struct TrackingCheckModalView: View {
    let onConfirm: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        FocusModalLayout(
            title: "Tracking Check-In",
            message: "Are you still working on this task?",
            detail: nil,
            systemImage: "questionmark.circle",
            accent: AppTheme.Colors.accent
        ) {
            Button("No, stop task") {
                onSwitch()
            }
            .buttonStyle(AppSecondaryButtonStyle())
            
            Button("Yes, keep tracking") {
                onConfirm()
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    IdleAlertModalView(idleDuration: 900, onDiscard: {}, onKeep: {})
}
