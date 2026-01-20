import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(theme.primaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass()
    }
}

struct SubjectCard: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let textColor = theme.currentPalette.color(.text, isDark: isDark)
        let secondaryColor = theme.currentPalette.color(.secondary, isDark: isDark)
        
        VStack(spacing: 12) {
            // Icon with subtle background
            ZStack {
                Circle()
                    .fill(subject.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: subject.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(subject.color)
            }

            VStack(spacing: 4) {
                Text(subject.displayName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)

                Text(subject.description)
                    .font(.caption)
                    .foregroundColor(secondaryColor.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(minHeight: 140)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 20)
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
        
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .liquidGlass(cornerRadius: 16)
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("目標まで")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    Text(daysRemaining == 0 ? "今日が締切" : "あと\(daysRemaining)日")
                        .font(.title3.bold())
                        .foregroundStyle(theme.primaryText)
                    Text("目標日 \(dateString(targetDate))")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                CircularProgressView(progress: progress, color: accent, lineWidth: 6)
                    .frame(width: 62, height: 62)
            }

            HStack {
                Text("学習時間")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding()
        .liquidGlass()
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
