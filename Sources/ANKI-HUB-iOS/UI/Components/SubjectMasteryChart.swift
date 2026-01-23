import Charts
import SwiftUI

/// 科目別の習熟度ドーナツチャート（コンパクト版）
struct SubjectMasteryChart: View {
    let subject: Subject
    @ObservedObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let data = getMasteryData()
        let totalCount = data.reduce(0) { $0 + $1.count }
        let masteredCount = data.first(where: { $0.level == .mastered })?.count ?? 0
        let summaryText = "合計\(totalCount)語、習熟\(masteredCount)語"
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度")
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.secondaryText.opacity(0.62))

            HStack(spacing: 16) {
                // Donut Chart
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.0
                    )
                    .cornerRadius(3)
                    .foregroundStyle(item.level.color)
                }
                .frame(width: 80, height: 80)
                .accessibilityLabel(Text("科目別習熟度"))
                .accessibilityValue(Text(summaryText))

                // Legend with counts
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        let count = data.first(where: { $0.level == level })?.count ?? 0
                        HStack(spacing: 6) {
                            Circle()
                                .fill(level.color)
                                .frame(width: 8, height: 8)
                            Text(level.label)
                                .font(.callout)
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            Text("\(count)")
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }

    // MARK: - Data Helper

    struct MasteryData: Identifiable {
        let id = UUID()
        let level: MasteryLevel
        let count: Int
    }

    private func getMasteryData() -> [MasteryData] {
        let stats = masteryTracker.getStats(for: subject.rawValue)

        // Get total vocabulary count for the subject to calculate "new" items
        let totalVocab = VocabularyData.shared.getVocabulary(for: subject).count
        let trackedCount = stats.values.reduce(0, +)
        let newCount = max(0, totalVocab - trackedCount)

        return MasteryLevel.allCases.map { level in
            if level == .new {
                return MasteryData(level: level, count: newCount)
            }
            return MasteryData(level: level, count: stats[level] ?? 0)
        }
    }
}
