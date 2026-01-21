import SwiftUI

struct CalendarStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(theme.primaryText)
                Text(unit)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surface.opacity(0.98), highlight.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

struct DayCell: View {
    let date: Date
    let activity: Int  // 0: none, 1: low, 2: medium, 3: high
    let hasJournal: Bool
    let isToday: Bool

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let background = activityColor(activity, accent: accent, surface: surface)
        let textColor = activity > 0 ? theme.onColor(for: background) : theme.primaryText
        let size: CGFloat = 36
        let cornerRadius: CGFloat = 11
        let shadowColor = activity > 0 ? background.opacity(0.25) : .clear

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
                .frame(width: size, height: size)
                .shadow(color: shadowColor, radius: activity > 0 ? 4 : 0, x: 0, y: 2)

            if isToday {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size, height: size)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor)

            if hasJournal {
                Circle()
                    .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    .frame(width: 7, height: 7)
                    .offset(x: 12, y: -12)
            }
        }
    }

    private func activityColor(_ level: Int, accent: Color, surface: Color) -> Color {
        switch level {
        case 1:
            return accent.opacity(0.25)
        case 2:
            return accent.opacity(0.55)
        case 3:
            return accent.opacity(0.9)
        default:
            return surface.opacity(0.35)
        }
    }
}
