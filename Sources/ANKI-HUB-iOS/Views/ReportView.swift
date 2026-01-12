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
    
    var masteryData: [(level: MasteryLevel, count: Int)] {
        var counts: [MasteryLevel: Int] = [:]
        for level in MasteryLevel.allCases {
            counts[level] = 0
        }
        
        for (_, subjectData) in masteryTracker.items {
            for (_, item) in subjectData {
                counts[item.mastery, default: 0] += 1
            }
        }
        
        return MasteryLevel.allCases.map { ($0, counts[$0] ?? 0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("習熟度分布")
                .font(.headline)
            
            Chart(masteryData, id: \.level) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.0
                )
                .foregroundStyle(item.level.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(masteryData, id: \.level) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.level.color)
                            .frame(width: 12, height: 12)
                        Text("\(item.level.label): \(item.count)")
                            .font(.caption)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .liquidGlass()
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
