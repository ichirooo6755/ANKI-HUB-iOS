import SwiftUI

struct CalendarStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 20)
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
            Circle()
                .fill(background)
                .frame(height: 36)

            if isToday {
                Circle()
                    .stroke(accent.opacity(0.6), lineWidth: 1)
                    .frame(height: 36)
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
