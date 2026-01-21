import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.35 : 0.08)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
            }

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(theme.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.9 : 0.98))
        )
        .shadow(color: shadow, radius: 10, x: 0, y: 6)
    }
}

struct SubjectCard: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let shadow = Color.black.opacity(isDark ? 0.35 : 0.08)
        let textColor = theme.primaryText
        let secondaryColor = theme.secondaryText
        
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(subject.color.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: subject.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(subject.color)
            }
            
            VStack(spacing: 6) {
                Text(subject.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)

                Text(subject.description)
                    .font(.caption)
                    .foregroundColor(secondaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(minHeight: 156)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface.opacity(isDark ? 0.9 : 0.98))
        )
        .shadow(color: shadow, radius: 10, x: 0, y: 6)
    }
}

struct ToolCard: View {
    let icon: String
    let title: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let shadow = Color.black.opacity(isDark ? 0.35 : 0.08)
        let textColor = theme.primaryText
        
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface.opacity(isDark ? 0.9 : 0.98))
        )
        .shadow(color: shadow, radius: 10, x: 0, y: 6)
    }
}

struct GoalCountdownCard: View {
    let daysRemaining: Int
    let targetDate: Date
    let progress: Double
    let progressText: String

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.35 : 0.08)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("目標まで")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    Text(daysRemaining == 0 ? "今日が締切" : "あと\(daysRemaining)日")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(theme.primaryText)
                    Text("目標日 \(dateString(targetDate))")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                CircularProgressView(progress: progress, color: accent, lineWidth: 8)
                    .frame(width: 72, height: 72)
            }

            HStack {
                Text("学習時間")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.9 : 0.98))
        )
        .shadow(color: shadow, radius: 12, x: 0, y: 8)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
