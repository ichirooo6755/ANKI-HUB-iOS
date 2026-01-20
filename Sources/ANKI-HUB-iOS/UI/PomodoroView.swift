import SwiftUI
import UserNotifications

#if canImport(ANKI_HUB_iOS_Shared)
    import ANKI_HUB_iOS_Shared
#endif

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit
#endif

// MARK: - Timer & Stopwatch View
struct TimerView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject private var materialManager = StudyMaterialManager.shared

    let startRequest: TimerStartRequest?

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
        var activeSegmentStart: Date?
        var segments: [TimerStudySegment]?
        var selectedMode: String
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
    private let persistedTimerStateKey = "anki_hub_timer_state_v1"
    private let legacyPersistedTimerStateKey = "anki_hub_pomodoro_timer_state_v1"

    // Timer State
    @State private var timeRemaining: TimeInterval = 25 * 60
    @State private var totalTime: TimeInterval = 25 * 60
    @State private var isActive = false
    @State private var timer: Timer? = nil
    @State private var endTime: Date? = nil

    @State private var startTime: Date? = nil
    @State private var activeSegmentStart: Date? = nil
    @State private var timerSegments: [TimerStudySegment] = []
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
    @State private var shouldResetAfterStudyLog = false
    @State private var selectedMaterialId: UUID? = nil
    @State private var postStudyLogToTimeline = true

    // Live Activity State
    @State private var activityID: String? = nil
    // External Control (AppIntent)
    private let focusTimerControlKey = "anki_hub_focus_timer_control_v1"

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

    init(startRequest: TimerStartRequest? = nil) {
        self.startRequest = startRequest
    }

    enum TimerTab: String, CaseIterable {
        case timer = "タイマー"
        case stopwatch = "ストップウォッチ"
    }

    enum TimerMode: String, CaseIterable {
        case focus = "ポモドーロ"
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
            checkExternalControlRequest()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active {
                persistTimerState(force: true)
            } else {
                checkExternalControlRequest()
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
                checkExternalControlRequest()
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
        activeSegmentStart = nil
        timerSegments.removeAll()
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

        // 120分を1周(360度)に割り当てる
        let minutesDiff = Int((angleDiff / 3.0).rounded())

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
        #if os(iOS)
            let isCompact = verticalSizeClass == .compact
        #else
            let isCompact = false
        #endif
        let accent = selectedMode.color
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let dialSize: CGFloat = isCompact ? 250 : 290

        return VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("モード")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                Picker("モード", selection: $selectedMode) {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Clock Dial
            ZStack {
                Circle()
                    .stroke(surface.opacity(0.6), lineWidth: 14)
                    .padding(18)

                // Tick marks
                TickMarksView(
                    majorColor: theme.secondaryText.opacity(0.55),
                    minorColor: theme.secondaryText.opacity(0.28),
                    radius: dialSize / 2 - 16
                )

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining / totalTime))
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.9), value: timeRemaining)
                    .padding(18)

                // Time Display
                VStack(spacing: 6) {
                    Text(isActive ? "残り" : "設定時間")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                    Text(
                        isOvertime
                            ? "+\(timeString(from: overtimeSeconds))"
                            : timeString(from: timeRemaining)
                    )
                    .font(.system(size: isCompact ? 52 : 64, weight: .thin, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                    if isActive, let end = endTime {
                        Text("終了: \(endTimeString(end))")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 4)
                    } else if !isActive {
                        Text("ドラッグで調整")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 2)
                    }

                    if isOvertime {
                        Text("オーバータイム")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(width: dialSize, height: dialSize)
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

            // Controls (Health-like)
            VStack(spacing: 16) {
                let sideSize: CGFloat = isCompact ? 46 : 52
                let mainSize: CGFloat = isCompact ? 82 : 96

                HStack(spacing: 16) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: sideSize, height: sideSize)
                            .liquidGlassCircle()
                    }

                    Button {
                        toggleTimer()
                    } label: {
                        let bg = accent
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.system(size: isCompact ? 26 : 30, weight: .semibold))
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(width: mainSize, height: mainSize)
                            .background(bg)
                            .clipShape(Circle())
                            .shadow(color: bg.opacity(0.35), radius: 14, x: 0, y: 8)
                    }

                    Button {
                        stopTimer(userInitiated: true)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: sideSize, height: sideSize)
                            .liquidGlassCircle()
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        resetTimer()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("リセット")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(surface.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(border.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                            Text("設定")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(surface.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(border.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
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
                        .font(.system(size: 52, weight: .thin, design: .rounded))
                        .contentTransition(.numericText())
                        .monospacedDigit()

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
                        in: 1...120
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

    private func isStudyMode(_ mode: TimerMode) -> Bool {
        mode == .focus || mode == .custom
    }

    private func startActiveSegmentIfNeeded(at start: Date = Date()) {
        guard isStudyMode(selectedMode) else {
            activeSegmentStart = nil
            return
        }
        if activeSegmentStart == nil {
            activeSegmentStart = start
        }
    }

    private func endActiveSegmentIfNeeded(at end: Date = Date()) {
        guard let start = activeSegmentStart else { return }
        guard end > start else {
            activeSegmentStart = nil
            return
        }
        timerSegments.append(TimerStudySegment(startTime: start, endTime: end))
        activeSegmentStart = nil
    }

    private func currentTimerStudySessions(at end: Date = Date()) -> [StudySession] {
        guard isStudyMode(selectedMode) else { return [] }
        var segments = timerSegments
        if let activeStart = activeSegmentStart, end > activeStart {
            segments.append(TimerStudySegment(startTime: activeStart, endTime: end))
        }
        return segments.compactMap { segment in
            guard segment.endTime > segment.startTime else { return nil }
            return StudySession(startTime: segment.startTime, endTime: segment.endTime, source: .timer)
        }
    }

    private func refreshLearningStatsForTimer(at end: Date = Date()) {
        let sessions = currentTimerStudySessions(at: end)
        if sessions.isEmpty {
            LearningStats.shared.refreshStudyMinutesFromSessions()
        } else {
            LearningStats.shared.refreshStudyMinutesFromSessions(additionalSessions: sessions)
        }
    }

    private func checkExternalControlRequest() {
        #if os(iOS)
            guard let defaults = UserDefaults(suiteName: "group.com.ankihub.ios"),
                let data = defaults.data(forKey: focusTimerControlKey),
                let req = try? JSONDecoder().decode(FocusTimerControlRequest.self, from: data)
            else { return }

            // Clear request immediately to avoid replay
            defaults.removeObject(forKey: focusTimerControlKey)

            // Ignore stale requests (>5s)
            if Date().timeIntervalSince(req.requestedAt) > 5 {
                return
            }

            switch req.action {
            case .togglePause:
                toggleTimer()
            case .stop:
                if isActive {
                    stopTimer(userInitiated: true)
                } else if startTime != nil || isOvertime || timeRemaining != totalTime {
                    stopTimer(userInitiated: true)
                }
            }
        #endif
    }

    private func applyStartRequestIfNeeded() {
        guard !didApplyStartRequest else { return }
        didApplyStartRequest = true

        guard let req = startRequest, req.open else { return }
        guard !isActive else { return }

        selectedTab = .timer

        suppressModeChangeUpdate = true
        selectedMode = .custom

        let safeMinutes = max(1, min(120, req.minutes))
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
        if isActive {
            pauseTimer()
            return
        }

        let now = Date()

        if startTime == nil {
            startTime = now
            if suppressHistoryOnNextStart {
                suppressHistoryOnNextStart = false
            } else {
                addToHistory(minutes: Int(totalTime / 60), mode: selectedMode.rawValue)
            }
        }

        startActiveSegmentIfNeeded(at: now)

        isActive = true
        if isOvertime {
            endTime = nil
            startTickingTimer()
            persistTimerState(force: true)
            updateActivityForTimerState()
            refreshLearningStatsForTimer(at: now)
            return
        }

        let targetDate = Date().addingTimeInterval(timeRemaining)
        endTime = targetDate
        scheduleTimerEndNotification(targetDate: targetDate)
        startActivity(targetDate: targetDate)
        startTickingTimer()
        persistTimerState(force: true)
        updateActivityForTimerState()
        refreshLearningStatsForTimer(at: now)
    }

    private func pauseTimer() {
        guard isActive else { return }
        let pausedAt = Date()
        endActiveSegmentIfNeeded(at: pausedAt)
        isActive = false
        timer?.invalidate()
        timer = nil

        if !isOvertime, let end = endTime {
            timeRemaining = max(0, end.timeIntervalSince(Date()))
        }
        endTime = nil
        cancelTimerEndNotification()
        persistTimerState(force: true)
        updateActivityForTimerState()
        refreshLearningStatsForTimer(at: pausedAt)
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
        let stoppedAt = Date()
        endActiveSegmentIfNeeded(at: stoppedAt)
        isActive = false
        timer?.invalidate()
        timer = nil

        cancelTimerEndNotification()
        endActivity()
        persistTimerState(force: true)
        refreshLearningStatsForTimer(at: stoppedAt)

        if userInitiated {
            if let startedAt = startTime {
                let elapsedSeconds = max(0.0, stoppedAt.timeIntervalSince(startedAt))
                let shouldRecordMode = (selectedMode == .focus || selectedMode == .custom)
                if shouldRecordMode, elapsedSeconds >= 60 {
                    shouldResetAfterStudyLog = true
                    showStudyLogSheet = true
                    return
                }
            }

            if isOvertime || timeRemaining == 0 {
                shouldResetAfterStudyLog = true
                showStudyLogSheet = true
                return
            }
        }

        resetTimer()
    }

    private func resetTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
        updateTimerDuration()
        endTime = nil
        startTime = nil
        activeSegmentStart = nil
        timerSegments.removeAll()
        isOvertime = false
        overtimeSeconds = 0
        studyContent = ""
        cancelTimerEndNotification()
        endActivity()

        clearPersistedTimerState()
        shouldResetAfterStudyLog = false
    }

    private var timerStudyLogSheet: some View {
        NavigationStack {
            Form {
                Section("学習内容") {
                    TextField("何を勉強した？", text: $studyContent)
                }

                Section("教材") {
                    if materialManager.materials.isEmpty {
                        Text("教材を追加すると学習記録に紐づけできます")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        Picker("教材", selection: $selectedMaterialId) {
                            Text("未選択").tag(UUID?.none)
                            ForEach(materialManager.materials) { material in
                                Text(material.title).tag(Optional(material.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("タイムライン") {
                    Toggle("タイムラインにも投稿", isOn: $postStudyLogToTimeline)
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
                        if shouldResetAfterStudyLog {
                            resetTimer()
                            LearningStats.shared.refreshStudyMinutesFromSessions()
                        }
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

    private func updateActivityForTimerState() {
        #if canImport(ActivityKit) && os(iOS)
            guard let id = activityID,
                let activity = Activity<FocusTimerAttributes>.activities.first(where: { $0.id == id })
            else { return }

            let target: Date
            let pausedRemaining: Int?
            if isActive {
                if isOvertime {
                    target = Date()
                    pausedRemaining = nil
                } else {
                    target = Date().addingTimeInterval(timeRemaining)
                    pausedRemaining = nil
                }
            } else {
                target = Date()
                pausedRemaining = Int(max(0, timeRemaining))
            }

            let state = FocusTimerAttributes.ContentState(
                targetTime: target,
                totalSeconds: max(1, Int(totalTime)),
                pausedRemainingSeconds: pausedRemaining,
                isPaused: !isActive
            )
            let content = ActivityContent(state: state, staleDate: nil)
            Task {
                await activity.update(content)
            }
        #endif
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

        endActiveSegmentIfNeeded(at: endedAt)
        let segments = timerSegments

        let log = TimerStudyLog(
            startedAt: startedAt,
            endedAt: endedAt,
            mode: selectedMode.rawValue,
            plannedSeconds: Int(totalTime),
            overtimeSeconds: isOvertime ? Int(overtimeSeconds) : 0,
            studyContent: studyContent.trimmingCharacters(in: .whitespacesAndNewlines),
            materialId: selectedMaterialId,
            segments: segments.isEmpty ? nil : segments
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
        if postStudyLogToTimeline {
            TimelineManager.shared.addStudyLogEntry(log)
        }
        StudyMaterialManager.shared.recordTimerStudy(log)
        LearningStats.shared.refreshStudyMinutesFromSessions()
        SyncManager.shared.requestAutoSync()
    }

    private func restoreTimerStateIfNeeded() -> Bool {
        let data = UserDefaults.standard.data(forKey: persistedTimerStateKey)
            ?? UserDefaults.standard.data(forKey: legacyPersistedTimerStateKey)
        guard let data,
            let decoded = try? JSONDecoder().decode(PersistedTimerState.self, from: data)
        else {
            return false
        }

        totalTime = decoded.totalTime
        selectedMode = TimerMode(rawValue: decoded.selectedMode) ?? selectedMode
        startTime = decoded.startTime
        endTime = decoded.endTime
        timerSegments = decoded.segments ?? []
        activeSegmentStart = decoded.activeSegmentStart
        if !isStudyMode(selectedMode) {
            timerSegments.removeAll()
            activeSegmentStart = nil
        }

        if decoded.isActive, let end = decoded.endTime {
            isActive = true
            if isStudyMode(selectedMode), activeSegmentStart == nil {
                activeSegmentStart = decoded.startTime ?? Date()
            }
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
        if !decoded.isActive {
            activeSegmentStart = nil
        }
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
            activeSegmentStart: activeSegmentStart,
            segments: timerSegments.isEmpty ? nil : timerSegments,
            selectedMode: selectedMode.rawValue
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: persistedTimerStateKey)
        }
    }

    private func clearPersistedTimerState() {
        UserDefaults.standard.removeObject(forKey: persistedTimerStateKey)
        UserDefaults.standard.removeObject(forKey: legacyPersistedTimerStateKey)
    }

    // MARK: - Live Activity Logic
    private func startActivity(targetDate: Date) {
        #if canImport(ActivityKit) && os(iOS)
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

            let attributes = FocusTimerAttributes(timerName: selectedMode.rawValue)
            let state = FocusTimerAttributes.ContentState(
                targetTime: targetDate,
                totalSeconds: max(1, Int(totalTime)),
                pausedRemainingSeconds: nil,
                isPaused: false
            )
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

            let state = FocusTimerAttributes.ContentState(
                targetTime: Date(),
                totalSeconds: max(1, Int(totalTime)),
                pausedRemainingSeconds: 0,
                isPaused: true
            )
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
        #if os(iOS)
            .statusBarHidden(true)
        #endif
        .ignoresSafeArea()
    }
}

private struct TickMarksView: View {
    let majorColor: Color
    let minorColor: Color
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<60) { tick in
                Rectangle()
                    .fill(tick % 5 == 0 ? majorColor : minorColor)
                    .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 12 : 6)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
        }
        .drawingGroup()
    }
}

// Preview removed for macOS compatibility
