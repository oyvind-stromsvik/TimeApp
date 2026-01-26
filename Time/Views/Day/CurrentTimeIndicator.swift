import SwiftUI

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    var topOffset: CGFloat = 0
    @Environment(AppManager.self) private var manager

    var body: some View {
        let now = manager.lastTick
        let calendar = Calendar.current
        let hour = CGFloat(calendar.component(.hour, from: now))
        let minute = CGFloat(calendar.component(.minute, from: now))
        let yOffset = (hour + minute / 60.0) * hourHeight + topOffset

        HStack(spacing: 0) {
            Circle()
                .fill(AppTheme.Colors.nowIndicator)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: AppTheme.Colors.nowIndicator.opacity(0.5), radius: 4)
                .offset(x: -4)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.nowIndicator, AppTheme.Colors.nowIndicator.opacity(0.25)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .offset(x: -6)
                .padding(.trailing, AppTheme.Timeline.hourLineOffsetX)
        }
        .offset(y: yOffset - 1)
        .zIndex(100)
    }
}
