import SwiftUI

struct TimelineGrid: View {
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<AppTheme.Timeline.hoursPerDay, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: AppTheme.Timeline.hourLabelWidth, alignment: .trailing)
                        .offset(x: AppTheme.Timeline.hourLabelOffsetX, y: AppTheme.Timeline.hourLabelOffsetY)

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(AppTheme.Colors.gridLine)
                            .frame(height: 1)
                            .offset(x: AppTheme.Timeline.hourLineOffsetX)
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
    }
}
