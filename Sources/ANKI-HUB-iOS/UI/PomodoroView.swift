import SwiftUI
import UserNotifications

#if canImport(ActivityKit)
    import ActivityKit
#endif

// MARK: - Timer & Stopwatch View
struct PomodoroView: View {
    @ObservedObject var theme = ThemeManager.shared

    let startRequest: PomodoroStartRequest?

    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    private struct PersistedTimerState: Codable {
        var isActive: Bool
        var startTime: Date?
        var endTime: Date?
        var totalTime: TimeInterval
        var timeRemaining: TimeInterval
        var isOvertime: Bool
        var overtimeSeconds: TimeInterval
        var selectedMode: String
    }

    private struct TimerStudyLog: Identifiable, Codable {
        var id: UUID = UUID()
        var startedAt: Date
        var endedAt: Date
        var mode: String
        var plannedSeconds: Int
        var overtimeSeconds: Int
        var studyContent: String
    }

    struct TimerHistoryEntry: Identifiable, Codable {
        let id: UUID
        let minutes: Int
        let createdAt: Date
        let mode: String

        init(id: UUID = UUID(), minutes: Int, createdAt: Date, mode: String) {
            self.id = id
            self.minutes = minutes
            self.createdAt = createdAt
            self.mode = mode
        }

        var displayText: String {
            return "\(minutes)分 - \(mode)"
        }
    }

    private let timerHistoryKey = "anki_hub_timer_history_v1"
    private let timerLogKey = "anki_hub_timer_study_logs_v1"
    private let timerEndNotificationId = "anki_hub_timer_end_v1"
    private let persistedTimerStateKey = "anki_hub_pomodoro_timer_state_v1"

    // Timer State
    @State private var timeRemaining: TimeInterval = 25 * 60
    @State private var totalTime: TimeInterval = 25 * 60
    @State private var isActive = false
    @State private var timer: Timer? = nil
    @State private var endTime: Date? = nil

    @State private var startTime: Date? = nil
    @State private var isOvertime = false
    @State private var overtimeSeconds: TimeInterval = 0

    // Timer History
    @State private var timerHistory: [TimerHistoryEntry] = []
    @State private var showHistory = false
    @State private var suppressHistoryOnNextStart = false

    // Edge manipulation
    @State private var isDragging = false
    @State private var dragStartAngle: Double = 0

    @State private var didApplyStartRequest = false

    @State private var suppressModeChangeUpdate = false

    @State private var lastPersistedAt: Date = .distantPast

    @State private var showStudyLogSheet = false
    @State private var studyContent = ""

    // Live Activity State
    @State private var activityID: String? = nil

    // Stopwatch State
    @State private var stopwatchTime: TimeInterval = 0
    @State private var stopwatchActive = false
    @State private var stopwatchTimer: Timer? = nil
    @State private var stopwatchLaps: [TimeInterval] = []
    @State private var stopwatchStartDate: Date? = nil
    @State private var stopwatchElapsedBeforeStart: TimeInterval = 0

    // Custom Timer Settings
    @AppStorage("anki_hub_timer_focus_minutes") private var focusMinutes: Int = 25
    @AppStorage("anki_hub_timer_short_break_minutes") private var shortBreakMinutes: Int = 5
    @AppStorage("anki_hub_timer_long_break_minutes") private var longBreakMinutes: Int = 15
    @AppStorage("anki_hub_timer_custom_minutes_v1") private var customMinutes: Int = 25

    // UI State
    @State private var selectedTab: TimerTab = .timer
    @State private var selectedMode: TimerMode = .focus
    @State private var showSettings = false

    init(startRequest: PomodoroStartRequest? = nil) {
        self.startRequest = startRequest
    }

    enum TimerTab: String, CaseIterable {
        case timer = "タイマー"
        case stopwatch = "ストップウォッチ"
    }

    enum TimerMode: String, CaseIterable {
        case focus = "集中"
        case shortBreak = "小休憩"
        case longBreak = "長休憩"
        case custom = "カスタム"

        var color: Color {
            switch self {
            case .focus:
                return ThemeManager.shared.currentPalette.color(
                    .primary, isDark: ThemeManager.shared.effectiveIsDark)
            case .shortBreak:
                return ThemeManager.shared.currentPalette.color(
                    .accent, isDark: ThemeManager.shared.effectiveIsDark)
            case .longBreak:
                return ThemeManager.shared.currentPalette.color(
                    .selection, isDark: ThemeManager.shared.effectiveIsDark)
            case .custom:
                return ThemeManager.shared.currentPalette.color(
                    .weak, isDark: ThemeManager.shared.effectiveIsDark)
            }
        }
    }

    private func durationFor(_ mode: TimerMode) -> TimeInterval {
        switch mode {
        case .focus: return TimeInterval(focusMinutes * 60)
        case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        case .custom: return TimeInterval(customMinutes * 60)
        }
    }

    var body: some View {
        #if os(iOS)
            // Show standby view when landscape and timer/stopwatch is active
            let isLandscape = verticalSizeClass == .compact
            let showStandby = isLandscape && (isActive || stopwatchActive)
        #else
            let showStandby = false
        #endif

        return ZStack {
            theme.background

            if showStandby {
                standbyTimerView
            } else {
                VStack(spacing: 24) {
                    // Tab Selector
                    Picker("", selection: $selectedTab) {
                        ForEach(TimerTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    if selectedTab == .timer {
                        timerView
                    } else {
                        stopwatchView
                    }
                }
            }
        }

        .sheet(isPresented: $showSettings) {
            timerSettingsSheet
        }
        .sheet(isPresented: $showStudyLogSheet) {
            timerStudyLogSheet
        }
        .onAppear {
            setupNotifications()
            loadTimerHistory()
            if !restoreTimerStateIfNeeded() {
                updateTimerDuration()
            }
            applyStartRequestIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active {
                persistTimerState(force: true)
            }
        }
        .onChange(of: selectedMode) { _, _ in
            if suppressModeChangeUpdate {
                suppressModeChangeUpdate = false
                return
            }
            if !isActive {
                updateTimerDuration()
            }
        }
        #if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                if isActive, let end = endTime {
                    let remaining = end.timeIntervalSince(Date())
                    if remaining <= 0 {
                        timeRemaining = 0
                        isOvertime = true
                        overtimeSeconds = abs(remaining)
                        startTickingTimer()
                    } else {
                        timeRemaining = remaining
                    }
                }
            }
        #endif
        .applyAppTheme()
    }

    // MARK: - Timer History Management

    private func loadTimerHistory() {
        if let data = UserDefaults.standard.data(forKey: timerHistoryKey),
            let history = try? JSONDecoder().decode([TimerHistoryEntry].self, from: data)
        {
            timerHistory = history.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func saveTimerHistory() {
        if let data = try? JSONEncoder().encode(timerHistory) {
            UserDefaults.standard.set(data, forKey: timerHistoryKey)
        }
    }

    private func addToHistory(minutes: Int, mode: String) {
        let entry = TimerHistoryEntry(minutes: minutes, createdAt: Date(), mode: mode)
        timerHistory.insert(entry, at: 0)

        // Keep only last 20 entries
        if timerHistory.count > 20 {
            timerHistory = Array(timerHistory.prefix(20))
        }

        saveTimerHistory()
    }

    private func applyHistoryEntry(_ entry: TimerHistoryEntry) {
        // 履歴をそのまま復元したいので、updateTimerDuration()で上書きしない
        suppressModeChangeUpdate = true
        selectedMode = TimerMode(rawValue: entry.mode) ?? .focus
        totalTime = TimeInterval(entry.minutes * 60)
        timeRemaining = totalTime
        endTime = nil
        startTime = nil
        isOvertime = false
        overtimeSeconds = 0
    }

    // MARK: - Edge Manipulation

    private func handleTimeDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: 150, y: 150)  // Center of the 300x300 frame
        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
        let angle = atan2(vector.dy, vector.dx) * 180 / .pi

        if !isDragging {
            isDragging = true
            dragStartAngle = angle
        }

        let angleDiff = angle - dragStartAngle

        // Convert angle difference to time adjustment (1 degree = 1 minute)
        let minutesDiff = Int(angleDiff.rounded())

        // Clamp between 1 and 120 minutes
        let newMinutes = max(1, min(120, Int(totalTime / 60) + minutesDiff))

        if newMinutes != Int(totalTime / 60) {
            totalTime = TimeInterval(newMinutes * 60)
            timeRemaining = totalTime
            dragStartAngle = angle
        }
    }

    // MARK: - Timer View

    private var timerView: some View {
        VStack(spacing: 30) {
            // Mode Selector
            HStack(spacing: 12) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedMode == mode
                                    ? mode.color.opacity(0.2) : Color.gray.opacity(0.1)
                            )
                            .foregroundStyle(
                                selectedMode == mode ? mode.color : theme.secondaryText
                            )
                            .cornerRadius(8)
                    }
                }
            }

            // Clock Dial
            ZStack {
                // Tick marks
                TickMarksView()

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining / totalTime))
                    .stroke(selectedMode.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timeRemaining)
                    .padding(20)

                // Time Display
                VStack {
                    Text(
                        isOvertime
                            ? "+\(timeString(from: overtimeSeconds))"
                            : timeString(from: timeRemaining)
                    )
                    .font(.system(size: 60, weight: .thin, design: .monospaced))
                    .contentTransition(.numericText())

                    if isActive, let end = endTime {
                        Text("終了: \(endTimeString(end))")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 4)
                    }

                    if isOvertime {
                        Text("オーバータイム")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(width: 300, height: 300)
            .liquidGlassCircle()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isActive {
                            handleTimeDrag(value)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Controls
            HStack(spacing: 40) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 60, height: 60)
                        .liquidGlassCircle()
                }

                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 60, height: 60)
                        .liquidGlassCircle()
                }

                Button {
                    toggleTimer()
                } label: {
                    let bg = selectedMode.color
                    Image(systemName: isActive ? "pause.fill" : "stopwatch.fill")
                        .font(.title)
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(width: 80, height: 80)
                        .background(bg)
                        .clipShape(Circle())
                        .shadow(color: selectedMode.color.opacity(0.4), radius: 10, x: 0, y: 5)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 60, height: 60)
                        .liquidGlassCircle()
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showHistory) {
            TimerHistoryView(history: timerHistory) { entry in
                applyHistoryEntry(entry)
                showHistory = false
                if !isActive {
                    suppressHistoryOnNextStart = true
                    toggleTimer()
                }
            }
        }
    }

    // MARK: - Stopwatch View

    private var stopwatchView: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        return VStack(spacing: 30) {
            Spacer()

            // Stopwatch Display
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.3), lineWidth: 20)
                    .padding(20)

                if stopwatchActive {
                    Circle()
                        .trim(
                            from: 0,
                            to: CGFloat((stopwatchTime.truncatingRemainder(dividingBy: 60)) / 60)
                        )
                        .stroke(accent, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(20)
                }

                VStack {
                    Text(stopwatchString(from: stopwatchTime))
                        .font(.system(size: 50, weight: .thin, design: .monospaced))
                        .contentTransition(.numericText())

                    Text("ストップウォッチ")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .frame(width: 300, height: 300)
            .liquidGlassCircle()

            // Controls
            HStack(spacing: 40) {
                Button {
                    resetStopwatch()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 60, height: 60)
                        .liquidGlassCircle()
                }

                Button {
                    toggleStopwatch()
                } label: {
                    let bg = accent
                    Image(systemName: stopwatchActive ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(width: 80, height: 80)
                        .background(bg)
                        .clipShape(Circle())
                        .shadow(color: bg.opacity(0.4), radius: 10, x: 0, y: 5)
                }

                // Lap button placeholder
                Button {
                    addStopwatchLap()
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 60, height: 60)
                        .liquidGlassCircle()
                }
            }

            if !stopwatchLaps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ラップ")
                            .font(.headline)
                        Spacer()
                        Button("クリア", role: .destructive) {
                            stopwatchLaps.removeAll()
                        }
                        .font(.caption)
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(stopwatchLaps.enumerated()), id: \.offset) { idx, t in
                                HStack {
                                    Text("\(idx + 1)")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                        .frame(width: 28, alignment: .leading)
                                    Spacer()
                                    Text(stopwatchString(from: t))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(theme.primaryText)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .liquidGlass(cornerRadius: 14)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 220)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Settings Sheet

    private var timerSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("集中時間") {
                    Stepper("\(focusMinutes)分", value: $focusMinutes, in: 1...120)
                }

                Section("小休憩") {
                    Stepper("\(shortBreakMinutes)分", value: $shortBreakMinutes, in: 1...30)
                }

                Section("長休憩") {
                    Stepper("\(longBreakMinutes)分", value: $longBreakMinutes, in: 1...60)
                }

                Section("カスタムタイマー") {
                    Stepper(
                        "\(customMinutes)分",
                        value: $customMinutes,
                        in: 1...180
                    )
                }
            }
            .navigationTitle("タイマー設定")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        showSettings = false
                        if !isActive {
                            updateTimerDuration()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func updateTimerDuration() {
        totalTime = durationFor(selectedMode)
        timeRemaining = totalTime
    }

    private func applyStartRequestIfNeeded() {
        guard !didApplyStartRequest else { return }
        didApplyStartRequest = true

        guard let req = startRequest, req.open else { return }
        guard !isActive else { return }

        selectedTab = .timer

        suppressModeChangeUpdate = true
        selectedMode = .custom

        let safeMinutes = max(1, min(180, req.minutes))
        customMinutes = safeMinutes
        totalTime = TimeInterval(safeMinutes * 60)
        timeRemaining = totalTime
        toggleTimer()
    }

    private func endTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func stopwatchString(from time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private func toggleTimer() {
        isActive.toggle()

        if isActive {
            if startTime == nil {
                startTime = Date()
                if suppressHistoryOnNextStart {
                    suppressHistoryOnNextStart = false
                } else {
                    addToHistory(minutes: Int(totalTime / 60), mode: selectedMode.rawValue)
                }
            }
            isOvertime = false
            overtimeSeconds = 0
            let targetDate = Date().addingTimeInterval(timeRemaining)
            endTime = targetDate

            scheduleTimerEndNotification(targetDate: targetDate)

            // Start Live Activity
            startActivity(targetDate: targetDate)

            startTickingTimer()
            persistTimerState(force: true)
        } else {
            stopTimer(userInitiated: true)
        }
    }

    private func startTickingTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isOvertime {
                overtimeSeconds += 1
                persistTimerState(force: false)
                return
            }

            if timeRemaining > 0 {
                timeRemaining -= 1
                persistTimerState(force: false)
                return
            }

            // Reached 0
            timeRemaining = 0
            isOvertime = true
            overtimeSeconds = 0
            notifyTimerFinishedIfNeeded()
            persistTimerState(force: true)
        }
    }

    private func notifyTimerFinishedIfNeeded() {
        #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        #endif
    }

    private func stopTimer(userInitiated: Bool) {
        isActive = false
        timer?.invalidate()
        timer = nil

        cancelTimerEndNotification()

        endActivity()

        persistTimerState(force: true)

        if userInitiated {
            if let startedAt = startTime {
                let elapsedSeconds = max(0.0, Date().timeIntervalSince(startedAt))
                let shouldRecordMode = (selectedMode == .focus || selectedMode == .custom)
                if shouldRecordMode, elapsedSeconds >= 60 {
                    showStudyLogSheet = true
                    return
                }
            }

            if isOvertime || timeRemaining == 0 {
                showStudyLogSheet = true
            }
        }
    }

    private func resetTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
        updateTimerDuration()
        endTime = nil
        startTime = nil
        isOvertime = false
        overtimeSeconds = 0
        studyContent = ""
        cancelTimerEndNotification()
        endActivity()

        clearPersistedTimerState()
    }

    private var timerStudyLogSheet: some View {
        NavigationStack {
            Form {
                Section("学習内容") {
                    TextField("何を勉強した？", text: $studyContent)
                }

                Section("ログ") {
                    if let startedAt = startTime {
                        let formatter = DateFormatter()
                        let _ = formatter.dateStyle = .none
                        let _ = formatter.timeStyle = .short
                        LabeledContent("開始", value: formatter.string(from: startedAt))
                    }
                    LabeledContent("モード", value: selectedMode.rawValue)
                    LabeledContent("予定", value: timeString(from: totalTime))
                    if isOvertime {
                        LabeledContent("超過", value: timeString(from: overtimeSeconds))
                    }
                }
            }
            .navigationTitle("学習を記録")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showStudyLogSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let endedAt = Date()
                        saveStudyLogIfPossible(endedAt: endedAt)
                        showStudyLogSheet = false
                        resetTimer()
                    }
                }
            }
        }
    }

    private func toggleStopwatch() {
        stopwatchActive.toggle()

        if stopwatchActive {
            stopwatchStartDate = Date()
            stopwatchTimer?.invalidate()
            stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                guard let started = stopwatchStartDate else { return }
                stopwatchTime = stopwatchElapsedBeforeStart + Date().timeIntervalSince(started)
            }
        } else {
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil
            if let started = stopwatchStartDate {
                stopwatchElapsedBeforeStart += Date().timeIntervalSince(started)
            }
            stopwatchStartDate = nil
        }
    }

    private func resetStopwatch() {
        stopwatchActive = false
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        stopwatchTime = 0
        stopwatchElapsedBeforeStart = 0
        stopwatchStartDate = nil
        stopwatchLaps.removeAll()
    }

    private func addStopwatchLap() {
        let current: TimeInterval = {
            if stopwatchActive, let started = stopwatchStartDate {
                return stopwatchElapsedBeforeStart + Date().timeIntervalSince(started)
            }
            return stopwatchElapsedBeforeStart
        }()

        guard current > 0 else { return }
        stopwatchLaps.insert(current, at: 0)
        if stopwatchLaps.count > 50 {
            stopwatchLaps = Array(stopwatchLaps.prefix(50))
        }
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }

    private func scheduleTimerEndNotification(targetDate: Date) {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [timerEndNotificationId])

        let content = UNMutableNotificationContent()
        content.title = "タイマー終了"
        content.body = "\(selectedMode.rawValue)が終了しました"
        content.sound = .default

        let interval = max(1, targetDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: timerEndNotificationId,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func cancelTimerEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            timerEndNotificationId
        ])
    }

    private func saveStudyLogIfPossible(endedAt: Date) {
        guard let startedAt = startTime else { return }

        let log = TimerStudyLog(
            startedAt: startedAt,
            endedAt: endedAt,
            mode: selectedMode.rawValue,
            plannedSeconds: Int(totalTime),
            overtimeSeconds: isOvertime ? Int(overtimeSeconds) : 0,
            studyContent: studyContent.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var logs: [TimerStudyLog] = []
        if let data = UserDefaults.standard.data(forKey: timerLogKey),
            let decoded = try? JSONDecoder().decode([TimerStudyLog].self, from: data)
        {
            logs = decoded
        }

        logs.append(log)
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: timerLogKey)
        }

        if selectedMode == .focus || selectedMode == .custom {
            let elapsedSeconds = max(0.0, endedAt.timeIntervalSince(startedAt))
            let minutes = max(1, Int(ceil(elapsedSeconds / 60.0)))
            LearningStats.shared.recordStudySession(subject: "", wordsStudied: 0, minutes: minutes)
        }

        SyncManager.shared.requestAutoSync()
    }

    private func restoreTimerStateIfNeeded() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: persistedTimerStateKey),
            let decoded = try? JSONDecoder().decode(PersistedTimerState.self, from: data)
        else {
            return false
        }

        totalTime = decoded.totalTime
        selectedMode = TimerMode(rawValue: decoded.selectedMode) ?? selectedMode
        startTime = decoded.startTime
        endTime = decoded.endTime

        if decoded.isActive, let end = decoded.endTime {
            isActive = true
            let remaining = end.timeIntervalSince(Date())
            if remaining <= 0 {
                timeRemaining = 0
                isOvertime = true
                overtimeSeconds = abs(remaining)
            } else {
                timeRemaining = remaining
                isOvertime = false
                overtimeSeconds = 0
            }
            startTickingTimer()
            return true
        }

        isActive = false
        isOvertime = decoded.isOvertime
        overtimeSeconds = decoded.overtimeSeconds
        timeRemaining = decoded.timeRemaining
        return true
    }

    private func persistTimerState(force: Bool) {
        if !force {
            if Date().timeIntervalSince(lastPersistedAt) < 15 {
                return
            }
        }

        lastPersistedAt = Date()
        let state = PersistedTimerState(
            isActive: isActive,
            startTime: startTime,
            endTime: endTime,
            totalTime: totalTime,
            timeRemaining: timeRemaining,
            isOvertime: isOvertime,
            overtimeSeconds: overtimeSeconds,
            selectedMode: selectedMode.rawValue
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: persistedTimerStateKey)
        }
    }

    private func clearPersistedTimerState() {
        UserDefaults.standard.removeObject(forKey: persistedTimerStateKey)
    }

    // MARK: - Live Activity Logic
    private func startActivity(targetDate: Date) {
        #if canImport(ActivityKit) && os(iOS)
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

            let attributes = FocusTimerAttributes(timerName: selectedMode.rawValue)
            let state = FocusTimerAttributes.ContentState(
                targetTime: targetDate, totalSeconds: Int(totalTime))
            let content = ActivityContent(state: state, staleDate: nil)

            do {
                let activity = try Activity.request(
                    attributes: attributes, content: content, pushType: nil)
                self.activityID = activity.id
            } catch {
                print("Error starting Live Activity: \(error)")
            }
        #endif
    }

    private func endActivity() {
        #if canImport(ActivityKit) && os(iOS)
            guard let id = activityID,
                let activity = Activity<FocusTimerAttributes>.activities.first(where: {
                    $0.id == id
                })
            else { return }

            let state = FocusTimerAttributes.ContentState(targetTime: Date(), totalSeconds: 0)
            let content = ActivityContent(state: state, staleDate: nil)

            Task {
                await activity.end(content, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
                self.activityID = nil
            }
        #endif
    }

    // MARK: - Standby Timer View (Landscape Fullscreen)

    private var standbyTimerView: some View {
        GeometryReader { geometry in
            let isTimerMode = selectedTab == .timer
            let currentTime = isTimerMode ? timeRemaining : stopwatchTime
            let progress =
                isTimerMode
                ? (totalTime > 0 ? timeRemaining / totalTime : 0)
                : (stopwatchTime.truncatingRemainder(dividingBy: 60) / 60)
            let accentColor =
                isTimerMode
                ? selectedMode.color
                : theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)

            HStack(spacing: 0) {
                // Left section - Time display
                VStack(spacing: 16) {
                    if isTimerMode && isOvertime {
                        Text("+\(timeString(from: overtimeSeconds))")
                            .font(
                                .system(
                                    size: min(geometry.size.width * 0.2, 120), weight: .ultraLight,
                                    design: .monospaced)
                            )
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                    } else {
                        Text(
                            isTimerMode
                                ? timeString(from: currentTime) : stopwatchString(from: currentTime)
                        )
                        .font(
                            .system(
                                size: min(geometry.size.width * 0.2, 120), weight: .ultraLight,
                                design: .monospaced)
                        )
                        .foregroundStyle(theme.primaryText)
                        .contentTransition(.numericText())
                    }

                    // Mode label
                    Text(isTimerMode ? selectedMode.rawValue : "ストップウォッチ")
                        .font(.title3)
                        .foregroundStyle(theme.secondaryText)

                    if isTimerMode && isOvertime {
                        Text("オーバータイム")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)

                // Right section - Progress bar and controls
                VStack(spacing: 20) {
                    // Vertical progress bar
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 30)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTimerMode && isOvertime ? .red : accentColor)
                            .frame(
                                width: 30,
                                height: max(
                                    0,
                                    geometry.size.height * 0.6
                                        * CGFloat(isTimerMode ? progress : (1 - progress)))
                            )
                            .animation(.linear(duration: 1), value: progress)
                    }
                    .frame(height: geometry.size.height * 0.6)

                    // Control buttons
                    HStack(spacing: 20) {
                        // Reset
                        Button {
                            if isTimerMode {
                                resetTimer()
                            } else {
                                resetStopwatch()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 50, height: 50)
                                .background(
                                    theme.currentPalette.color(
                                        .surface, isDark: theme.effectiveIsDark
                                    ).opacity(0.5)
                                )
                                .clipShape(Circle())
                        }

                        // Play/Pause
                        Button {
                            if isTimerMode {
                                toggleTimer()
                            } else {
                                toggleStopwatch()
                            }
                        } label: {
                            let isRunning = isTimerMode ? isActive : stopwatchActive
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(theme.onColor(for: accentColor))
                                .frame(width: 60, height: 60)
                                .background(accentColor)
                                .clipShape(Circle())
                        }
                    }
                }
                .frame(width: 120)
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden(true)
        .ignoresSafeArea()
    }
}

private struct TickMarksView: View {
    var body: some View {
        ZStack {
            ForEach(0..<60) { tick in
                Rectangle()
                    .fill(Color.primary.opacity(tick % 5 == 0 ? 0.5 : 0.2))
                    .frame(width: tick % 5 == 0 ? 3 : 1, height: tick % 5 == 0 ? 20 : 10)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
        }
        .drawingGroup()
    }
}

// Preview removed for macOS compatibility
