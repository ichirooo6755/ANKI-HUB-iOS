import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
    import ActivityKit
#endif

#if canImport(AppIntents)
    import AppIntents
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
private let widgetShowTodoKey = "anki_hub_widget_show_todo_v1"
private let widgetTodoCountKey = "anki_hub_widget_todo_count_v1"
private let widgetStyleKey = "anki_hub_widget_style_v1"
private let widgetTimerMinutesKey = "anki_hub_widget_timer_minutes_v1"

private let todoItemsKey = "anki_hub_todo_items_v1"

fileprivate struct WidgetSettings {
    let showStreak: Bool
    let showTodayMinutes: Bool
    let showMistakes: Bool
    let mistakeCount: Int
    let showTodo: Bool
    let todoCount: Int
    let style: String
    let timerMinutes: Int

    init(defaults: UserDefaults?) {
        self.showStreak = defaults?.object(forKey: widgetShowStreakKey) as? Bool ?? true
        self.showTodayMinutes = defaults?.object(forKey: widgetShowTodayMinutesKey) as? Bool ?? true
        self.showMistakes = defaults?.object(forKey: widgetShowMistakesKey) as? Bool ?? true
        let count = defaults?.integer(forKey: widgetMistakeCountKey) ?? 3
        self.mistakeCount = max(1, min(3, count))
        self.showTodo = defaults?.object(forKey: widgetShowTodoKey) as? Bool ?? false
        let todoCount = defaults?.integer(forKey: widgetTodoCountKey) ?? 2
        self.todoCount = max(1, min(3, todoCount))
        self.style = defaults?.string(forKey: widgetStyleKey) ?? "system"
        let rawMinutes = defaults?.integer(forKey: widgetTimerMinutesKey) ?? 25
        self.timerMinutes = max(1, min(180, rawMinutes))
    }
}

struct StudyEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayMinutes: Int
    let mistakes: [String]
    let todos: [String]
    fileprivate let settings: WidgetSettings
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return StudyEntry(
            date: Date(),
            streak: 3,
            todayMinutes: 20,
            mistakes: [],
            todos: [],
            settings: WidgetSettings(defaults: defaults)
        )
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
                let todos = loadTodos(defaults: defaults, settings: settings)
                return StudyEntry(
                    date: date,
                    streak: decoded.streak,
                    todayMinutes: decoded.todayMinutes,
                    mistakes: settings.showMistakes ? mistakes : [],
                    todos: settings.showTodo ? todos : [],
                    settings: settings
                )
            }
        }

        let todos = loadTodos(defaults: defaults, settings: settings)
        return StudyEntry(
            date: date,
            streak: 0,
            todayMinutes: 0,
            mistakes: settings.showMistakes ? mistakes : [],
            todos: settings.showTodo ? todos : [],
            settings: settings
        )
    }

    private func loadTodos(defaults: UserDefaults?, settings: WidgetSettings) -> [String] {
        guard settings.showTodo else { return [] }
        guard let data = defaults?.data(forKey: todoItemsKey) else { return [] }

        struct StoredTodoItem: Decodable {
            let id: UUID
            let title: String
            let isCompleted: Bool
            let dueDate: Date?
            let createdAt: Date
        }

        guard let decoded = try? JSONDecoder().decode([StoredTodoItem].self, from: data) else {
            return []
        }

        let pending = decoded
            .filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .map { $0.title }

        return Array(pending.prefix(settings.todoCount))
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

                    if entry.settings.showTodo {
                        ForEach(entry.todos.prefix(entry.settings.todoCount), id: \.self) { t in
                            Text("• \(t)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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

                if entry.settings.showTodo, let t = entry.todos.first {
                    Text(t)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if family == .systemSmall || family == .systemMedium {
                if let url = timerURL(minutes: entry.settings.timerMinutes) {
                    Link(destination: url) {
                        Label("タイマー開始", systemImage: "play.fill")
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
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

    private func timerURL(minutes: Int) -> URL? {
        var comps = URLComponents()
        comps.scheme = "sugwranki"
        comps.host = "timer"
        comps.path = "/start"
        comps.queryItems = [URLQueryItem(name: "minutes", value: String(minutes))]
        return comps.url
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
    #if canImport(AppIntents)
        struct FocusTimerTogglePauseIntent: AppIntent {
            static var title: LocalizedStringResource = "Toggle Pause"
            static var description = IntentDescription("Pause/Resume focus timer")

            func perform() async throws -> some IntentResult {
                guard let activity = Activity<FocusTimerAttributes>.activities.first else {
                    return .result()
                }

                let now = Date()
                let state = activity.content.state

                if state.isPaused {
                    let remaining = max(0, state.pausedRemainingSeconds ?? 0)
                    let target = now.addingTimeInterval(TimeInterval(remaining))
                    let newState = FocusTimerAttributes.ContentState(
                        targetTime: target,
                        totalSeconds: state.totalSeconds,
                        pausedRemainingSeconds: nil,
                        isPaused: false
                    )
                    await activity.update(ActivityContent(state: newState, staleDate: nil))
                } else {
                    let remaining = max(0, Int(state.targetTime.timeIntervalSince(now)))
                    let newState = FocusTimerAttributes.ContentState(
                        targetTime: state.targetTime,
                        totalSeconds: state.totalSeconds,
                        pausedRemainingSeconds: remaining,
                        isPaused: true
                    )
                    await activity.update(ActivityContent(state: newState, staleDate: nil))
                }

                return .result()
            }
        }

        struct FocusTimerStopIntent: AppIntent {
            static var title: LocalizedStringResource = "Stop Timer"
            static var description = IntentDescription("Stop focus timer")

            func perform() async throws -> some IntentResult {
                guard let activity = Activity<FocusTimerAttributes>.activities.first else {
                    return .result()
                }
                let state = FocusTimerAttributes.ContentState(
                    targetTime: Date(),
                    totalSeconds: max(1, activity.content.state.totalSeconds),
                    pausedRemainingSeconds: 0,
                    isPaused: true
                )
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
                return .result()
            }
        }
    #endif

    struct StudyLiveActivity: Widget {
        var body: some WidgetConfiguration {
            ActivityConfiguration(for: FocusTimerAttributes.self) { context in
                // Lock Screen / Banner UI
                VStack {
                    HStack(alignment: .lastTextBaseline) {
                        HStack(spacing: 8) {
                            Image(systemName: "stopwatch.fill")
                                .foregroundStyle(.yellow)
                            Text(context.attributes.timerName)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Spacer()

                        if context.state.isPaused {
                            let remaining = max(0, context.state.pausedRemainingSeconds ?? 0)
                            Text(Date().addingTimeInterval(TimeInterval(remaining)), style: .timer)
                                .font(.system(size: 32, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.yellow)
                        } else {
                            Text(context.state.targetTime, style: .timer)
                                .font(.system(size: 32, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.yellow)
                        }
                    }
                    .padding()

                    if context.state.isPaused {
                        let remaining = max(0, context.state.pausedRemainingSeconds ?? 0)
                        ProgressView(value: Double(context.state.totalSeconds - remaining), total: Double(context.state.totalSeconds))
                            .tint(.yellow)
                            .padding([.leading, .trailing, .bottom])
                    } else {
                        ProgressView(timerInterval: Date()...context.state.targetTime, countsDown: true)
                            .tint(.yellow)
                            .padding([.leading, .trailing, .bottom])
                    }

                    #if canImport(AppIntents)
                        HStack(spacing: 14) {
                            Button(intent: FocusTimerTogglePauseIntent()) {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)

                            Button(intent: FocusTimerStopIntent()) {
                                Image(systemName: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.white.opacity(0.25))
                        }
                        .padding(.bottom, 8)
                    #endif
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
                    Image(systemName: "stopwatch.fill")
                        .tint(.yellow)
                } compactTrailing: {
                    Text(context.state.targetTime, style: .timer)
                        .monospacedDigit()
                        .frame(maxWidth: 40)
                } minimal: {
                    Image(systemName: "stopwatch.fill")
                        .tint(.yellow)
                }
            }
        }
    }
#endif
