import SwiftUI

struct TimelineView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var timelineManager = TimelineManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeader(
                            title: "タイムライン",
                            subtitle: nil,
                            trailing: "\(timelineManager.entries.count)件"
                        )

                        summaryCards

                        if timelineManager.entries.isEmpty {
                            ContentUnavailableView {
                                Label("タイムラインがありません", systemImage: "clock.arrow.circlepath")
                            }
                            .padding(.top, 24)
                        } else {
                            ForEach(timelineManager.entries) { entry in
                                TimelineEntryCard(entry: entry)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("タイムライン")
            .applyAppTheme()
        }
    }

    private var summaryCards: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let secondary = theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                HealthMetricCard(
                    title: "学習ログ",
                    value: "\(studyLogCount)",
                    unit: "件",
                    icon: "book.closed.fill",
                    color: accent
                )
                HealthMetricCard(
                    title: "習得",
                    value: "\(masteredCount)",
                    unit: "件",
                    icon: "checkmark.seal.fill",
                    color: mastered
                )
            }
            HealthMetricCard(
                title: "メモ",
                value: "\(noteCount)",
                unit: "件",
                icon: "note.text",
                color: secondary
            )
        }
    }

    private var studyLogCount: Int {
        timelineManager.entries.filter { $0.type == .studyLog }.count
    }

    private var masteredCount: Int {
        timelineManager.entries.filter { $0.type == .mastered }.count
    }

    private var noteCount: Int {
        timelineManager.entries.filter { $0.type == .note }.count
    }
}

private struct TimelineEntryCard: View {
    let entry: StudyTimelineEntry
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let accent = entryColor
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: entryIcon)
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    Text(entry.summary)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dateLabel)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                    PillBadge(title: typeLabel, color: accent)
                }
            }

            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
            }

            if let subjectLabel {
                Text(subjectLabel)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .opacity(theme.effectiveIsDark ? 0.95 : 0.98)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var entryIcon: String {
        switch entry.type {
        case .studyLog:
            return "book.closed.fill"
        case .mastered:
            return "checkmark.seal.fill"
        case .note:
            return "note.text"
        }
    }

    private var entryColor: Color {
        switch entry.type {
        case .studyLog:
            return theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        case .mastered:
            return theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        case .note:
            return theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)
        }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        return formatter.string(from: entry.createdAt)
    }

    private var typeLabel: String {
        switch entry.type {
        case .studyLog:
            return "学習ログ"
        case .mastered:
            return "習得"
        case .note:
            return "メモ"
        }
    }

    private var subjectLabel: String? {
        guard let subject = entry.subject, let subjectEnum = Subject(rawValue: subject) else {
            return nil
        }
        return "科目: \(subjectEnum.displayName)"
    }
}
