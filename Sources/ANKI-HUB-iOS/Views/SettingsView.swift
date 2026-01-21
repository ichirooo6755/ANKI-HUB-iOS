import SwiftUI

#if os(iOS)
    import UIKit
#endif

#if canImport(WidgetKit)
    import WidgetKit
#endif

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var learningStats: LearningStats
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("anki_hub_target_date_timestamp_v2") private var targetDateTimestamp: Double = 0
    @AppStorage("anki_hub_target_start_timestamp_v1") private var targetStartTimestamp: Double = 0
    @AppStorage("anki_hub_target_study_minutes_v1") private var targetStudyMinutes: Int = 600
    @AppStorage("anki_hub_widget_subject_filter_v1") private var widgetSubjectFilter: String = ""
    @AppStorage("anki_hub_widget_show_streak_v1") private var widgetShowStreak: Bool = true
    @AppStorage("anki_hub_widget_show_today_minutes_v1") private var widgetShowTodayMinutes: Bool = true
    @AppStorage("anki_hub_widget_show_mistakes_v1") private var widgetShowMistakes: Bool = true
    @AppStorage("anki_hub_widget_mistake_count_v1") private var widgetMistakeCount: Int = 3
    @AppStorage("anki_hub_widget_show_todo_v1") private var widgetShowTodo: Bool = false
    @AppStorage("anki_hub_widget_todo_count_v1") private var widgetTodoCount: Int = 2
    @AppStorage("anki_hub_widget_show_calendar_v1") private var widgetShowCalendar: Bool = false
    @AppStorage("anki_hub_widget_style_v1") private var widgetStyle: String = "system"
    @AppStorage("anki_hub_widget_timer_minutes_v1") private var widgetTimerMinutes: Int = 25

    private let widgetAppGroupId = "group.com.ankihub.ios"

    private var targetDateBinding: Binding<Date> {
        Binding(
            get: {
                if targetDateTimestamp == 0 {
                    return Date().addingTimeInterval(7 * 24 * 3600)
                }
                return Date(timeIntervalSince1970: targetDateTimestamp)
            },
            set: { newValue in
                let previousTimestamp = targetDateTimestamp
                let newTimestamp = newValue.timeIntervalSince1970
                targetDateTimestamp = newTimestamp
                if previousTimestamp != newTimestamp {
                    targetStartTimestamp = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                }

                // Clear V1 to ensure V2 is used
                // UserDefaults.standard.removeObject(forKey: "anki_hub_retention_target_days_v1")

                SyncManager.shared.requestAutoSync()
            }
        )
    }

    private var targetStudyMinutesText: String {
        let hours = targetStudyMinutes / 60
        let minutes = targetStudyMinutes % 60
        if minutes == 0 {
            return "\(hours)時間"
        }
        if hours == 0 {
            return "\(minutes)分"
        }
        return "\(hours)時間\(minutes)分"
    }

    private func migrateRetentionSettings() {
        let keyV2 = "anki_hub_target_date_timestamp_v2"
        let keyV1 = "anki_hub_retention_target_days_v1"

        // If V2 is already set (non-zero), do nothing
        if UserDefaults.standard.double(forKey: keyV2) != 0 {
            return
        }

        // Load V1
        let days = UserDefaults.standard.integer(forKey: keyV1)
        let defaultDays = days == 0 ? 7 : days

        // Set V2
        let date = Calendar.current.date(byAdding: .day, value: defaultDays, to: Date()) ?? Date()
        targetDateTimestamp = date.timeIntervalSince1970
        if targetStartTimestamp == 0 {
            targetStartTimestamp = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        }
    }
    @AppStorage("anki_hub_kobun_inputmode_use_all_v1") private var kobunInputModeUseAll: Bool =
        false
    @AppStorage("anki_hub_timer_limit_seconds_v1") private var timerLimitSeconds: Int = 30
    @AppStorage("anki_hub_daily_study_reminder_enabled_v1") private var dailyStudyReminderEnabled:
        Bool = false
    @AppStorage("anki_hub_daily_study_reminder_times_v1") private var dailyStudyReminderTimesJson:
        String = ""
    @State private var syncStatus = ""
    @State private var inviteCode = ""
    @State private var showInviteSheet = false
    @State private var inviteError = ""

    private enum ActiveAlert: Identifiable {
        case notificationDenied
        case authError(String)

        var id: String {
            switch self {
            case .notificationDenied:
                return "notificationDenied"
            case .authError:
                return "authError"
            }
        }
    }

    

    @ViewBuilder
    private var statsSection: some View {
        let rowBg = themeManager.color(.surface, scheme: colorScheme)
        Section("学習統計") {
            HStack {
                SettingsIcon(
                    icon: "flame.fill",
                    color: .orange,
                    foregroundColor: .white
                )
                Text("連続学習日数")
                Spacer()
                Text("\(learningStats.streak) 日")
                    .foregroundStyle(themeManager.color(.accent, scheme: colorScheme))
            }
            .listRowBackground(rowBg)
            HStack {
                SettingsIcon(
                    icon: "clock.fill",
                    color: .blue,
                    foregroundColor: .white
                )
                Text("今日の学習")
                Spacer()
                Text("\(learningStats.todayMinutes) 分")
                    .foregroundStyle(themeManager.color(.primary, scheme: colorScheme))
            }
            .listRowBackground(rowBg)
            HStack {
                SettingsIcon(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    foregroundColor: .white
                )
                Text("覚えた単語")
                Spacer()
                Text("\(learningStats.masteredCount) 語")
                    .foregroundStyle(themeManager.color(.mastered, scheme: colorScheme))
            }
            .listRowBackground(rowBg)
        }
    }

    @State private var activeAlert: ActiveAlert?

    private var timerLimitBinding: Binding<Double> {
        Binding(
            get: { Double(timerLimitSeconds) },
            set: { newValue in
                timerLimitSeconds = newValue == 0 ? 0 : Int(newValue)
            }
        )
    }

    private func saveWidgetSubjectFilterToAppGroup() {
        UserDefaults(suiteName: widgetAppGroupId)?.set(
            widgetSubjectFilter,
            forKey: "anki_hub_widget_subject_filter_v1"
        )
    }

    private func saveWidgetSettingsToAppGroup() {
        let defaults = UserDefaults(suiteName: widgetAppGroupId)
        defaults?.set(widgetSubjectFilter, forKey: "anki_hub_widget_subject_filter_v1")
        defaults?.set(widgetShowStreak, forKey: "anki_hub_widget_show_streak_v1")
        defaults?.set(widgetShowTodayMinutes, forKey: "anki_hub_widget_show_today_minutes_v1")
        defaults?.set(widgetShowMistakes, forKey: "anki_hub_widget_show_mistakes_v1")
        defaults?.set(widgetMistakeCount, forKey: "anki_hub_widget_mistake_count_v1")
        defaults?.set(widgetShowTodo, forKey: "anki_hub_widget_show_todo_v1")
        defaults?.set(widgetTodoCount, forKey: "anki_hub_widget_todo_count_v1")
        defaults?.set(widgetShowCalendar, forKey: "anki_hub_widget_show_calendar_v1")
        defaults?.set(widgetStyle, forKey: "anki_hub_widget_style_v1")
        defaults?.set(widgetTimerMinutes, forKey: "anki_hub_widget_timer_minutes_v1")
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let user = authManager.currentUser {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(themeManager.color(.primary, scheme: colorScheme))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.email)
                            .font(.headline)
                        HStack {
                            if authManager.isInvited {
                                Label("プレミアム", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(
                                        themeManager.color(.mastered, scheme: colorScheme))
                            } else {
                                Text("無料プラン")
                                    .font(.caption)
                                    .foregroundStyle(themeManager.secondaryText)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)

                if !authManager.isInvited {
                    Button {
                        showInviteSheet = true
                    } label: {
                        HStack {
                            SettingsIcon(
                                icon: "ticket.fill",
                                color: .orange,
                                foregroundColor: .white
                            )
                            Text("招待コードを入力")
                        }
                    }
                }

                Button(role: .destructive) {
                    Task { await authManager.signOut() }
                } label: {
                    HStack {
                        SettingsIcon(
                            icon: "rectangle.portrait.and.arrow.right.fill",
                            color: .red,
                            foregroundColor: .white
                        )
                        Text("ログアウト")
                    }
                }
            } else {
                Button {
                    Task { await authManager.signInWithGoogle() }
                } label: {
                    HStack {
                        SettingsIcon(
                            icon: "person.badge.plus.fill",
                            color: .green,
                            foregroundColor: .white
                        )
                        Text("Googleでログイン")
                        Spacer()
                        if authManager.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(authManager.isLoading)
            }
        }
    }

    @ViewBuilder
    private var studySection: some View {
        Section("学習") {
            DatePicker("目標日", selection: targetDateBinding, displayedComponents: [.date])
                .environment(\.locale, Locale(identifier: "ja_JP"))

            Stepper(value: $targetStudyMinutes, in: 30...20000, step: 30) {
                HStack {
                    Text("目標時間")
                    Spacer()
                    Text(targetStudyMinutesText)
                        .foregroundStyle(themeManager.secondaryText)
                }
            }

            Toggle(isOn: $kobunInputModeUseAll) {
                Text("古文インプットモードを全単語で行う")
            }

            timerSettingRow
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
        let rowBg = themeManager.color(.surface, scheme: colorScheme)
        Section("学習リマインド") {
            NavigationLink {
                ReminderSettingsView(
                    enabled: $dailyStudyReminderEnabled,
                    reminderTimeItems: $reminderTimeItems,
                    loadReminderTimesIfNeeded: loadReminderTimesIfNeeded,
                    persistReminderTimes: persistReminderTimes,
                    applySetting: applyDailyReminderSetting
                )
            } label: {
                HStack {
                    SettingsIcon(
                        icon: "bell.badge.fill",
                        color: .red,
                        foregroundColor: .white
                    )
                    Text("学習リマインド設定")
                }
            }
        }
        .listRowBackground(rowBg)
    }

    @ViewBuilder
    private var widgetSection: some View {
        let rowBg = themeManager.color(.surface, scheme: colorScheme)
        Section("ウィジェット") {
            NavigationLink {
                WidgetSettingsView()
                    .environmentObject(themeManager)
            } label: {
                HStack {
                    SettingsIcon(
                        icon: "square.grid.2x2.fill",
                        color: .purple,
                        foregroundColor: .white
                    )
                    Text("ウィジェット設定")
                }
            }

            NavigationLink {
                LockScreenMirrorGuideView()
            } label: {
                HStack {
                    SettingsIcon(
                        icon: "camera.viewfinder",
                        color: themeManager.color(.primary, scheme: colorScheme),
                        foregroundColor: themeManager.onColor(
                            for: themeManager.color(.primary, scheme: colorScheme))
                    )
                    Text("ロック画面ミラー")
                }
            }
        }
        .listRowBackground(rowBg)
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("外観") {
            Picker("外観", selection: $themeManager.colorSchemeOverride) {
                Text("システム").tag(0)
                Text("ライト").tag(1)
                Text("ダーク").tag(2)
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $themeManager.useLiquidGlass) {
                Text("Liquid Glass（コンテナ背景）")
            }

            NavigationLink {
                ThemeSettingsView()
            } label: {
                Label {
                    Text("テーマ設定")
                } icon: {
                    SettingsIcon(
                        icon: "paintpalette.fill",
                        color: themeManager.color(.primary, scheme: colorScheme),
                        foregroundColor: themeManager.onColor(for: themeManager.color(.primary, scheme: colorScheme))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        if authManager.currentUser != nil && authManager.isInvited {
            Section("同期") {
                Button {
                    syncData()
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading) {
                                Text("クラウド同期")
                                if !syncStatus.isEmpty {
                                    Text(syncStatus)
                                        .font(.caption)
                                        .foregroundStyle(themeManager.secondaryText)
                                }
                            }
                        } icon: {
                            SettingsIcon(
                                icon: "icloud.fill",
                                color: themeManager.color(.primary, scheme: colorScheme),
                                foregroundColor: themeManager.onColor(for: themeManager.color(.primary, scheme: colorScheme))
                            )
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }
                .foregroundStyle(themeManager.primaryText)
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Section("情報") {
            HStack {
                SettingsIcon(
                    icon: "info.circle.fill",
                    color: .gray,
                    foregroundColor: .white
                )
                Text("バージョン")
                Spacer()
                Text("2.0.0")
                    .foregroundStyle(themeManager.secondaryText)
            }

            HStack {
                SettingsIcon(
                    icon: "hammer.fill",
                    color: .gray,
                    foregroundColor: .white
                )
                Text("ビルド")
                Spacer()
                Text("SwiftUI Native")
                    .foregroundStyle(themeManager.secondaryText)
            }

            HStack {
                SettingsIcon(
                    icon: "person.2.fill",
                    color: .gray,
                    foregroundColor: .white
                )
                Text("開発")
                Spacer()
                Text("ANKI-HUB Team")
                    .foregroundStyle(themeManager.secondaryText)
            }
        }
    }

    private typealias ReminderTime = NotificationScheduler.Time

    private struct ReminderTimeItem: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var hour: Int
        var minute: Int

        init(id: UUID = UUID(), hour: Int, minute: Int) {
            self.id = id
            self.hour = hour
            self.minute = minute
        }

        init(time: ReminderTime) {
            self.hour = time.hour
            self.minute = time.minute
        }

        var asTime: ReminderTime {
            ReminderTime(hour: hour, minute: minute)
        }
    }

    @State private var reminderTimeItems: [ReminderTimeItem] = []

    private func reminderDateBinding(for item: ReminderTimeItem) -> Binding<Date> {
        Binding(
            get: {
                let t = item
                var comps = DateComponents()
                comps.hour = t.hour
                comps.minute = t.minute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                guard let idx = reminderTimeItems.firstIndex(where: { $0.id == item.id }) else {
                    return
                }
                var t = reminderTimeItems[idx]
                t.hour = comps.hour ?? t.hour
                t.minute = comps.minute ?? t.minute
                reminderTimeItems[idx] = t
                persistReminderTimes()
                Task { await applyDailyReminderSetting(enabled: true) }
            }
        )
    }

    private func loadReminderTimesIfNeeded() {
        guard reminderTimeItems.isEmpty else { return }
        if let data = dailyStudyReminderTimesJson.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([ReminderTime].self, from: data)
        {
            reminderTimeItems = decoded.map { ReminderTimeItem(time: $0) }
        }

        if reminderTimeItems.isEmpty {
            // Migration from v1 (single time)
            let oldHourKey = "anki_hub_daily_study_reminder_hour_v1"
            let oldMinuteKey = "anki_hub_daily_study_reminder_minute_v1"
            if UserDefaults.standard.object(forKey: oldHourKey) != nil
                || UserDefaults.standard.object(forKey: oldMinuteKey) != nil
            {
                let h = UserDefaults.standard.integer(forKey: oldHourKey)
                let m = UserDefaults.standard.integer(forKey: oldMinuteKey)
                reminderTimeItems = [ReminderTimeItem(hour: h, minute: m)]
                persistReminderTimes()
                return
            }
        }
        if reminderTimeItems.isEmpty {
            reminderTimeItems = [ReminderTimeItem(hour: 20, minute: 0)]
            persistReminderTimes()
        }
    }

    private func persistReminderTimes() {
        let times = reminderTimeItems.map { $0.asTime }
        if let data = try? JSONEncoder().encode(times),
            let json = String(data: data, encoding: .utf8)
        {
            dailyStudyReminderTimesJson = json
        }
    }

    private var timerSettingRow: some View {
        let rowBg = themeManager.color(.surface, scheme: colorScheme)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タイマー時間")
                    .font(.headline)
                Spacer()
                Text(timerLimitSeconds == 0 ? "制限なし" : "\(timerLimitSeconds)秒")
                    .foregroundStyle(themeManager.secondaryText)
            }

            Slider(value: timerLimitBinding, in: 0...120, step: 5)
                .tint(themeManager.color(.primary, scheme: colorScheme))

            Text("0秒で制限なし")
                .font(.caption)
                .foregroundStyle(themeManager.secondaryText)
        }
        .padding(.vertical, 4)
        .listRowBackground(rowBg)
    }

    private func applyDailyReminderSetting(enabled: Bool) async {
        if enabled {
            let times = reminderTimeItems.map { $0.asTime }
            let ok = await NotificationScheduler.shared.scheduleDailyStudyReminders(
                times: times
            )
            if !ok {
                await MainActor.run {
                    dailyStudyReminderEnabled = false
                    activeAlert = .notificationDenied
                }
            }
        } else {
            await NotificationScheduler.shared.cancelDailyStudyReminders()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background

                List {
                    accountSection
                    statsSection
                    studySection
                    widgetSection
                    reminderSection
                    appearanceSection
                    syncSection
                    infoSection
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(themeManager.color(.surface, scheme: colorScheme))
                #if os(iOS)
                    .listStyle(.insetGrouped)
                #else
                    .listStyle(.inset)
                #endif
            }
            .navigationTitle("マイページ")
        }
        .applyAppTheme()
        .onAppear {
            #if os(iOS)
                UITableView.appearance().backgroundColor = .clear
            #endif
            loadReminderTimesIfNeeded()
            migrateRetentionSettings()
            saveWidgetSettingsToAppGroup()
        }
        .onChange(of: targetStudyMinutes) { _, _ in
            SyncManager.shared.requestAutoSync()
        }
        .onChange(of: kobunInputModeUseAll) { _, _ in
            SyncManager.shared.requestAutoSync()
        }
        .onChange(of: dailyStudyReminderEnabled) { _, newValue in
            Task {
                await applyDailyReminderSetting(enabled: newValue)
            }
        }
        .onChange(of: authManager.lastAuthErrorMessage) { _, newValue in
            if let msg = newValue {
                activeAlert = .authError(msg)
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .notificationDenied:
                return Alert(
                    title: Text("通知が許可されていません"),
                    message: Text("iPhoneの設定アプリから通知を許可してください"),
                    dismissButton: .default(Text("OK"))
                )
            case .authError(let msg):
                return Alert(
                    title: Text("ログインに失敗しました"),
                    message: Text(msg),
                    dismissButton: .default(
                        Text("OK"),
                        action: {
                            authManager.clearAuthError()
                        })
                )
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("招待コード", text: $inviteCode)
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                    } footer: {
                        if !inviteError.isEmpty {
                            Text(inviteError)
                                .foregroundStyle(themeManager.color(.weak, scheme: colorScheme))
                        }
                    }
                }
                .navigationTitle("招待コード")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showInviteSheet = false
                            inviteCode = ""
                            inviteError = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("確認") {
                            Task {
                                let success = await authManager.verifyInviteCode(inviteCode)
                                if success {
                                    showInviteSheet = false
                                    inviteCode = ""
                                    inviteError = ""
                                } else {
                                    inviteError = "無効なコードです"
                                }
                            }
                        }
                        .disabled(inviteCode.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func syncData() {
        syncStatus = "同期中..."
        Task {
            await SyncManager.shared.syncAllDebounced()
            await MainActor.run {
                syncStatus = "完了"
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                syncStatus = ""
            }
        }
    }

    private struct ReminderSettingsView: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme

        @Binding var enabled: Bool
        @Binding var reminderTimeItems: [ReminderTimeItem]

        let loadReminderTimesIfNeeded: () -> Void
        let persistReminderTimes: () -> Void
        let applySetting: (Bool) async -> Void

        var body: some View {
            let rowBg = themeManager.color(.surface, scheme: colorScheme)
            List {
                Section("学習リマインド") {
                    Toggle(isOn: $enabled) {
                        Text("学習リマインド（毎日）")
                    }

                    if enabled {
                        ForEach(reminderTimeItems) { item in
                            DatePicker(
                                item == reminderTimeItems.first ? "通知時刻" : "",
                                selection: reminderDateBinding(for: item),
                                displayedComponents: .hourAndMinute
                            )

                            if reminderTimeItems.count > 1 {
                                Button(role: .destructive) {
                                    reminderTimeItems.removeAll { $0.id == item.id }
                                    persistReminderTimes()
                                    Task { await applySetting(true) }
                                } label: {
                                    Text("この時刻を削除")
                                }
                            }
                        }

                        Button {
                            reminderTimeItems.append(ReminderTimeItem(hour: 20, minute: 0))
                            persistReminderTimes()
                            Task { await applySetting(true) }
                        } label: {
                            Text("通知時刻を追加")
                        }
                    }
                }
                .listRowBackground(rowBg)
            }
            .scrollContentBackground(.hidden)
            #if os(iOS)
                .listStyle(.insetGrouped)
            #else
                .listStyle(.inset)
            #endif
            .navigationTitle("学習リマインド")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .applyAppTheme()
            .onAppear {
                loadReminderTimesIfNeeded()
            }
            .onChange(of: enabled) { _, newValue in
                Task { await applySetting(newValue) }
            }
        }

        private func reminderDateBinding(for item: ReminderTimeItem) -> Binding<Date> {
            Binding(
                get: {
                    var comps = DateComponents()
                    comps.hour = item.hour
                    comps.minute = item.minute
                    return Calendar.current.date(from: comps) ?? Date()
                },
                set: { newValue in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    guard let idx = reminderTimeItems.firstIndex(where: { $0.id == item.id }) else {
                        return
                    }
                    var t = reminderTimeItems[idx]
                    t.hour = comps.hour ?? t.hour
                    t.minute = comps.minute ?? t.minute
                    reminderTimeItems[idx] = t
                    persistReminderTimes()
                    Task { await applySetting(true) }
                }
            )
        }
    }
}

struct WidgetSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("anki_hub_widget_subject_filter_v1") private var widgetSubjectFilter: String = ""
    @AppStorage("anki_hub_widget_show_streak_v1") private var widgetShowStreak: Bool = true
    @AppStorage("anki_hub_widget_show_today_minutes_v1") private var widgetShowTodayMinutes: Bool = true
    @AppStorage("anki_hub_widget_show_mistakes_v1") private var widgetShowMistakes: Bool = true
    @AppStorage("anki_hub_widget_mistake_count_v1") private var widgetMistakeCount: Int = 3
    @AppStorage("anki_hub_widget_show_todo_v1") private var widgetShowTodo: Bool = false
    @AppStorage("anki_hub_widget_todo_count_v1") private var widgetTodoCount: Int = 2
    @AppStorage("anki_hub_widget_show_calendar_v1") private var widgetShowCalendar: Bool = false
    @AppStorage("anki_hub_widget_style_v1") private var widgetStyle: String = "system"
    @AppStorage("anki_hub_widget_timer_minutes_v1") private var widgetTimerMinutes: Int = 25

    private let widgetAppGroupId = "group.com.ankihub.ios"

    var body: some View {
        let rowBg = themeManager.color(.surface, scheme: colorScheme)

        List {
            Section("ウィジェット") {
                Picker("教科", selection: $widgetSubjectFilter) {
                    Text("すべて").tag("")
                    Text("英語").tag(Subject.english.rawValue)
                    Text("古文").tag(Subject.kobun.rawValue)
                    Text("漢文").tag(Subject.kanbun.rawValue)
                    Text("政経").tag(Subject.seikei.rawValue)
                }

                Toggle(isOn: $widgetShowStreak) {
                    Text("連続学習日数")
                }

                Toggle(isOn: $widgetShowTodayMinutes) {
                    Text("今日の学習時間")
                }

                Toggle(isOn: $widgetShowMistakes) {
                    Text("間違えた単語")
                }

                Toggle(isOn: $widgetShowCalendar) {
                    Text("カレンダー")
                }

                Picker("間違えた単語の表示数", selection: $widgetMistakeCount) {
                    Text("1件").tag(1)
                    Text("2件").tag(2)
                    Text("3件").tag(3)
                }

                Toggle(isOn: $widgetShowTodo) {
                    Text("やることリスト")
                }

                Picker("やることリストの表示数", selection: $widgetTodoCount) {
                    Text("1件").tag(1)
                    Text("2件").tag(2)
                    Text("3件").tag(3)
                }

                Picker("見た目", selection: $widgetStyle) {
                    Text("システム").tag("system")
                    Text("ダーク").tag("dark")
                    Text("アクセント").tag("accent")
                }

                Stepper(
                    "タイマー（\(widgetTimerMinutes)分）",
                    value: $widgetTimerMinutes,
                    in: 1...180
                )
            }
            .listRowBackground(rowBg)
        }
        .scrollContentBackground(.hidden)
        #if os(iOS)
            .listStyle(.insetGrouped)
        #else
            .listStyle(.inset)
        #endif
        .navigationTitle("ウィジェット設定")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .applyAppTheme()
        .onAppear {
            saveWidgetSettingsToAppGroup()
        }
        .onChange(of: widgetSubjectFilter) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetShowStreak) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetShowTodayMinutes) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetShowMistakes) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetShowCalendar) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetMistakeCount) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetShowTodo) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetTodoCount) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetStyle) { _, _ in
            onWidgetSettingsChanged()
        }
        .onChange(of: widgetTimerMinutes) { _, _ in
            onWidgetSettingsChanged()
        }
    }

    private func onWidgetSettingsChanged() {
        saveWidgetSettingsToAppGroup()
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func saveWidgetSettingsToAppGroup() {
        let defaults = UserDefaults(suiteName: widgetAppGroupId)
        defaults?.set(widgetSubjectFilter, forKey: "anki_hub_widget_subject_filter_v1")
        defaults?.set(widgetShowStreak, forKey: "anki_hub_widget_show_streak_v1")
        defaults?.set(widgetShowTodayMinutes, forKey: "anki_hub_widget_show_today_minutes_v1")
        defaults?.set(widgetShowMistakes, forKey: "anki_hub_widget_show_mistakes_v1")
        defaults?.set(widgetMistakeCount, forKey: "anki_hub_widget_mistake_count_v1")
        defaults?.set(widgetShowTodo, forKey: "anki_hub_widget_show_todo_v1")
        defaults?.set(widgetTodoCount, forKey: "anki_hub_widget_todo_count_v1")
        defaults?.set(widgetShowCalendar, forKey: "anki_hub_widget_show_calendar_v1")
        defaults?.set(widgetStyle, forKey: "anki_hub_widget_style_v1")
        defaults?.set(widgetTimerMinutes, forKey: "anki_hub_widget_timer_minutes_v1")
    }
}

// Previews removed for SPM
