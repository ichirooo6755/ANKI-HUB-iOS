import SwiftUI
import Charts

struct ReportView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var learningStats: LearningStats

    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    NavigationLink(destination: WeakWordsView()) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                            Text("苦手一括復習")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .liquidGlass()
                    }

                    // Mastery Pie Chart
                    MasteryPieChart(masteryTracker: masteryTracker)
                    
                    // Weekly Activity Line Chart
                    WeeklyActivityChart(learningStats: learningStats)
                    
                    // Subject Strength Radar (Simplified Bar Chart for iOS)
                    SubjectStrengthChart(masteryTracker: masteryTracker)
                }
                .padding()
            }
            .navigationTitle("レポート")
            .background(ThemeManager.shared.background)
            .applyAppTheme()
        }
    }
}

// MARK: - Mastery Distribution Pie Chart

struct MasteryPieChart: View {
    @ObservedObject var masteryTracker: MasteryTracker
    @State private var selectedPage: Int = 0

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Mastery")
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    let data = masteryData(for: page)
                    let totalMastered = data.first(where: { $0.level == .mastered })?.count ?? 0
                    VStack(spacing: 10) {
                        Chart(data) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.level.color)
                            .cornerRadius(5)
                        }
                        .frame(height: 200)
                        .chartOverlay { _ in
                            VStack(spacing: 4) {
                                Text("覚えた")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(totalMastered)")
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                        }

                        Text(page.subject?.displayName ?? "総合")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Legend
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(MasteryLevel.allCases, id: \.self) { level in
                                let count = data.first(where: { $0.level == level })?.count ?? 0
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(level.color)
                                        .frame(width: 12, height: 12)
                                    Text("\(level.label): \(count)")
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .frame(height: 320)
            #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            #else
                .tabViewStyle(.automatic)
            #endif
        }
        .padding()
        .liquidGlass()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("週間学習量")
                .font(.headline)
            
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
            }
            .frame(height: 180)
        }
        .padding()
        .liquidGlass()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("科目別習得度")
                .font(.headline)
            
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
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
        }
        .padding()
        .liquidGlass()
    }
}

// Previews removed for SPM
