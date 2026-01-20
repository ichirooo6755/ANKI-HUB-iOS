import SwiftUI

struct AppCalendarView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var stats = LearningStats.shared

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards

                        VStack(alignment: .leading, spacing: 8) {
                            Text("学習履歴")
                                .font(.headline)
                                .foregroundStyle(theme.primaryText)

                            if stats.dailyHistory.isEmpty {
                                Text("学習記録がまだありません")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            } else {
                                Text("記録日数: \(stats.dailyHistory.count)日")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlass(cornerRadius: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("カレンダー")
            .applyAppTheme()
        }
    }

    private var summaryCards: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let secondary = theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                CalendarStatCard(
                    title: "今日の学習",
                    value: "\(stats.todayMinutes)",
                    unit: "分",
                    icon: "clock.fill",
                    color: accent
                )
                CalendarStatCard(
                    title: "連続日数",
                    value: "\(stats.streak)",
                    unit: "日",
                    icon: "flame.fill",
                    color: primary
                )
            }

            HStack(spacing: 12) {
                CalendarStatCard(
                    title: "習得語彙",
                    value: "\(stats.masteredCount)",
                    unit: "語",
                    icon: "checkmark.seal.fill",
                    color: mastered
                )
                CalendarStatCard(
                    title: "総単語数",
                    value: "\(stats.totalWords)",
                    unit: "語",
                    icon: "books.vertical.fill",
                    color: secondary
                )
            }
        }
    }
}
