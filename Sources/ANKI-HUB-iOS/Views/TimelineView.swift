import SwiftUI

struct TimelineView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var timelineManager = TimelineManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    LazyVStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("タイムライン")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            Text("\(timelineManager.entries.count)件")
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(theme.secondaryText.opacity(0.62))
                        }

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
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let style = theme.widgetCardStyle
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        let fill: AnyShapeStyle = {
            switch style {
            case "neo":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [surface.opacity(isDark ? 0.86 : 0.98), accent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "outline":
                return AnyShapeStyle(surface.opacity(0.001))
            default:
                return AnyShapeStyle(surface.opacity(isDark ? 0.92 : 0.98))
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
            default:
                return 6
            }
        }()
        let shadowColor: Color = {
            switch style {
            case "outline":
                return .clear
            default:
                return Color.black.opacity(isDark ? 0.20 : 0.05)
            }
        }()

        return ZStack(alignment: .topTrailing) {
            Image(systemName: entryIcon)
                .font(.system(size: 96, weight: .bold, design: .default))
                .foregroundStyle(accent.opacity(isDark ? (style == "neo" ? 0.20 : 0.16) : (style == "neo" ? 0.16 : 0.12)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.primaryText)

                        if !entry.summary.isEmpty {
                            Text(entry.summary)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.secondaryText.opacity(0.62))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(dateLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.secondaryText.opacity(0.62))
                        PillBadge(title: typeLabel, color: accent)
                    }
                }

                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let subjectLabel {
                    Text(subjectLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.62))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardShape.fill(fill))
        .overlay(cardShape.stroke(stroke, lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
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
