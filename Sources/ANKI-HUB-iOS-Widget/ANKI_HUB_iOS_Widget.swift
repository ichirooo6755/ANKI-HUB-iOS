import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
    import ActivityKit
#endif

private let appGroupId = "group.com.ankihub.ios"
private let learningStatsKey = "anki_hub_learning_stats"
private let recentMistakeKey = "anki_hub_recent_mistake_v1"
private let recentMistakesKey = "anki_hub_recent_mistakes_v1"
private let widgetSubjectFilterKey = "anki_hub_widget_subject_filter_v1"
private let widgetShowStreakKey = "anki_hub_widget_show_streak_v1"
private let widgetShowTodayMinutesKey = "anki_hub_widget_show_today_minutes_v1"
private let widgetShowMistakesKey = "anki_hub_widget_show_mistakes_v1"
private let widgetMistakeCountKey = "anki_hub_widget_mistake_count_v1"
private let widgetStyleKey = "anki_hub_widget_style_v1"

fileprivate struct WidgetSettings {
    let showStreak: Bool
    let showTodayMinutes: Bool
    let showMistakes: Bool
    let mistakeCount: Int
    let style: String

    init(defaults: UserDefaults?) {
        self.showStreak = defaults?.object(forKey: widgetShowStreakKey) as? Bool ?? true
        self.showTodayMinutes = defaults?.object(forKey: widgetShowTodayMinutesKey) as? Bool ?? true
        self.showMistakes = defaults?.object(forKey: widgetShowMistakesKey) as? Bool ?? true
        let count = defaults?.integer(forKey: widgetMistakeCountKey) ?? 3
        self.mistakeCount = max(1, min(3, count))
        self.style = defaults?.string(forKey: widgetStyleKey) ?? "system"
    }
}

struct StudyEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayMinutes: Int
    let mistakes: [String]
    fileprivate let settings: WidgetSettings
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return StudyEntry(date: Date(), streak: 3, todayMinutes: 20, mistakes: [], settings: WidgetSettings(defaults: defaults))
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        completion(loadEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let first = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? now.addingTimeInterval(3600)

        var entries: [StudyEntry] = []
        entries.append(loadEntry(at: now))
        for i in 0..<24 {
            let date = calendar.date(byAdding: .hour, value: i, to: first) ?? first.addingTimeInterval(TimeInterval(i * 3600))
            entries.append(loadEntry(at: date))
        }

        let policyDate = calendar.date(byAdding: .hour, value: 24, to: first) ?? first.addingTimeInterval(24 * 3600)
        completion(Timeline(entries: entries, policy: .after(policyDate)))
    }

    private func loadEntry(at date: Date) -> StudyEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let settings = WidgetSettings(defaults: defaults)

        struct RecentMistake: Decodable {
            let subject: String
            let term: String
            let correct: String
            let date: Date
        }

        let subjectFilter = defaults?.string(forKey: widgetSubjectFilterKey) ?? ""

        var mistakes: [String] = []
        if let mdata = defaults?.data(forKey: recentMistakesKey),
            let decoded = try? JSONDecoder().decode([RecentMistake].self, from: mdata)
        {
            let filtered =
                decoded
                .filter { subjectFilter.isEmpty ? true : $0.subject == subjectFilter }
                .sorted { $0.date > $1.date }

            let strings = filtered.map { "\($0.term) → \($0.correct)" }
            let count = min(settings.mistakeCount, strings.count)
            if count > 0 {
                let hourIndex = Int(date.timeIntervalSince1970 / 3600)
                let start = hourIndex % strings.count
                var rotated: [String] = []
                rotated.reserveCapacity(count)
                for i in 0..<count {
                    rotated.append(strings[(start + i) % strings.count])
                }
                mistakes = rotated
            }
        }

        if mistakes.isEmpty, let mdata = defaults?.data(forKey: recentMistakeKey) {
            struct SingleMistake: Decodable {
                let subject: String
                let term: String
                let correct: String
            }
            if let m = try? JSONDecoder().decode(SingleMistake.self, from: mdata) {
                if subjectFilter.isEmpty || m.subject == subjectFilter {
                    mistakes = ["\(m.term) → \(m.correct)"]
                }
            }
        }

        if let data = defaults?.data(forKey: learningStatsKey) {
            struct Stored: Decodable {
                let streak: Int
                let todayMinutes: Int
            }
            if let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
                return StudyEntry(
                    date: date,
                    streak: decoded.streak,
                    todayMinutes: decoded.todayMinutes,
                    mistakes: settings.showMistakes ? mistakes : [],
                    settings: settings
                )
            }
        }
        return StudyEntry(date: date, streak: 0, todayMinutes: 0, mistakes: settings.showMistakes ? mistakes : [], settings: settings)
    }
}

struct StudyWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("sugwrAnki")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.settings.showStreak {
                Text("連続 \(entry.streak)日")
                    .font(.title2.bold())
            }

            if entry.settings.showTodayMinutes {
                Text("今日 \(entry.todayMinutes)分")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.mistakes.prefix(2), id: \.self) { m in
                        Text(m)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if family == .systemSmall {
                if let m = entry.mistakes.first {
                    Text(m)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            #if os(iOS)
                if family == .accessoryRectangular {
                    VStack(alignment: .leading, spacing: 2) {
                        if entry.settings.showStreak {
                            Text("連続 \(entry.streak)日")
                                .font(.headline)
                        }
                        if let m = entry.mistakes.first {
                            Text(m)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if family == .accessoryInline {
                    HStack(spacing: 6) {
                        if entry.settings.showStreak {
                            Text("\(entry.streak)日")
                        }
                        if let m = entry.mistakes.first {
                            Text(m)
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                }
            #endif

            Spacer()
        }
        .padding(14)
    }
}

struct StudyWidget: Widget {
    let kind: String = "StudyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if entry.settings.style == "system" {
                StudyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StudyWidgetEntryView(entry: entry)
                    .containerBackground(backgroundColor(for: entry.settings.style), for: .widget)
            }
        }
        .configurationDisplayName("学習状況")
        .description("連続学習日数と今日の学習時間を表示します")
        #if os(iOS)
            .supportedFamilies([
                .systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular,
            ])
        #else
            .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }

    private func backgroundColor(for style: String) -> Color {
        switch style {
        case "dark":
            return Color.black.opacity(0.75)
        case "accent":
            return Color.blue.opacity(0.25)
        default:
            return Color.clear
        }
    }
}

@main
struct ANKI_HUB_iOS_WidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyWidget()
        #if canImport(ActivityKit)
            StudyLiveActivity()
        #endif
    }
}

#if canImport(ActivityKit)
    struct StudyLiveActivity: Widget {
        var body: some WidgetConfiguration {
            ActivityConfiguration(for: FocusTimerAttributes.self) { context in
                // Lock Screen / Banner UI
                VStack {
                    HStack(alignment: .lastTextBaseline) {
                        Text(context.attributes.timerName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(context.state.targetTime, style: .timer)
                            .font(.system(size: 32, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.yellow)
                    }
                    .padding()
                }
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.yellow)

            } dynamicIsland: { context in
                DynamicIsland {
                    // Expanded UI
                    DynamicIslandExpandedRegion(.leading) {
                        Text(context.attributes.timerName)
                            .font(.caption)
                            .padding(.leading)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Text(context.state.targetTime, style: .timer)
                            .font(.title2.monospacedDigit())
                            .padding(.trailing)
                    }
                    DynamicIslandExpandedRegion(.center) {
                        Text("Focus")
                            .font(.caption)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        ProgressView(
                            timerInterval: Date()...context.state.targetTime, countsDown: true
                        )
                        .tint(.yellow)
                        .padding([.leading, .trailing])
                    }
                } compactLeading: {
                    Image(systemName: "timer")
                        .tint(.yellow)
                } compactTrailing: {
                    Text(context.state.targetTime, style: .timer)
                        .monospacedDigit()
                        .frame(maxWidth: 40)
                } minimal: {
                    Image(systemName: "timer")
                        .tint(.yellow)
                }
            }
        }
    }
#endif
