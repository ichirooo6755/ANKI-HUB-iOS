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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.2))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(unit)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surface.opacity(0.98), highlight.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.12), radius: 6, x: 0, y: 3)
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

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(background)
                .frame(width: 36, height: 36)

            if isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.6), lineWidth: 1)
                    .frame(width: 36, height: 36)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor)

            if hasJournal {
                Circle()
                    .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    .frame(width: 6, height: 6)
                    .offset(x: 12, y: -12)
            }
        }
    }

    private func activityColor(_ level: Int, accent: Color, surface: Color) -> Color {
        switch level {
        case 1:
            return accent.opacity(0.2)
        case 2:
            return accent.opacity(0.45)
        case 3:
            return accent.opacity(0.85)
        default:
            return surface.opacity(0.4)
        }
    }
}
