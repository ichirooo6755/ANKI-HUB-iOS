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

struct StudyEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayMinutes: Int
    let mistakes: [String]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry {
        StudyEntry(date: Date(), streak: 3, todayMinutes: 20, mistakes: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let entry = loadEntry()
        let next =
            Calendar.current.date(byAdding: .minute, value: 5, to: Date())
            ?? Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> StudyEntry {
        let defaults = UserDefaults(suiteName: appGroupId)

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
            mistakes = filtered.prefix(3).map { "\($0.term) → \($0.correct)" }
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
                    date: Date(),
                    streak: decoded.streak,
                    todayMinutes: decoded.todayMinutes,
                    mistakes: mistakes
                )
            }
        }
        return StudyEntry(date: Date(), streak: 0, todayMinutes: 0, mistakes: mistakes)
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

            Text("連続 \(entry.streak)日")
                .font(.title2.bold())

            Text("今日 \(entry.todayMinutes)分")
                .font(.headline)
                .foregroundStyle(.secondary)

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
                        Text("連続 \(entry.streak)日")
                            .font(.headline)
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
                        Text("\(entry.streak)日")
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
            StudyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
