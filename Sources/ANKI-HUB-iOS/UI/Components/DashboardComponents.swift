import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
            }
            
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

struct SubjectCard: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let textColor = theme.currentPalette.color(.text, isDark: isDark)
        let secondaryColor = theme.currentPalette.color(.secondary, isDark: isDark)
        
        VStack(spacing: 16) {
            // Icon with enhanced pastel background
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(subject.color.opacity(0.25))
                    .frame(width: 64, height: 64)
                Image(systemName: subject.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(subject.color)
            }
            
            VStack(spacing: 6) {
                Text(subject.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)

                Text(subject.description)
                    .font(.caption.weight(.medium))
                    .foregroundColor(secondaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(minHeight: 160)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(subject.color.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: subject.color.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct ToolCard: View {
    let icon: String
    let title: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let textColor = theme.currentPalette.color(.text, isDark: isDark)
        
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.22))
                    .frame(width: 50, height: 50)
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
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
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

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("目標まで")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                    Text(daysRemaining == 0 ? "今日が締切" : "あと\(daysRemaining)日")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text("目標日 \(dateString(targetDate))")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                CircularProgressView(progress: progress, color: accent, lineWidth: 6)
                    .frame(width: 64, height: 64)
            }

            HStack {
                Text("学習時間")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.15), radius: 6, x: 0, y: 3)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
