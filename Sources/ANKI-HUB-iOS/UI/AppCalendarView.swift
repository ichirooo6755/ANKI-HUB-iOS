import SwiftUI

struct AppCalendarView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var stats = LearningStats.shared
    @State private var monthOffset: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 20) {
                        summaryCards

                        calendarCard

                        historyCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("カレンダー")
            .applyAppTheme()
        }
    }

    private var calendarCard: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        let days = monthDays

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("月間カレンダー")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text("学習記録がある日を可視化")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        monthOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(accent.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(monthTitle)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)

                    Button {
                        monthOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(accent.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days) { day in
                    if let date = day.date {
                        DayCell(
                            date: date,
                            activity: activityLevel(for: stats.dailyHistory[dateKey(date)]),
                            hasJournal: stats.journals[dateKey(date)] != nil,
                            isToday: Calendar.current.isDateInToday(date)
                        )
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(16)
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
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 4)
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

    private var historyCard: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        let days = recentDays

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("学習履歴")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text("直近3週間の記録")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
            }

            if stats.dailyHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("まだ学習記録がありません")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("タイマーやクイズを完了するとここに反映されます")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: TimerView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.footnote.weight(.semibold))
                            Text("タイマーを起動")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(theme.onColor(for: accent))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(accent.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 6
                ) {
                    ForEach(days) { day in
                        DayCell(
                            date: day.date,
                            activity: day.activity,
                            hasJournal: day.hasJournal,
                            isToday: day.isToday
                        )
                    }
                }

                HStack {
                    Text("記録日数: \(stats.dailyHistory.count)日")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("少")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                        ForEach(0..<4) { level in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(heatmapColor(level: level, accent: accent, surface: surface))
                                .frame(width: 12, height: 12)
                        }
                        Text("多")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .padding(16)
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
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private var recentDays: [DaySnapshot] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<21).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = dateKey(date)
            let entry = stats.dailyHistory[key]
            let activity = activityLevel(for: entry)
            let hasJournal = stats.journals[key] != nil
            return DaySnapshot(
                date: date,
                activity: activity,
                hasJournal: hasJournal,
                isToday: calendar.isDateInToday(date)
            )
        }
        .reversed()
    }

    private var weekdays: [String] {
        let calendar = Calendar.current
        let base = ["日", "月", "火", "水", "木", "金", "土"]
        let startIndex = (calendar.firstWeekday - 1 + base.count) % base.count
        return Array(base[startIndex...] + base[..<startIndex])
    }

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayedMonth)
    }

    private var monthDays: [CalendarDay] {
        let calendar = Calendar.current
        let start = startOfMonth(displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = Array(repeating: CalendarDay(date: nil), count: leadingEmpty)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                days.append(CalendarDay(date: date))
            }
        }

        let trailingEmpty = (7 - (days.count % 7)) % 7
        if trailingEmpty > 0 {
            days.append(contentsOf: Array(repeating: CalendarDay(date: nil), count: trailingEmpty))
        }

        return days
    }

    private func activityLevel(for entry: LearningStats.DailyEntry?) -> Int {
        let minutes = entry?.minutes ?? 0
        let words = entry?.words ?? 0
        if minutes >= 60 || words >= 80 { return 3 }
        if minutes >= 30 || words >= 40 { return 2 }
        if minutes > 0 || words > 0 { return 1 }
        return 0
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func heatmapColor(level: Int, accent: Color, surface: Color) -> Color {
        switch level {
        case 1:
            return accent.opacity(0.25)
        case 2:
            return accent.opacity(0.55)
        case 3:
            return accent.opacity(0.9)
        default:
            return surface.opacity(0.4)
        }
    }

    private struct DaySnapshot: Identifiable {
        let id = UUID()
        let date: Date
        let activity: Int
        let hasJournal: Bool
        let isToday: Bool
    }

    private struct CalendarDay: Identifiable {
        let id = UUID()
        let date: Date?
    }
}
