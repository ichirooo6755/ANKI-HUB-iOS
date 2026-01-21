import Charts
import SwiftUI

struct DashboardCharts: View {
    @ObservedObject var learningStats: LearningStats
    @ObservedObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedPage: Int = 0

    var body: some View {
        let pages: [MasteryPage] = {
            var result: [MasteryPage] = [MasteryPage(kind: .combined, subject: nil)]
            result.append(contentsOf: Subject.allCases.map { MasteryPage(kind: .subject, subject: $0) })
            return result
        }()
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let safeIndex = min(selectedPage, max(pages.count - 1, 0))
        let currentData = masteryData(for: pages[safeIndex])

        VStack(spacing: 16) {
            chartCard(accent: accent) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.2))
                            .frame(width: 34, height: 34)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("習熟度")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.primaryText)
                        Text("左右スワイプで科目切替")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        let data = masteryData(for: page)
                        let totalMastered = data.first(where: { $0.level == .mastered })?.count ?? 0
                        let isEmpty = data.allSatisfy { $0.count == 0 }
                        VStack(spacing: 12) {
                            if isEmpty {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .stroke(accent.opacity(0.2), lineWidth: 12)
                                            .frame(width: 120, height: 120)
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(accent)
                                    }
                                    Text("学習を始めよう")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.primaryText)
                                    Text("クイズやタイマーの記録がここに表示されます")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(height: 200)
                            } else {
                                Chart(data) { item in
                                    SectorMark(
                                        angle: .value("Count", item.count),
                                        innerRadius: .ratio(0.6),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(5)
                                    .foregroundStyle(item.level.color)
                                }
                                .frame(height: 200)
                                .chartOverlay { _ in
                                    VStack(spacing: 4) {
                                        Text("覚えた")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                        Text("\(totalMastered)")
                                            .font(.system(.title, design: .rounded).weight(.bold))
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                            .foregroundStyle(theme.primaryText)
                                    }
                                    .padding(.horizontal, 10)
                                }
                            }

                            Text(page.subject?.displayName ?? "総合")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(.horizontal, 4)
                        .tag(index)
                    }
                }
                .frame(height: 240)
                #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                #else
                    .tabViewStyle(.automatic)
                #endif

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        let count = currentData.first(where: { $0.level == level })?.count ?? 0
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(level.color)
                                .frame(width: 12, height: 12)
                            Text(level.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            Text("\(count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(level.color.opacity(0.12))
                        )
                    }
                }
            }

            chartCard(accent: primary) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(primary.opacity(0.2))
                            .frame(width: 34, height: 34)
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("学習ヒートマップ")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.primaryText)
                        Text("直近3週間の学習強度")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                }

                if learningStats.dailyHistory.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(primary)
                        Text("まだ学習記録がありません")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text("タイマーやクイズを完了するとここに反映されます")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                        spacing: 6
                    ) {
                        ForEach(heatmapDays) { day in
                            HeatmapCell(
                                level: day.level,
                                accent: primary,
                                surface: theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark),
                                isToday: day.isToday
                            )
                        }
                    }

                    HStack(spacing: 6) {
                        Text("少")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                        ForEach(0..<4) { level in
                            HeatmapCell(
                                level: level,
                                accent: primary,
                                surface: theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark),
                                isToday: false
                            )
                        }
                        Text("多")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func chartCard<Content: View>(accent: Color, @ViewBuilder content: () -> Content) -> some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        return VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surface.opacity(0.98), highlight.opacity(0.9)],
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

    private var heatmapDays: [HeatmapDay] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<21).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = dateKey(date)
            let entry = learningStats.dailyHistory[key]
            let level = activityLevel(for: entry)
            return HeatmapDay(date: date, level: level, isToday: calendar.isDateInToday(date))
        }
        .reversed()
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
    
    private func getCombinedMasteryData() -> [MasteryData] {
        var totalStats: [MasteryLevel: Int] = [
            .new: 0, .weak: 0, .learning: 0, .almost: 0, .mastered: 0,
        ]

        var totalVocabCount = 0
        var trackedCount = 0

        for subject in Subject.allCases {
            let stats = masteryTracker.getStats(for: subject.id)
            for (level, count) in stats {
                totalStats[level, default: 0] += count
                trackedCount += count
            }

            totalVocabCount += VocabularyData.shared.getVocabulary(for: subject).count
        }

        totalStats[.new] = max(0, totalVocabCount - trackedCount)

        return MasteryLevel.allCases.map { level in
            MasteryData(level: level, count: totalStats[level] ?? 0)
        }
    }

    private func getSubjectMasteryData(_ subject: Subject) -> [MasteryData] {
        let stats = masteryTracker.getStats(for: subject.id)
        var combined: [MasteryLevel: Int] = [:]
        for (level, count) in stats {
            combined[level, default: 0] += count
        }
        let total = VocabularyData.shared.getVocabulary(for: subject).count
        let tracked = stats.values.reduce(0, +)
        combined[.new] = max(0, total - tracked)

        return MasteryLevel.allCases.map { level in
            MasteryData(level: level, count: combined[level] ?? 0)
        }
    }

    private func masteryData(for page: MasteryPage) -> [MasteryData] {
        switch page.kind {
        case .combined:
            return getCombinedMasteryData()
        case .subject:
            if let subject = page.subject {
                return getSubjectMasteryData(subject)
            }
            return getCombinedMasteryData()
        }
    }

    private struct MasteryPage {
        enum Kind {
            case combined
            case subject
        }

        let kind: Kind
        let subject: Subject?
    }

    private struct HeatmapDay: Identifiable {
        let id = UUID()
        let date: Date
        let level: Int
        let isToday: Bool
    }

    private struct HeatmapCell: View {
        let level: Int
        let accent: Color
        let surface: Color
        let isToday: Bool

        var body: some View {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? accent.opacity(0.6) : .clear, lineWidth: 1)
                )
        }

        private var color: Color {
            switch level {
            case 1:
                return accent.opacity(0.25)
            case 2:
                return accent.opacity(0.5)
            case 3:
                return accent.opacity(0.85)
            default:
                return surface.opacity(0.4)
            }
        }
    }

    struct ActivityData: Identifiable {
        let id = UUID()
        let day: String
        let words: Int
    }

    struct MinuteActivityData: Identifiable {
        let id = UUID()
        let day: String
        let minutes: Int
    }

    private func getWeeklyData() -> [ActivityData] {
        let calendar = Calendar.current
        var data: [ActivityData] = []
        let today = Date()

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let key = formatter.string(from: date)

                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E"
                let dayLabel = dayFormatter.string(from: date)

                let count = learningStats.dailyHistory[key]?.words ?? 0
                data.append(ActivityData(day: dayLabel, words: count))
            }
        }
        return data
    }

    private func getWeeklyMinutesData() -> [MinuteActivityData] {
        let calendar = Calendar.current
        var data: [MinuteActivityData] = []
        let today = Date()

        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: date)

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "E"
            let dayLabel = dayFormatter.string(from: date)

            let minutes = learningStats.dailyHistory[key]?.minutes ?? 0
            data.append(MinuteActivityData(day: dayLabel, minutes: minutes))
        }
        return data
    }

    struct SubjectActivityData: Identifiable {
        let id = UUID()
        let subjectId: String
        let subjectDisplayName: String
        let words: Int
    }

    private func getWeeklySubjectTotals() -> [SubjectActivityData] {
        let calendar = Calendar.current
        let today = Date()

        var totals: [String: Int] = [:]

        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: date)

            guard let entry = learningStats.dailyHistory[key] else { continue }
            for (subjectId, count) in entry.subjects {
                totals[subjectId, default: 0] += count
            }
        }

        // Keep a stable order based on Subject enum, then unknown leftovers
        let orderedIds = Subject.allCases.map { $0.rawValue }
        let known = orderedIds.compactMap { id -> SubjectActivityData? in
            guard let words = totals[id], words > 0 else { return nil }
            let display = Subject(rawValue: id)?.displayName ?? id
            return SubjectActivityData(subjectId: id, subjectDisplayName: display, words: words)
        }

        let extra = totals
            .filter { !orderedIds.contains($0.key) && $0.value > 0 }
            .map { SubjectActivityData(subjectId: $0.key, subjectDisplayName: $0.key, words: $0.value) }
            .sorted { $0.words > $1.words }

        return (known + extra)
            .sorted { $0.words > $1.words }
    }

    private func subjectColor(for subjectId: String) -> Color {
        let isDark = theme.effectiveIsDark
        if subjectId == Subject.english.rawValue {
            return theme.currentPalette.color(.primary, isDark: isDark)
        }
        if subjectId == Subject.kobun.rawValue {
            return theme.currentPalette.color(.selection, isDark: isDark)
        }
        if subjectId == Subject.kanbun.rawValue {
            return theme.currentPalette.color(.mastered, isDark: isDark)
        }
        if subjectId == Subject.seikei.rawValue {
            return theme.currentPalette.color(.weak, isDark: isDark)
        }
        return theme.currentPalette.color(.secondary, isDark: isDark)
    }
}

// MARK: - Shared Data Models
struct MasteryData: Identifiable {
    let id = UUID()
    let level: MasteryLevel
    let count: Int
}
