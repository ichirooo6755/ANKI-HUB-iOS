import SwiftUI
import WidgetKit

import Foundation

#if canImport(ANKI_HUB_iOS_Shared)
    import ANKI_HUB_iOS_Shared
#endif

#if canImport(ActivityKit) && os(iOS)
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
private let widgetShowCalendarKey = "anki_hub_widget_show_calendar_v1"
private let widgetStyleKey = "anki_hub_widget_style_v1"
private let widgetTimerMinutesKey = "anki_hub_widget_timer_minutes_v1"
private let widgetThemePrimaryLightKey = "anki_hub_widget_theme_primary_light_v1"
private let widgetThemePrimaryDarkKey = "anki_hub_widget_theme_primary_dark_v1"
private let widgetThemeAccentLightKey = "anki_hub_widget_theme_accent_light_v1"
private let widgetThemeAccentDarkKey = "anki_hub_widget_theme_accent_dark_v1"
private let widgetThemeSurfaceLightKey = "anki_hub_widget_theme_surface_light_v1"
private let widgetThemeSurfaceDarkKey = "anki_hub_widget_theme_surface_dark_v1"
private let widgetThemeBackgroundLightKey = "anki_hub_widget_theme_background_light_v1"
private let widgetThemeBackgroundDarkKey = "anki_hub_widget_theme_background_dark_v1"
private let widgetThemeTextLightKey = "anki_hub_widget_theme_text_light_v1"
private let widgetThemeTextDarkKey = "anki_hub_widget_theme_text_dark_v1"
private let widgetThemeSchemeOverrideKey = "anki_hub_widget_theme_color_scheme_override_v1"
private let scanStartRequestKey = "anki_hub_scan_start_request_v1"
private let frontCameraStartRequestKey = "anki_hub_front_camera_start_request_v1"
private let controlTimerURL = URL(string: "sugwranki://timer/start?minutes=25")!
private let controlFrontCameraURL = URL(string: "sugwranki://camera/front")!
private let controlScanURL = URL(string: "sugwranki://scan/start")!
private let controlStudyTabURL = URL(string: "sugwranki://tab/study")!
private let controlSessionStartURL = URL(string: "sugwranki://session/start")!
private let controlSessionStopURL = URL(string: "sugwranki://session/stop")!
private let controlSessionPinURL = URL(string: "sugwranki://session/pin")!

private let widgetAccent = Color(red: 0.96, green: 0.36, blue: 0.20)

private let todoItemsKey = "anki_hub_todo_items_v1"

private extension View {
    @ViewBuilder
    func widgetContainerBackground(_ style: AnyShapeStyle, fallback: Color? = nil) -> some View {
        #if os(iOS)
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            if let fallback {
                self.background(fallback)
            } else {
                self
            }
        }
        #else
        self
        #endif
    }
}

fileprivate struct WidgetSettings {
    let showStreak: Bool
    let showTodayMinutes: Bool
    let showMistakes: Bool
    let mistakeCount: Int
    let showTodo: Bool
    let todoCount: Int
    let showCalendar: Bool
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
        self.showCalendar = defaults?.object(forKey: widgetShowCalendarKey) as? Bool ?? false
        self.style = defaults?.string(forKey: widgetStyleKey) ?? "system"
        let rawMinutes = defaults?.integer(forKey: widgetTimerMinutesKey) ?? 25
        self.timerMinutes = max(1, min(180, rawMinutes))
    }

}

fileprivate struct WidgetDailyEntry: Decodable {
    let words: Int
    let minutes: Int
    let subjects: [String: Int]
}

fileprivate struct WidgetStoredStats: Decodable {
    let streak: Int
    let todayMinutes: Int
    let dailyHistory: [String: WidgetDailyEntry]
}

struct WidgetCalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let level: Int
    let isToday: Bool
}

#if canImport(AppIntents) && swift(>=6.0) && os(iOS)
@available(iOS 18.0, *)
struct TimerStartControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "TimerStartControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlTimerURL)) {
                Label("タイマー", systemImage: "timer")
            }
        }
        .displayName("タイマー開始")
        .description("25分のタイマーを開始します")
    }
}

@available(iOS 18.0, *)
struct FrontCameraControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "FrontCameraControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlFrontCameraURL)) {
                Label("カメラ", systemImage: "camera.fill")
            }
        }
        .displayName("フロントカメラ")
        .description("フロントカメラ撮影を起動します")
    }
}

@available(iOS 18.0, *)
struct ScanControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "ScanControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlScanURL)) {
                Label("スキャン", systemImage: "doc.text.viewfinder")
            }
        }
        .displayName("スキャン")
        .description("スキャンを開始します")
    }
}

@available(iOS 18.0, *)
struct StudyTabControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "StudyTabControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlStudyTabURL)) {
                Label("学習タブ", systemImage: "book.fill")
            }
        }
        .displayName("学習タブ")
        .description("学習タブをすぐ開きます")
    }
}

@available(iOS 18.0, *)
struct SessionStartControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "SessionStartControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlSessionStartURL)) {
                Label("開始", systemImage: "play.circle.fill")
            }
        }
        .displayName("勉強をスタート")
        .description("学習セッションを開始します")
    }
}

@available(iOS 18.0, *)
struct SessionStopControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "SessionStopControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlSessionStopURL)) {
                Label("終了", systemImage: "stop.circle.fill")
            }
        }
        .displayName("勉強を終了")
        .description("学習セッションを終了します")
    }
}

@available(iOS 18.0, *)
struct SessionPinControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "SessionPinControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlSessionPinURL)) {
                Label("ピン", systemImage: "pin.circle.fill")
            }
        }
        .displayName("ピンを打つ")
        .description("学習内容を記録するピン入力を開きます")
    }
}
#endif

struct BlackClockWidget: Widget {
    let kind: String = "BlackClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BlackClockWidgetEntryView(entry: entry)
                .widgetContainerBackground(AnyShapeStyle(.fill.tertiary))
        }
        .configurationDisplayName("ブラッククロック")
        .description("黒基調の時計タイル")
        .contentMarginsDisabled()
        #if os(iOS)
            .supportedFamilies([.systemSmall, .systemMedium])
        #else
            .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

private struct BlackClockWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var themeSnapshot: WidgetThemeSnapshot? {
        WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
    }

    private var accentColor: Color {
        themeSnapshot?.resolvedAccent(for: resolvedScheme) ?? widgetAccent
    }

    private var surfaceColor: Color {
        themeSnapshot?.resolvedSurface(for: resolvedScheme)
            ?? (resolvedScheme == .dark ? Color.black : Color.white)
    }

    private var textColor: Color {
        themeSnapshot?.resolvedText(for: resolvedScheme)
            ?? (resolvedScheme == .dark ? .white : .black)
    }

    private var resolvedScheme: ColorScheme {
        themeSnapshot?.resolvedScheme(for: colorScheme) ?? colorScheme
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.date)
    }

    private var monthDayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd"
        return formatter.string(from: entry.date)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let bg = resolvedScheme == .dark
            ? Color.black.opacity(0.9)
            : (themeSnapshot?.resolvedBackground(for: resolvedScheme) ?? Color.white)
        let border = accentColor.opacity(0.20)

        return ZStack(alignment: .topLeading) {
            cardShape
                .fill(bg)
                .overlay(cardShape.stroke(border, lineWidth: 1))

            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(dayLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(textColor.opacity(0.7))
                        Text(monthLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(textColor.opacity(0.7))
                        Text(monthDayLabel)
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(textColor.opacity(0.7))
                        Spacer()
                    }

                    Text(entry.date, style: .time)
                        .font(.system(size: 44, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(textColor.opacity(0.7))
                            Text("\(entry.todayMinutes)")
                                .font(.system(size: 30, weight: .black, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(textColor)
                        }
                        Text("分")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(textColor.opacity(0.7))

                        Spacer()

                        Text("\(entry.streak)日")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accentColor.opacity(0.16)))
                    }
                }
                .padding(14)
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(dayLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(textColor.opacity(0.7))
                            Text(monthLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(textColor.opacity(0.7))
                            Text(monthDayLabel)
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(textColor.opacity(0.7))
                            Spacer()
                        }

                        Text(entry.date, style: .time)
                            .font(.system(size: 54, weight: .black, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("今日")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(textColor.opacity(0.7))
                                Text("\(entry.todayMinutes)")
                                    .font(.system(size: 34, weight: .black, design: .default))
                                    .monospacedDigit()
                                    .foregroundStyle(textColor)
                            }
                            Text("分")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(textColor.opacity(0.7))

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("連続")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(textColor.opacity(0.7))
                                Text("\(entry.streak)日")
                                    .font(.system(size: 34, weight: .black, design: .default))
                                    .monospacedDigit()
                                    .foregroundStyle(accentColor)
                            }
                        }
                    }

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(surfaceColor.opacity(resolvedScheme == .dark ? 0.14 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(accentColor.opacity(0.20), lineWidth: 1)
                        )
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TODO")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(0.7))
                                if entry.todos.isEmpty {
                                    Text("0")
                                        .font(.system(size: 42, weight: .black, design: .default))
                                        .monospacedDigit()
                                        .foregroundStyle(textColor)
                                } else {
                                    Text("\(entry.todos.count)")
                                        .font(.system(size: 42, weight: .black, design: .default))
                                        .monospacedDigit()
                                        .foregroundStyle(textColor)
                                }
                                Spacer()
                                Text("件")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(textColor.opacity(0.7))
                            }
                            .padding(14)
                        )
                        .frame(width: 120)
                }
                .padding(14)
            }
        }
    }
}

struct BlackStatsWidget: Widget {
    let kind: String = "BlackStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BlackStatsWidgetEntryView(entry: entry)
                .widgetContainerBackground(AnyShapeStyle(.fill.tertiary))
        }
        .configurationDisplayName("ブラックスタッツ")
        .description("学習の数値を黒いタイルで表示します")
        .contentMarginsDisabled()
        #if os(iOS)
            .supportedFamilies([.systemSmall, .systemMedium])
        #else
            .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

private struct BlackStatsWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var themeSnapshot: WidgetThemeSnapshot? {
        WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
    }

    private var accentColor: Color {
        themeSnapshot?.resolvedAccent(for: resolvedScheme) ?? widgetAccent
    }

    private var textColor: Color {
        themeSnapshot?.resolvedText(for: resolvedScheme)
            ?? (resolvedScheme == .dark ? .white : .black)
    }

    private var resolvedScheme: ColorScheme {
        themeSnapshot?.resolvedScheme(for: colorScheme) ?? colorScheme
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let bg = resolvedScheme == .dark
            ? Color.black.opacity(0.9)
            : (themeSnapshot?.resolvedBackground(for: resolvedScheme) ?? Color.white)
        let border = accentColor.opacity(0.20)

        func statPill(title: String, value: String, unit: String) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(textColor.opacity(0.7))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 36, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(textColor.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accentColor.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
        }

        return ZStack {
            cardShape
                .fill(bg)
                .overlay(cardShape.stroke(border, lineWidth: 1))

            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(textColor.opacity(0.7))
                    Text("\(entry.todayMinutes)")
                        .font(.system(size: 60, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("分")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(textColor.opacity(0.7))
                    Spacer()
                    HStack {
                        Text("連続")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(textColor.opacity(0.7))
                        Spacer()
                        Text("\(entry.streak)日")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accentColor)
                    }
                }
                .padding(14)
            } else {
                HStack(spacing: 12) {
                    statPill(title: "今日", value: "\(entry.todayMinutes)", unit: "分")
                    statPill(title: "連続", value: "\(entry.streak)", unit: "日")
                }
                .padding(14)
            }
        }
    }
}

struct BlackFocusRingWidget: Widget {
    let kind: String = "BlackFocusRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BlackFocusRingWidgetEntryView(entry: entry)
                .widgetContainerBackground(AnyShapeStyle(.fill.tertiary))
        }
        .configurationDisplayName("ブラックリング")
        .description("進捗リングと学習時間を黒いタイルで表示します")
        .contentMarginsDisabled()
        #if os(iOS)
            .supportedFamilies([.systemSmall, .systemMedium])
        #else
            .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

private struct BlackFocusRingWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var themeSnapshot: WidgetThemeSnapshot? {
        WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
    }

    private var accentColor: Color {
        themeSnapshot?.resolvedAccent(for: resolvedScheme) ?? widgetAccent
    }

    private var textColor: Color {
        themeSnapshot?.resolvedText(for: resolvedScheme)
            ?? (resolvedScheme == .dark ? .white : .black)
    }

    private var surfaceColor: Color {
        themeSnapshot?.resolvedSurface(for: resolvedScheme)
            ?? (resolvedScheme == .dark ? Color.black : Color.white)
    }

    private var resolvedScheme: ColorScheme {
        themeSnapshot?.resolvedScheme(for: colorScheme) ?? colorScheme
    }

    private var ringProgress: Double {
        let clamped = min(max(Double(entry.todayMinutes) / 60.0, 0), 1)
        return clamped
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let bg = resolvedScheme == .dark
            ? Color.black.opacity(0.9)
            : (themeSnapshot?.resolvedBackground(for: resolvedScheme) ?? Color.white)
        let border = accentColor.opacity(0.20)

        func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
            ZStack {
                Circle()
                    .stroke(surfaceColor.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }

        return ZStack {
            cardShape
                .fill(bg)
                .overlay(cardShape.stroke(border, lineWidth: 1))

            if family == .systemSmall {
                VStack(spacing: 10) {
                    ZStack {
                        ring(size: 118, lineWidth: 10)
                            .frame(width: 118, height: 118)
                        VStack(spacing: 2) {
                            Text("\(entry.todayMinutes)")
                                .font(.system(size: 42, weight: .black, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(textColor)
                            Text("分")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(textColor.opacity(0.7))
                        }
                    }

                    HStack {
                        Text("連続")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(textColor.opacity(0.7))
                        Spacer()
                        Text("\(entry.streak)日")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accentColor)
                    }
                }
                .padding(14)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        ring(size: 120, lineWidth: 10)
                            .frame(width: 120, height: 120)
                        VStack(spacing: 2) {
                            Text("\(entry.todayMinutes)")
                                .font(.system(size: 44, weight: .black, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(textColor)
                            Text("分")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(textColor.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日の学習")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(textColor.opacity(0.7))
                        Text(entry.date, style: .time)
                            .font(.system(size: 34, weight: .black, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text("連続 \(entry.streak)日")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accentColor.opacity(0.16)))
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }
}

 #if canImport(AppIntents) && swift(>=6.0) && os(iOS)
@available(iOS 18.0, *)
struct FrontCameraControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "FrontCameraControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlFrontCameraURL)) {
                Label("ミラー", systemImage: "camera.viewfinder")
            }
        }
        .displayName("ミラー")
        .description("ロック画面からミラーを起動します")
    }
}

@available(iOS 18.0, *)
struct ScanControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "ScanControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlScanURL)) {
                Label("スキャン", systemImage: "doc.viewfinder")
            }
        }
        .displayName("スキャン")
        .description("ロック画面からスキャンを起動します")
    }
}

@available(iOS 18.0, *)
struct StudyTabControlWidget: ControlWidget {
    var body: some ControlConfiguration {
        StaticControlConfiguration(kind: "StudyTabControl") {
            ControlWidgetButton(intent: OpenURLIntent(url: controlStudyTabURL)) {
                Label("学習", systemImage: "book.fill")
            }
        }
        .displayName("学習")
        .description("学習タブを開きます")
    }
}
#endif

private struct WidgetThemeSnapshot {
    let primaryLight: Color
    let primaryDark: Color
    let accentLight: Color
    let accentDark: Color
    let surfaceLight: Color
    let surfaceDark: Color
    let backgroundLight: Color
    let backgroundDark: Color
    let textLight: Color
    let textDark: Color
    let schemeOverride: Int

    static func load(defaults: UserDefaults?) -> WidgetThemeSnapshot? {
        guard let defaults else { return nil }
        guard let primaryLight = defaults.string(forKey: widgetThemePrimaryLightKey),
            let primaryDark = defaults.string(forKey: widgetThemePrimaryDarkKey),
            let accentLight = defaults.string(forKey: widgetThemeAccentLightKey),
            let accentDark = defaults.string(forKey: widgetThemeAccentDarkKey),
            let surfaceLight = defaults.string(forKey: widgetThemeSurfaceLightKey),
            let surfaceDark = defaults.string(forKey: widgetThemeSurfaceDarkKey),
            let backgroundLight = defaults.string(forKey: widgetThemeBackgroundLightKey),
            let backgroundDark = defaults.string(forKey: widgetThemeBackgroundDarkKey),
            let textLight = defaults.string(forKey: widgetThemeTextLightKey),
            let textDark = defaults.string(forKey: widgetThemeTextDarkKey)
        else { return nil }

        return WidgetThemeSnapshot(
            primaryLight: Color(hex: primaryLight),
            primaryDark: Color(hex: primaryDark),
            accentLight: Color(hex: accentLight),
            accentDark: Color(hex: accentDark),
            surfaceLight: Color(hex: surfaceLight),
            surfaceDark: Color(hex: surfaceDark),
            backgroundLight: Color(hex: backgroundLight),
            backgroundDark: Color(hex: backgroundDark),
            textLight: Color(hex: textLight),
            textDark: Color(hex: textDark),
            schemeOverride: defaults.integer(forKey: widgetThemeSchemeOverrideKey)
        )
    }

    func resolvedScheme(for scheme: ColorScheme) -> ColorScheme {
        switch schemeOverride {
        case 1:
            return .light
        case 2:
            return .dark
        default:
            return scheme
        }
    }

    func resolvedPrimary(for scheme: ColorScheme) -> Color {
        resolvedScheme(for: scheme) == .dark ? primaryDark : primaryLight
    }

    func resolvedAccent(for scheme: ColorScheme) -> Color {
        resolvedScheme(for: scheme) == .dark ? accentDark : accentLight
    }

    func resolvedSurface(for scheme: ColorScheme) -> Color {
        resolvedScheme(for: scheme) == .dark ? surfaceDark : surfaceLight
    }

    func resolvedBackground(for scheme: ColorScheme) -> Color {
        resolvedScheme(for: scheme) == .dark ? backgroundDark : backgroundLight
    }

    func resolvedText(for scheme: ColorScheme) -> Color {
        resolvedScheme(for: scheme) == .dark ? textDark : textLight
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

private struct FocusBadge: View {
    let size: CGFloat
    let fontSize: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.08))
            Circle()
                .stroke(accent.opacity(0.45), lineWidth: 1)
            Text("學")
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
    }
}

private struct FocusRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            accent.opacity(0.5),
                            accent,
                            accent.opacity(0.35)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct StudyEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayMinutes: Int
    let mistakes: [String]
    let todos: [String]
    let calendarDays: [WidgetCalendarDay]
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
            calendarDays: [],
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

        if let data = defaults?.data(forKey: learningStatsKey),
            let decoded = try? JSONDecoder().decode(WidgetStoredStats.self, from: data)
        {
            let todos = loadTodos(defaults: defaults, settings: settings)
            let calendarDays = settings.showCalendar
                ? calendarDays(for: date, history: decoded.dailyHistory)
                : []
            return StudyEntry(
                date: date,
                streak: decoded.streak,
                todayMinutes: decoded.todayMinutes,
                mistakes: settings.showMistakes ? mistakes : [],
                todos: settings.showTodo ? todos : [],
                calendarDays: calendarDays,
                settings: settings
            )
        }

        let todos = loadTodos(defaults: defaults, settings: settings)
        let calendarDays = settings.showCalendar ? calendarDays(for: date, history: [:]) : []
        return StudyEntry(
            date: date,
            streak: 0,
            todayMinutes: 0,
            mistakes: settings.showMistakes ? mistakes : [],
            todos: settings.showTodo ? todos : [],
            calendarDays: calendarDays,
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

    private func calendarDays(for date: Date, history: [String: WidgetDailyEntry])
        -> [WidgetCalendarDay]
    {
        let calendar = Calendar.current
        let days = (0..<21).compactMap { offset -> WidgetCalendarDay? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let entry = history[dateKey(day)]
            let level = activityLevel(for: entry)
            return WidgetCalendarDay(
                date: day,
                level: level,
                isToday: calendar.isDateInToday(day)
            )
        }
        return Array(days.reversed())
    }

    private func activityLevel(for entry: WidgetDailyEntry?) -> Int {
        let minutes = entry?.minutes ?? 0
        let words = entry?.words ?? 0
        if minutes >= 60 || words >= 80 { return 3 }
        if minutes >= 30 || words >= 40 { return 2 }
        if minutes > 0 || words > 0 { return 1 }
        return 0
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct StudyWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var themeSnapshot: WidgetThemeSnapshot? {
        WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
    }

    private var accentColor: Color {
        themeSnapshot?.resolvedAccent(for: colorScheme) ?? widgetAccent
    }

    private var surfaceColor: Color {
        themeSnapshot?.resolvedSurface(for: colorScheme) ?? Color.secondary.opacity(0.2)
    }

    private var textColor: Color {
        themeSnapshot?.resolvedText(for: colorScheme)
            ?? (colorScheme == .dark ? .white : .black)
    }

    private var secondaryText: Color {
        textColor.opacity(0.62)
    }

    private var widgetBackground: Color {
        switch entry.settings.style {
        case "dark":
            return (themeSnapshot?.backgroundDark ?? Color.black).opacity(0.85)
        case "accent":
            return (themeSnapshot?.resolvedAccent(for: colorScheme) ?? widgetAccent).opacity(0.22)
        default:
            return themeSnapshot?.resolvedBackground(for: colorScheme)
                ?? (colorScheme == .dark ? Color.black : Color.white)
        }
    }

    @ViewBuilder
    var body: some View {
        let bg: AnyShapeStyle = isAccessoryFamily
            ? AnyShapeStyle(.fill.tertiary)
            : AnyShapeStyle(widgetBackground)

        content
            .widgetContainerBackground(bg, fallback: widgetBackground)
    }

    private var content: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            case .systemSmall:
                smallWidget
            #if os(iOS)
            case .accessoryRectangular:
                accessoryRectangular
            case .accessoryInline:
                accessoryInline
            #endif
            default:
                smallWidget
            }
        }
    }

    private var isAccessoryFamily: Bool {
        #if os(iOS)
        return family == .accessoryRectangular || family == .accessoryInline
        #else
        return false
        #endif
    }

    private var header: some View {
        HStack(spacing: 6) {
            FocusBadge(size: 22, fontSize: 11, accent: accentColor)
            Text("集中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
            Spacer()
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if entry.settings.showTodayMinutes {
                metricBlock(title: "今日", value: entry.todayMinutes, unit: "分")
            }

            if entry.settings.showStreak {
                Text("連続 \(entry.streak)日")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textColor)
            }

            if entry.settings.showCalendar {
                calendarSection
            } else {
                if let m = entry.mistakes.first {
                    Text(m)
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }

                if entry.settings.showTodo, let t = entry.todos.first {
                    Text(t)
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
            }

            timerLink

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(kanjiWatermark(size: 110, opacity: 0.08), alignment: .bottomTrailing)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    header
                    if entry.settings.showTodayMinutes {
                        metricBlock(title: "今日", value: entry.todayMinutes, unit: "分")
                    }
                }
                Spacer()
                if entry.settings.showStreak {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("連続")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                        Text("\(entry.streak)日")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(textColor)
                    }
                }
            }

            if entry.settings.showCalendar {
                calendarSection
            } else if !entry.mistakes.isEmpty || !entry.todos.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.mistakes.prefix(2), id: \.self) { m in
                        Text(m)
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }

                    ForEach(entry.todos.prefix(entry.settings.todoCount), id: \.self) { t in
                        Text("• \(t)")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            timerLink
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(kanjiWatermark(size: 150, opacity: 0.06), alignment: .bottomTrailing)
    }

    #if os(iOS)
    private var accessoryRectangular: some View {
        HStack(spacing: 6) {
            FocusBadge(size: 22, fontSize: 11, accent: accentColor)
            VStack(alignment: .leading, spacing: 2) {
                if entry.settings.showStreak {
                    Text("連続 \(entry.streak)日")
                        .font(.headline)
                }
                if let m = entry.mistakes.first {
                    Text(m)
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                } else if entry.settings.showTodayMinutes {
                    Text("今日 \(entry.todayMinutes)分")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private var accessoryInline: some View {
        HStack(spacing: 6) {
            Text("學")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accentColor)
            if entry.settings.showStreak {
                Text("\(entry.streak)日")
            } else if entry.settings.showTodayMinutes {
                Text("\(entry.todayMinutes)分")
            }
        }
        .font(.caption2)
        .foregroundStyle(textColor)
        .lineLimit(1)
    }
    #endif

    private func metricBlock(title: String, value: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var calendarSection: some View {
        let days = calendarDays
        let cellSize: CGFloat = family == .systemMedium ? 11 : 10
        let spacing: CGFloat = family == .systemMedium ? 3 : 3
        return VStack(alignment: .leading, spacing: 4) {
            if family == .systemMedium {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                    Text("カレンダー")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7),
                spacing: spacing
            ) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(calendarColor(level: day.level))
                        .frame(width: cellSize, height: cellSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(day.isToday ? accentColor.opacity(0.7) : .clear, lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calendarDays: [WidgetCalendarDay] {
        let count = family == .systemMedium ? 21 : 7
        if entry.calendarDays.count >= count {
            return Array(entry.calendarDays.suffix(count))
        }
        return entry.calendarDays
    }

    private func calendarColor(level: Int) -> Color {
        switch level {
        case 1:
            return accentColor.opacity(0.18)
        case 2:
            return accentColor.opacity(0.4)
        case 3:
            return accentColor.opacity(0.72)
        default:
            return surfaceColor.opacity(0.2)
        }
    }

    private var timerLink: some View {
        Group {
            if family == .systemSmall || family == .systemMedium {
                if let url = timerURL(minutes: entry.settings.timerMinutes) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("タイマー開始")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accentColor.opacity(0.16)))
                    }
                }
            }
        }
    }

    private func kanjiWatermark(size: CGFloat, opacity: Double) -> some View {
        Text("學")
            .font(.system(size: size, weight: .bold, design: .serif))
            .foregroundStyle(accentColor.opacity(opacity))
            .offset(x: 14, y: 18)
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
            StudyWidgetEntryView(entry: entry)
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
        let snapshot = WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
        switch style {
        case "dark":
            return (snapshot?.backgroundDark ?? Color.black).opacity(0.8)
        case "accent":
            return (snapshot?.accentLight ?? widgetAccent).opacity(0.22)
        default:
            return Color.clear
        }
    }
}

@main
struct ANKI_HUB_iOS_WidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyWidget()
        BlackClockWidget()
        BlackStatsWidget()
        BlackFocusRingWidget()
        #if canImport(ActivityKit) && os(iOS)
            if #available(iOS 16.1, *) {
                StudyLiveActivity()
            }
        #endif
        #if canImport(AppIntents) && swift(>=6.0) && os(iOS)
            if #available(iOS 18.0, *) {
                TimerStartControlWidget()
                FrontCameraControlWidget()
                ScanControlWidget()
                StudyTabControlWidget()
                SessionStartControlWidget()
                SessionStopControlWidget()
                SessionPinControlWidget()
            }
        #endif
    }
}

#if canImport(ActivityKit) && os(iOS)
    #if canImport(AppIntents)
        struct FocusTimerTogglePauseIntent: AppIntent {
            static var title: LocalizedStringResource = "Toggle Pause"
            static var description = IntentDescription("Pause/Resume focus timer")

            func perform() async throws -> some IntentResult {
                guard let activity = Activity<FocusTimerAttributes>.activities.first else {
                    return .result()
                }

                // App groupへ操作リクエストを書き込む（アプリ側が起動/復帰時に同期）
                if let defaults = UserDefaults(suiteName: appGroupId) {
                    let req = FocusTimerControlRequest(action: .togglePause)
                    if let data = try? JSONEncoder().encode(req) {
                        defaults.set(data, forKey: "anki_hub_focus_timer_control_v1")
                    }
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

                if let defaults = UserDefaults(suiteName: appGroupId) {
                    let req = FocusTimerControlRequest(action: .stop)
                    if let data = try? JSONEncoder().encode(req) {
                        defaults.set(data, forKey: "anki_hub_focus_timer_control_v1")
                    }
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

        struct FocusTimerOpenFrontCameraIntent: AppIntent {
            static var title: LocalizedStringResource = "Open Front Camera"
            static var description = IntentDescription("Open front camera")
            static var openAppWhenRun: Bool = true

            func perform() async throws -> some IntentResult {
                if let defaults = UserDefaults(suiteName: appGroupId) {
                    defaults.set(Date().timeIntervalSince1970, forKey: frontCameraStartRequestKey)
                }
                return .result()
            }
        }
    #endif

    @available(iOS 16.1, *)
    struct StudyLiveActivity: Widget {
        @Environment(\.colorScheme) private var colorScheme

        private var themeSnapshot: WidgetThemeSnapshot? {
            WidgetThemeSnapshot.load(defaults: UserDefaults(suiteName: appGroupId))
        }

        private var accentColor: Color {
            themeSnapshot?.resolvedAccent(for: colorScheme) ?? widgetAccent
        }

        private var activityBackgroundColor: Color {
            // Lock screen Live Activity should always use dark semi-transparent background
            // to blend with the lock screen aesthetic (Apple HIG)
            return Color.black.opacity(0.75)
        }

        private var primaryTextColor: Color {
            // Always use white text on dark Live Activity background
            .white
        }

        var body: some WidgetConfiguration {
            ActivityConfiguration(for: FocusTimerAttributes.self) { context in
                let remaining = remainingSeconds(for: context)
                let progress = progressValue(remaining: remaining, total: context.state.totalSeconds)
                let statusText = context.state.isPaused ? "一時停止" : "集中"

                HStack(spacing: 12) {
                    // Left: Timer ring (compact)
                    ZStack {
                        FocusRing(progress: progress, size: 56, lineWidth: 5, accent: accentColor)
                        timerText(for: context, remaining: remaining)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(primaryTextColor)
                    }
                    .frame(width: 56, height: 56)
                    
                    // Center: Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.timerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(statusText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("合計 \(max(1, context.state.totalSeconds / 60))分")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer(minLength: 0)

                    #if canImport(AppIntents)
                        // Right: Control buttons (vertical for compact layout)
                        VStack(spacing: 6) {
                            Button(intent: FocusTimerTogglePauseIntent()) {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)

                            Button(intent: FocusTimerStopIntent()) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.white.opacity(0.3))

                            Button(intent: FocusTimerOpenFrontCameraIntent()) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .tint(accentColor.opacity(0.35))
                        }
                    #endif
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .activityBackgroundTint(activityBackgroundColor)
                .activitySystemActionForegroundColor(accentColor)

            } dynamicIsland: { context in
                let remaining = remainingSeconds(for: context)
                let progress = progressValue(remaining: remaining, total: context.state.totalSeconds)
                let statusText = context.state.isPaused ? "一時停止" : "集中"

                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.timerName)
                                .font(.caption)
                            Text(statusText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                    DynamicIslandExpandedRegion(.center) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                            FocusRing(progress: progress, size: 72, lineWidth: 6, accent: accentColor)
                            timerText(for: context, remaining: remaining)
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(primaryTextColor)
                        }
                        .frame(width: 72, height: 72)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("残り")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            timerText(for: context, remaining: remaining)
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding(.trailing, 4)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        #if canImport(AppIntents)
                            HStack(spacing: 10) {
                                Button(intent: FocusTimerTogglePauseIntent()) {
                                    Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accentColor)

                                Button(intent: FocusTimerStopIntent()) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.white.opacity(0.25))
                            }
                        #endif
                    }
                } compactLeading: {
                    FocusBadge(size: 18, fontSize: 9, accent: accentColor)
                } compactTrailing: {
                    timerText(for: context, remaining: remaining)
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(maxWidth: 46)
                } minimal: {
                    Text("學")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accentColor)
                }
            }
        }

        private func remainingSeconds(for context: ActivityViewContext<FocusTimerAttributes>) -> Int {
            if context.state.isPaused {
                return max(0, context.state.pausedRemainingSeconds ?? 0)
            }
            return max(0, Int(context.state.targetTime.timeIntervalSince(Date())))
        }

        private func progressValue(remaining: Int, total: Int) -> Double {
            guard total > 0 else { return 0 }
            return Double(max(0, total - remaining)) / Double(total)
        }

        private func timerText(for context: ActivityViewContext<FocusTimerAttributes>, remaining: Int) -> Text {
            if context.state.isPaused {
                return Text(timeString(from: remaining))
            }
            return Text(context.state.targetTime, style: .timer)
        }

        private func timeString(from seconds: Int) -> String {
            let minutes = seconds / 60
            let secs = seconds % 60
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
#endif
