import SwiftUI

private struct FocusModalLayout<Actions: View>: View {
    let title: String
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
    let idleStartTime: Date?
    let onDiscard: () -> Void
    let onKeep: () -> Void

    var body: some View {
        let idleStartText = idleStartTime.map(formatIdleStartTime) ?? "an unknown time"
        FocusModalLayout(
            title: "You have been idle since \(idleStartText)",
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
        "Idle duration: \(Task.formatDuration(duration))"
    }

    private func formatIdleStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NoActiveTasksModalView: View {
    let onDismiss: () -> Void

    var body: some View {
        FocusModalLayout(
            title: "Don't forget to track your time",
            detail: nil,
            systemImage: "timer",
            accent: AppTheme.Colors.accent
        ) {
            Button("Dismiss") {
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
            title: "Are you still working on this task?",
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
    IdleAlertModalView(idleDuration: 900, idleStartTime: Date().addingTimeInterval(-900), onDiscard: {}, onKeep: {})
}
