import Charts
import SwiftUI

struct DashboardCharts: View {
    @ObservedObject var learningStats: LearningStats
    @ObservedObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let combined = getCombinedMasteryData()
        let totalMastered = combined.first(where: { $0.level == .mastered })?.count ?? 0
        VStack(spacing: 20) {
            // Mastery Chart (Donut)
            VStack(alignment: .leading) {
                Text("Total Mastery（習熟度）")
                    .font(.headline)
                    .padding(.bottom, 5)

                Chart(combined) { item in
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

                // Legend
                HStack {
                    ForEach(MasteryLevel.allCases.reversed(), id: \.self) { level in
                        if level != .new {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(level.color)
                                    .frame(width: 8, height: 8)
                                Text(level.label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
            .liquidGlass()

            // Weekly Activity (Bar)
            VStack(alignment: .leading) {
                Text("Weekly Activity（直近7日）")
                    .font(.headline)
                    .padding(.bottom, 5)

                Chart(getWeeklyMinutesData()) { entry in
                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Minutes", entry.minutes)
                    )
                    .foregroundStyle(primary.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 150)
            }
            .padding()
            .liquidGlass()

            // Subject Activity (Weekly Totals)
            VStack(alignment: .leading) {
                Text("教科別（直近7日）")
                    .font(.headline)
                    .padding(.bottom, 5)

                let data = getWeeklySubjectTotals()
                if data.isEmpty {
                    Text("まだ記録がありません。クイズ/インプット/タイマーで学習するとここに反映されます")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.vertical, 12)
                } else {
                    Chart(data) { entry in
                        BarMark(
                            x: .value("Subject", entry.subjectDisplayName),
                            y: .value("Words", entry.words)
                        )
                        .foregroundStyle(subjectColor(for: entry.subjectId).gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 170)
                }
            }
            .padding()
            .liquidGlass()
        }
    }

    // MARK: - Data Helpers

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
        if subjectId == Subject.eiken.rawValue {
            return theme.currentPalette.color(.accent, isDark: isDark)
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
