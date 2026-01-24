import SwiftUI
import Charts

struct ReportView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var learningStats: LearningStats

    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    SectionHeader(title: "アクティビティ", subtitle: "直近の学習サマリー", trailing: nil)

                    activityRings

                    summaryMetrics

                    SectionHeader(title: "習熟度", subtitle: "マスタリー分布", trailing: nil)
                    MasteryPieChart(masteryTracker: masteryTracker)

                    SectionHeader(title: "週間推移", subtitle: "1週間の単語数", trailing: nil)
                    WeeklyActivityChart(learningStats: learningStats)

                    SectionHeader(title: "科目別", subtitle: "習得率", trailing: nil)
                    SubjectStrengthChart(masteryTracker: masteryTracker)

                    weakWordsAction
                }
                .padding(16)
            }
            .navigationTitle("レポート")
            .background(theme.background)
            .applyAppTheme()
        }
    }

    private var activityRings: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ringCard(
                    title: "今日の学習",
                    value: "\(learningStats.todayMinutes)分",
                    progress: min(Double(learningStats.todayMinutes) / 60.0, 1),
                    color: accent
                )
                ringCard(
                    title: "習得率",
                    value: "\(learningStats.masteryRate)%",
                    progress: Double(learningStats.masteryRate) / 100.0,
                    color: mastered
                )
                ringCard(
                    title: "連続日数",
                    value: "\(learningStats.streak)日",
                    progress: min(Double(learningStats.streak) / 30.0, 1),
                    color: primary
                )
            }
            .padding(.horizontal, 2)
        }
    }

    private var summaryMetrics: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                let totalTime = totalTimeComponents(totalMinutes)
                HealthMetricCard(
                    title: "総学習時間",
                    value: totalTime.value,
                    unit: totalTime.unit,
                    icon: "hourglass",
                    color: theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)
                )
                HealthMetricCard(
                    title: "総単語数",
                    value: "\(totalWords)",
                    unit: "語",
                    icon: "text.book.closed.fill",
                    color: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                )
            }
            HStack(spacing: 12) {
                HealthMetricCard(
                    title: "弱点語彙",
                    value: "\(weakCount)",
                    unit: "語",
                    icon: "exclamationmark.triangle.fill",
                    color: theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                )
                HealthMetricCard(
                    title: "習得語彙",
                    value: "\(learningStats.masteredCount)",
                    unit: "語",
                    icon: "checkmark.seal.fill",
                    color: theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
                )
            }
        }
    }

    private var weakWordsAction: some View {
        NavigationLink(destination: WeakWordsView()) {
            HStack(spacing: 12) {
                let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("苦手一括復習")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("弱点語彙を集中で復習")
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                PillBadge(title: "\(weakCount)語", color: accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                    .opacity(theme.effectiveIsDark ? 0.95 : 0.98)
            )
        }
        .buttonStyle(.plain)
    }

    private func ringCard(title: String, value: String, progress: Double, color: Color) -> some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        return VStack(spacing: 8) {
            ZStack {
                HealthRingView(progress: progress, color: color, lineWidth: 8, size: 72)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(12)
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

    private var totalMinutes: Int {
        learningStats.dailyHistory.values.reduce(0) { $0 + $1.minutes }
    }

    private var totalWords: Int {
        learningStats.dailyHistory.values.reduce(0) { $0 + $1.words }
    }

    private var weakCount: Int {
        Subject.allCases.reduce(0) { partial, subject in
            let stats = masteryTracker.getStats(for: subject.rawValue)
            return partial + (stats[.weak] ?? 0)
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)分" }
        return "\(hours)時間\(remainder)分"
    }

    private func totalTimeComponents(_ minutes: Int) -> (value: String, unit: String) {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 {
            return ("\(remainder)", "m")
        }
        if remainder == 0 {
            return ("\(hours)", "h")
        }
        return ("\(hours)", "h \(remainder)m")
    }
}

// MARK: - Mastery Distribution Pie Chart

struct MasteryPieChart: View {
    @ObservedObject var masteryTracker: MasteryTracker
    @State private var selectedPage: Int = 0

    @ObservedObject private var theme = ThemeManager.shared

    private struct MasteryPage {
        enum Kind {
            case combined
            case subject
        }

        let kind: Kind
        let subject: Subject?
    }

    private struct MasteryData: Identifiable {
        let id = UUID()
        let level: MasteryLevel
        let count: Int
    }

    private var pages: [MasteryPage] {
        var result: [MasteryPage] = [MasteryPage(kind: .combined, subject: nil)]
        result.append(contentsOf: Subject.allCases.map { MasteryPage(kind: .subject, subject: $0) })
        return result
    }
    
    var body: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let safeIndex = min(selectedPage, max(pages.count - 1, 0))
        let currentPage = pages[safeIndex]
        let currentData = masteryData(for: currentPage)
        let totalCount = currentData.reduce(0) { $0 + $1.count }
        let masteredCount = currentData.first(where: { $0.level == .mastered })?.count ?? 0
        let summaryText = "合計\(totalCount)語、習熟\(masteredCount)語"
        return VStack(alignment: .leading, spacing: 16) {
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
                                        .frame(width: 160, height: 160)
                                    Image(systemName: "sparkles")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(accent)
                                }
                            }
                            .frame(height: 200)
                        } else {
                            Chart(data) { item in
                                SectorMark(
                                    angle: .value("Count", item.count),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(item.level.color)
                                .cornerRadius(5)
                            }
                            .frame(height: 260)
                            .chartOverlay { _ in
                                VStack(spacing: 4) {
                                    Text("覚えた")
                                        .font(.callout)
                                        .foregroundStyle(theme.secondaryText)
                                    Text("\(totalMastered)")
                                        .font(.title2.weight(.bold))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .foregroundStyle(theme.primaryText)
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .frame(height: 300)
            #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
            #else
                .tabViewStyle(.automatic)
            #endif
            .accessibilityLabel(Text("習熟度分布"))
            .accessibilityValue(Text(summaryText))

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

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(currentPage.subject?.displayName ?? "総合")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(MasteryLevel.allCases, id: \.self) { level in
                    let count = currentData.first(where: { $0.level == level })?.count ?? 0
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(level.color)
                            .frame(width: 12, height: 12)
                        Text(level.label)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Text("\(count)")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
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
    }

    private func masteryData(for page: MasteryPage) -> [MasteryData] {
        switch page.kind {
        case .combined:
            return combinedMasteryData()
        case .subject:
            if let subject = page.subject {
                return subjectMasteryData(subject)
            }
            return combinedMasteryData()
        }
    }

    private func combinedMasteryData() -> [MasteryData] {
        var totalStats: [MasteryLevel: Int] = [
            .new: 0, .weak: 0, .learning: 0, .almost: 0, .mastered: 0,
        ]

        var totalVocabCount = 0
        var trackedCount = 0

        for subject in Subject.allCases {
            let stats = masteryTracker.getStats(for: subject.rawValue)
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

    private func subjectMasteryData(_ subject: Subject) -> [MasteryData] {
        let stats = masteryTracker.getStats(for: subject.rawValue)
        let total = VocabularyData.shared.getVocabulary(for: subject).count
        let tracked = stats.values.reduce(0, +)
        var combined: [MasteryLevel: Int] = [:]
        for (level, count) in stats {
            combined[level, default: 0] += count
        }
        combined[.new] = max(0, total - tracked)

        return MasteryLevel.allCases.map { level in
            MasteryData(level: level, count: combined[level] ?? 0)
        }
    }
}

// MARK: - Weekly Activity Line Chart

struct WeeklyActivityChart: View {
    @ObservedObject var learningStats: LearningStats

    @ObservedObject private var theme = ThemeManager.shared
    
    var weeklyData: [(day: String, words: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ja_JP")
        
        var result: [(String, Int)] = []
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let key = formatKey(date)
            let words = learningStats.dailyHistory[key]?.words ?? 0
            let dayLabel = formatter.string(from: date)
            result.append((dayLabel, words))
        }
        
        return result
    }
    
    private func formatKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    var body: some View {
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let isEmpty = weeklyData.allSatisfy { $0.words == 0 }
        let maxEntry = weeklyData.max { $0.words < $1.words }
        let totalWords = weeklyData.reduce(0) { $0 + $1.words }
        let summaryText = maxEntry == nil
            ? "合計\(totalWords)語"
            : "合計\(totalWords)語、最多は\(maxEntry?.day ?? "-")の\(maxEntry?.words ?? 0)語"
        return VStack(alignment: .leading, spacing: 12) {
            if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primary)
                    Text("まだ記録がありません")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("クイズやタイマーを使うと推移が表示されます")
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Chart(weeklyData, id: \.day) { item in
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Words", item.words)
                    )
                    .foregroundStyle(primary)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Day", item.day),
                        y: .value("Words", item.words)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primary.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Day", item.day),
                        y: .value("Words", item.words)
                    )
                    .foregroundStyle(primary)
                    .symbolSize(item.day == maxEntry?.day ? 80 : 40)
                    .annotation(position: .top, alignment: .center) {
                        if let maxEntry, item.day == maxEntry.day {
                            Text("\(item.words)語")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
                .chartYAxisLabel("学習語数", position: .leading)
                .chartXAxisLabel("曜日")
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(primary.opacity(0.2))
                        AxisTick()
                        AxisValueLabel {
                            if let words = value.as(Int.self) {
                                Text("\(words)")
                                    .monospacedDigit()
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: weeklyData.map { $0.day }) { _ in
                        AxisGridLine()
                            .foregroundStyle(primary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel()
                            .font(.callout)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .accessibilityLabel(Text("週間推移チャート"))
                .accessibilityValue(Text(summaryText))
                .accessibilityHint(Text("曜日ごとの学習語数を示します"))
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Subject Strength Chart

struct SubjectStrengthChart: View {
    @ObservedObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared
    
    var subjectStrength: [(subject: String, score: Double)] {
        let subjects = ["english", "kobun", "kanbun", "seikei"]
        let names = ["英単語", "古文", "漢文", "政経"]
        
        return subjects.enumerated().map { index, subject in
            let data = masteryTracker.items[subject] ?? [:]
            let total = data.count
            guard total > 0 else { return (names[index], 0.0) }
            
            var score = 0.0
            for (_, item) in data {
                switch item.mastery {
                case .mastered: score += 1.0
                case .almost: score += 0.75
                case .learning: score += 0.5
                case .weak: score += 0.25
                case .new: score += 0
                }
            }
            
            return (names[index], (score / Double(total)) * 100)
        }
    }
    
    var body: some View {
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let isEmpty = subjectStrength.allSatisfy { $0.score == 0 }
        let maxSubject = subjectStrength.max { $0.score < $1.score }
        let summaryText = maxSubject == nil
            ? "データがありません"
            : "最高は\(maxSubject?.subject ?? "-")の\(Int(maxSubject?.score ?? 0))%"
        return VStack(alignment: .leading, spacing: 12) {
            if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(mastered)
                    Text("まだ学習がありません")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("学習が進むと科目ごとの棒グラフが表示されます")
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Chart(subjectStrength, id: \.subject) { item in
                    BarMark(
                        x: .value("Subject", item.subject),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [mastered, primary],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(8)
                    .annotation(position: .top, alignment: .center) {
                        if item.subject == maxSubject?.subject {
                            Text("\(Int(item.score))%")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
                .frame(height: 220)
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("習熟度(%)", position: .leading)
                .chartXAxisLabel("科目")
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 25)) { value in
                        AxisGridLine()
                            .foregroundStyle(mastered.opacity(0.2))
                        AxisTick()
                        AxisValueLabel {
                            if let percent = value.as(Double.self) {
                                Text("\(Int(percent))%")
                                    .monospacedDigit()
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: subjectStrength.map { $0.subject }) { _ in
                        AxisTick()
                        AxisValueLabel()
                            .font(.callout)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .accessibilityLabel(Text("科目別習熟度チャート"))
                .accessibilityValue(Text(summaryText))
            }
        }
    }
}

// Previews removed for SPM
