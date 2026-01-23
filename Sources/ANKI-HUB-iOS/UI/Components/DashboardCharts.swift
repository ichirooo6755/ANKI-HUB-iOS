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
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let safeIndex = min(selectedPage, max(pages.count - 1, 0))
        let currentData = masteryData(for: pages[safeIndex])

        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("習熟度")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                }

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        let data = masteryData(for: page)
                        let totalMastered = data.first(where: { $0.level == .mastered })?.count ?? 0
                        let isEmpty = data.allSatisfy { $0.count == 0 }
                        VStack(spacing: 12) {
                            if isEmpty {
                                ZStack {
                                    Circle()
                                        .stroke(accent.opacity(0.16), lineWidth: 10)
                                        .frame(width: 160, height: 160)
                                    Image(systemName: "sparkles")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(accent)
                                }
                                .frame(height: 260)
                            } else {
                                let totalCount = data.reduce(0) { $0 + $1.count }
                                let masteredCount = data.first(where: { $0.level == .mastered })?.count ?? 0
                                let summaryText = "合計\(totalCount)語、習熟\(masteredCount)語"
                                Chart(data) { item in
                                    SectorMark(
                                        angle: .value("Count", item.count),
                                        innerRadius: .ratio(0.6),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(5)
                                    .foregroundStyle(item.level.color)
                                }
                                .frame(height: 260)
                                .accessibilityLabel(Text("習熟度ドーナツチャート"))
                                .accessibilityValue(Text(summaryText))
                                .chartOverlay { _ in
                                    VStack(spacing: 4) {
                                        Text("覚えた")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(theme.secondaryText.opacity(0.62))
                                        Text("\(totalMastered)")
                                            .font(.system(size: 58, weight: .black, design: .default))
                                            .monospacedDigit()
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                            .foregroundStyle(theme.primaryText)
                                    }
                                    .padding(.horizontal, 10)
                                }
                            }

                            Text(page.subject?.displayName ?? "総合")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.secondaryText.opacity(0.62))
                        }
                        .padding(.horizontal, 4)
                        .tag(index)
                    }
                }
                .frame(height: 340)
                #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                    .tabViewStyle(.automatic)
                #endif

                #if os(iOS)
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { idx in
                            Circle()
                                .fill(idx == safeIndex ? accent.opacity(0.9) : border.opacity(0.35))
                                .frame(width: idx == safeIndex ? 6 : 5, height: idx == safeIndex ? 6 : 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
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
                                .foregroundStyle(theme.secondaryText.opacity(0.62))
                            Spacer()
                            Text("\(count)")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(theme.primaryText)
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

            chartCard(accent: primary, icon: "square.grid.3x3.fill") {
                HStack {
                    Text("ヒートマップ")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                }

                if learningStats.dailyHistory.isEmpty {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(18), spacing: 6), count: 7),
                        alignment: .leading,
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

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(0..<4) { level in
                            HStack(spacing: 6) {
                                HeatmapCell(
                                    level: level,
                                    accent: primary,
                                    surface: theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark),
                                    isToday: false
                                )
                                Text(legendText(for: level))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(theme.secondaryText.opacity(0.62))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func chartCard<Content: View>(
        accent: Color,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let style = theme.widgetCardStyle

        let fill: AnyShapeStyle = {
            switch style {
            case "neo":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [surface.opacity(theme.effectiveIsDark ? 0.86 : 0.98), accent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "outline":
                return AnyShapeStyle(surface.opacity(0.001))
            default:
                return AnyShapeStyle(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            }
        }()
        let stroke: Color = {
            switch style {
            case "neo":
                return accent.opacity(0.22)
            case "outline":
                return accent.opacity(0.32)
            default:
                return accent.opacity(0.14)
            }
        }()
        let shadowRadius: CGFloat = {
            switch style {
            case "outline":
                return 0
            case "neo":
                return 10
            default:
                return 8
            }
        }()
        let shadowColor: Color = {
            switch style {
            case "neo":
                return accent.opacity(theme.effectiveIsDark ? 0.18 : 0.10)
            case "outline":
                return .clear
            default:
                return Color.black.opacity(theme.effectiveIsDark ? 0.24 : 0.06)
            }
        }()

        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 110, weight: .bold, design: .default))
                .foregroundStyle(accent.opacity(theme.effectiveIsDark ? (style == "neo" ? 0.20 : 0.16) : (style == "neo" ? 0.16 : 0.12)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(18)
        }
        .background(cardShape.fill(fill))
        .overlay(cardShape.stroke(stroke, lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
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

    private func legendText(for level: Int) -> String {
        switch level {
        case 0:
            return "0"
        case 1:
            return "1+"
        case 2:
            return "30分/40語"
        case 3:
            return "60分/80語"
        default:
            return ""
        }
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
            let size: CGFloat = 18
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape
                .fill(color)
                .frame(width: size, height: size)
                .overlay(
                    shape
                        .stroke(
                            isToday ? accent.opacity(0.7) : accent.opacity(level == 0 ? 0.08 : 0),
                            lineWidth: isToday ? 1.5 : 1
                        )
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
