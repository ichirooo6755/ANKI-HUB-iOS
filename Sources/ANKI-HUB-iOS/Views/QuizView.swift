import AVFoundation
import QuartzCore
import SwiftUI

#if canImport(WidgetKit)
    import WidgetKit
#endif

struct QuizView: View {
    let subject: Subject

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var learningStats: LearningStats
    @EnvironmentObject var rankUpManager: RankUpManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var theme = ThemeManager.shared

    @ObservedObject private var learningManager = LearningManager.shared

    @State private var questions: [Question] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var isProcessingAnswer: Bool = false
    @State private var correctCount = 0
    @State private var wrongCount = 0
    @State private var quizCompleted = false
    @State private var questionCount = 10
    @State private var mode: QuizMode = .fourChoice
    @State private var showAnswer = false
    @State private var isRankUpMode = false
    @State private var rankUpChunkIndex: Int = 0
    @State private var selectedChapters: Set<String> = ["すべて"]
    @State private var availableChapters: [String] = []
    @State private var typingAnswer: String = ""  // For Typing Mode
    @State private var redSheetMode: Bool = false  // 赤シート
    @AppStorage("anki_hub_timer_limit_seconds_v1") private var timerLimitSetting: Int = 30
    @State private var timeLimit: Int = 30  // Default 30s (0 = no limit)
    @State private var timeRemaining: Int = 0
    @State private var timerActive: Bool = false
    @State private var baseTimeLimit: Int = 30  // Base time, increased for blanks
    @State private var showAddToWordbook: Bool = false
    @State private var wordbookRefreshNonce: Int = 0
    @State private var showFeedbackOverlay: Bool = false
    @State private var lastChosenAnswerText: String = ""
    @State private var revealedSeikeiBlankId: Int?
    @State private var showKobunHint: Bool = false
    @State private var showKanbunHint: Bool = false
    @State private var showStartErrorAlert: Bool = false
    @State private var startErrorMessage: String = ""
    
    // Shuffle mode
    @State private var isShuffleMode: Bool = false

    private let feedbackOverlayHideDelay: TimeInterval = 0.35
    private let autoAdvanceDelay: TimeInterval = 0.6

    // Mastery Filter (like UI reference)
    @State private var masteryFilters: Set<MasteryLevel> = [.new, .weak, .learning, .almost]
    @State private var specialTrainingMode: Bool = false  // 特訓モード

    @State private var mistakesSessionMode: Bool = false

    @State private var sessionId: Int = 0
    @State private var questionStartTime: TimeInterval = 0
    @State private var quizStartTime: TimeInterval = 0
    @State private var failedSeikeiArticleIds: Set<String> = []

    @State private var showMistakeReportSheet: Bool = false
    @State private var mistakeReportNote: String = ""
    @State private var mistakeReportError: String = ""
    @State private var isSubmittingMistakeReport: Bool = false

    @State private var cardDragX: CGFloat = 0

    @State private var sessionIncorrectQuestions: [Question] = []
    @State private var isReviewRound: Bool = false

    @State private var rechallengeQuestions: [Question] = []
    @State private var didDecideRechallengeForCurrent: Bool = false

    // Sequential Chapter Mode
    @State private var isSequentialMode: Bool = false
    @State private var chapterOrder: [String] = []
    @State private var currentChapterIndex: Int = 0

    private static var seikeiParseCache: [Int: (String, [Int: String])] = [:]

    // Initializer param
    var initialChapter: String? = nil
    private var initialMistakesOnly: Bool = false
    private var initialDueOnly: Bool = false

    init(
        subject: Subject, chapter: String? = nil, mistakesOnly: Bool = false, dueOnly: Bool = false
    ) {
        self.subject = subject
        self.initialChapter = chapter
        self.initialMistakesOnly = mistakesOnly
        self.initialDueOnly = dueOnly
        _mistakesSessionMode = State(initialValue: mistakesOnly)

        // Load timer setting from UserDefaults
        self.timeLimit = timerLimitSetting
        self.baseTimeLimit = timerLimitSetting
    }

    private var bookmarkButton: some View {
        _ = wordbookRefreshNonce
        let isBookmarked: Bool = {
            guard currentIndex < questions.count else { return false }
            let q = questions[currentIndex]

            if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
                let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data)
            {
                return decoded.contains(where: { $0.id == q.id })
            }
            return false
        }()

        return Button {
            addCurrentWordToWordbook()
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var retryButtons: some View {
        let q = questions[currentIndex]
        return VStack(spacing: 10) {
            Text("この問題をセッション内でもう一度出しますか？")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    scheduleRechallenge(for: q)
                    didDecideRechallengeForCurrent = true
                } label: {
                    let bg = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                    Text("もう一度出す")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    didDecideRechallengeForCurrent = true
                } label: {
                    Text("今回はいい")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }

    private func scheduleRechallenge(for q: Question) {
        // Avoid duplicates in the rechallenge queue
        if rechallengeQuestions.contains(where: { $0.id == q.id && $0.questionText == q.questionText }) {
            return
        }
        rechallengeQuestions.append(q)
    }

    private func toggleChapterSelection(_ chapter: String) {
        if chapter == "すべて" {
            selectedChapters = ["すべて"]
            return
        }

        // Selecting a specific chapter removes "すべて"
        if selectedChapters.contains("すべて") {
            selectedChapters.remove("すべて")
        }

        if selectedChapters.contains(chapter) {
            selectedChapters.remove(chapter)
        } else {
            selectedChapters.insert(chapter)
        }

        if selectedChapters.isEmpty {
            selectedChapters = ["すべて"]
        }
    }

    private var selectedChaptersDisplay: String {
        if selectedChapters.contains("すべて") || selectedChapters.isEmpty {
            return "すべて"
        }
        let sorted = selectedChapters.sorted()
        if sorted.count <= 2 {
            return sorted.joined(separator: ", ")
        }
        return "\(sorted.prefix(2).joined(separator: ", ")) ほか\(sorted.count - 2)件"
    }

    private func isTypingCorrect(typed: String, answer: String) -> Bool {
        let t = typed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if t.isEmpty { return false }

        // Partial match (minimum length to avoid accidental 1-2 letter hits)
        if t.count >= 3, a.contains(t) {
            return true
        }

        // Fuzzy match fallback
        return t.isFuzzyMatch(to: a, tolerance: 0.2)
    }

    private func cachedParseSeikeiQuizContent(_ text: String) -> (String, [Int: String]) {
        let key = text.hashValue
        if let cached = Self.seikeiParseCache[key] {
            return cached
        }
        let parsed = parseSeikeiQuizContent(text)
        Self.seikeiParseCache[key] = parsed
        return parsed
    }

    private let synthesizer = AVSpeechSynthesizer()

    enum QuizMode: String, CaseIterable {
        case fourChoice = "4択"
        case typing = "タイピング"
        case card = "カード"
    }

    var body: some View {
        ZStack {
            theme.background

            if questions.isEmpty {
                // Settings Screen
                quizSettingsView
                    .onAppear {
                        // Apply saved timer setting when entering the quiz settings screen
                        timeLimit = timerLimitSetting
                        baseTimeLimit = timerLimitSetting

                        if subject == .seikei {
                            var caps = VocabularyData.shared.getSeikeiChapters()
                            caps.insert("すべて", at: 0)
                            availableChapters = caps
                        } else if subject == .kobun {
                            let total = VocabularyData.shared.getVocabulary(for: .kobun).count
                            guard total > 0 else {
                                availableChapters = ["すべて"]
                                return
                            }
                            let blocks = Int(ceil(Double(total) / 50.0))
                            var caps: [String] = ["すべて"]
                            for i in 0..<blocks {
                                let start = i * 50 + 1
                                let end = min((i + 1) * 50, total)
                                caps.append("チャプター \(i + 1)（\(start)-\(end)）")
                            }
                            availableChapters = caps
                        } else if subject == .english {
                            // Can add chapters for English here if desired
                        }
                        if let initChap = initialChapter {
                            selectedChapters = [initChap]
                            if subject == .kobun, questionCount > 0 {
                                questionCount = max(questionCount, VocabularyData.shared.chunkSize)
                            }
                        }

                        // Remove selections that no longer exist (e.g., after word count shrink)
                        let valid = Set(availableChapters)
                        let filtered = selectedChapters.filter { valid.contains($0) }
                        selectedChapters = filtered.isEmpty ? ["すべて"] : filtered
                    }
                    .onChange(of: timerLimitSetting) { _, newValue in
                        // Only sync while quiz has not started
                        guard questions.isEmpty else { return }
                        timeLimit = newValue
                        baseTimeLimit = newValue
                    }
            } else if quizCompleted {
                // Results Screen
                quizResultsView
            } else {
                // Quiz Screen
                quizContentView
            }

            // Feedback Overlay
            if showFeedbackOverlay {
                OverlayFeedbackView(isCorrect: isCorrect)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .navigationTitle(subject.displayName)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: timerActive) {
            guard timerActive, timeLimit > 0 else { return }
            while timerActive, timeLimit > 0, !showResult {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                guard timerActive, timeLimit > 0, !showResult else { break }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    skipQuestion()
                    break
                }
            }
        }
        .sheet(isPresented: $showMistakeReportSheet) {
            NavigationStack {
                let currentQuestion = questions.indices.contains(currentIndex)
                    ? questions[currentIndex]
                    : nil
                VStack(spacing: 0) {
                    Form {
                        if let q = currentQuestion {
                            Section("問題") {
                                Text(q.questionText)
                                    .textSelection(.enabled)
                            }

                            Section("正解") {
                                Text(q.answerText)
                                    .textSelection(.enabled)
                            }

                            Section("選んだ回答") {
                                Text(currentChosenAnswerText() ?? "（未回答）")
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Section("メモ（任意）") {
                                TextEditor(text: $mistakeReportNote)
                                    .frame(minHeight: 120)
                            }

                            if !mistakeReportError.isEmpty {
                                Section {
                                    Text(mistakeReportError)
                                        .foregroundStyle(
                                            theme.currentPalette.color(
                                                .weak, isDark: theme.effectiveIsDark))
                                }
                            }
                        }
                    }

                    if subject == .kanbun, let question = currentQuestion {
                        KanbunWebView(kanbunText: kanbunDisplayText(for: question), isCompact: true)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                .navigationTitle("誤答通報")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showMistakeReportSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            submitMistakeReport()
                        } label: {
                            if isSubmittingMistakeReport {
                                ProgressView()
                            } else {
                                Text("送信")
                            }
                        }
                        .disabled(isSubmittingMistakeReport)
                    }
                }
            }
        }
        .applyAppTheme()
    }

    // MARK: - Settings View

    private var quizSettingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                watchSettingsHeader
                    .padding(.top, 8)

                // 習熟度グラフ
                SubjectMasteryChart(subject: subject, masteryTracker: masteryTracker)
                    .padding([.leading, .trailing])

                VStack(alignment: .leading, spacing: 16) {
                    // Mode Selection
                    Text("モード")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Picker("モード", selection: $mode) {
                        ForEach(QuizMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text("モード"))
                    .accessibilityValue(Text(mode.rawValue))

                    Toggle(isOn: $mistakesSessionMode) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                            Text("苦手一括復習")
                        }
                    }
                    .padding(.top)
                    
                    Toggle(isOn: $isShuffleMode) {
                        HStack {
                            Image(systemName: "shuffle")
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .accent, isDark: theme.effectiveIsDark))
                            Text("出題順をシャッフル")
                        }
                    }
                    .padding(.top)

                    // Mastery Filter (like UI reference: 未学習/苦手/うろ覚え/ほぼ覚えた)
                    Text("出題範囲")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                        spacing: 8
                    ) {
                        ForEach(
                            [
                                MasteryLevel.new, MasteryLevel.weak, MasteryLevel.learning,
                                MasteryLevel.almost,
                            ], id: \.self
                        ) { level in
                            Button {
                                if masteryFilters.contains(level) {
                                    masteryFilters.remove(level)
                                } else {
                                    masteryFilters.insert(level)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(level.color)
                                        .frame(width: 18, height: 18)
                                    Text(level.label)
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    masteryFilters.contains(level)
                                        ? level.color.opacity(0.2) : Color.gray.opacity(0.1)
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Special Training Mode
                    Toggle(isOn: $specialTrainingMode) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .accent, isDark: theme.effectiveIsDark))
                            VStack(alignment: .leading) {
                                Text("特訓モード")
                                    .font(.callout.weight(.semibold))
                                Text("全て『覚えた』になるまで出題")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top)

                    // Sequential Mode
                    Toggle(isOn: $isSequentialMode) {
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .primary, isDark: theme.effectiveIsDark))
                            VStack(alignment: .leading) {
                                Text("チャプター順に解く")
                                    .font(.callout.weight(.semibold))
                                Text("選択したチャプターを順に完了")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top)

                    // Question Count
                    Text("問題数")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top)

                    Picker("問題数", selection: $questionCount) {
                        Text("10問").tag(10)
                        Text("20問").tag(20)
                        Text("50問").tag(50)
                        Text("100問").tag(100)
                        Text("全問").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text("問題数"))
                    .accessibilityValue(Text(questionCount == 0 ? "全問" : "\(questionCount)問"))

                    Text("制限時間")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top)

                    let timeLimitLabel = timerLimitSetting == 0
                        ? "制限なし"
                        : "\(timerLimitSetting)秒"
                    let timeLimitBinding = Binding<Double>(
                        get: { Double(timerLimitSetting) },
                        set: { timerLimitSetting = Int($0.rounded()) }
                    )

                    LabeledContent {
                        Text(timeLimitLabel)
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    } label: {
                        Text("1問あたり")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                    }

                    Slider(value: timeLimitBinding, in: 0...120, step: 5) {
                        Text("制限時間")
                    } minimumValueLabel: {
                        Text("0")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    } maximumValueLabel: {
                        Text("120")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    }
                    .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    .accessibilityValue(Text(timeLimitLabel))

                    // Chapter Selection (multi-select)
                    if subject == .seikei || subject == .kobun {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("チャプターを選択")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(availableChapters, id: \.self) { chapter in
                                    let isSelected = selectedChapters.contains(chapter)
                                    Button {
                                        toggleChapterSelection(chapter)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isSelected
                                                    ? theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                                                    : .secondary)
                                            Text(chapter)
                                                .font(.subheadline)
                                                .foregroundStyle(theme.primaryText)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .layoutPriority(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(
                                            isSelected
                                            ? theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.15)
                                            : Color.gray.opacity(0.08)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    // Red Sheet Mode
                    Toggle(isOn: $redSheetMode) {
                        HStack {
                            Image(systemName: "doc.plaintext")
                                .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                            Text("赤シートモード")
                        }
                    }
                    .padding(.top)
                    
                    // Reset Button
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                            Text("デフォルトに戻す")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                Button {
                    startQuiz()
                } label: {
                    let bg = subject.color
                    Text("スタート")
                        .font(.headline)
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                // Rank Up Test Button
                if rankUpManager.canTakeRankUpTest(for: subject) {
                    Button {
                        startRankUpTest()
                    } label: {
                        let bg = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                        HStack {
                            Image(systemName: "trophy.fill")
                            Text(
                                "ランクアップテスト (\(rankUpManager.getUnlockedChunkCount(for: subject))/\(VocabularyData.shared.getChunkCount(for: subject)))"
                            )
                            .font(.headline)
                        }
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [
                                    theme.currentPalette.color(
                                        .accent, isDark: theme.effectiveIsDark),
                                    theme.currentPalette.color(
                                        .primary, isDark: theme.effectiveIsDark),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                } else if rankUpManager.getUnlockedChunkCount(for: subject)
                    >= VocabularyData.shared.getChunkCount(for: subject)
                {
                    Button {
                        // Completed state
                    } label: {
                        let bg = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("全チャプタークリア！")
                                .font(.headline)
                        }
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(true)
                    .padding(.horizontal)
                }

            }
            .padding(.bottom, 100)  // Extra padding for scrolling past the start button
        }
        .scrollContentBackground(.hidden)  // Ensure scroll background is transparent
        .contentMargins(.bottom, 40, for: .scrollIndicators)
    }

    // MARK: - Watch Style

    private var watchSettingsHeader: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let masteredColor = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let stats = masteryTracker.getStats(for: subject.rawValue)
        let totalWords = VocabularyData.shared.getVocabulary(for: subject).count
        let mastered = stats[.mastered] ?? 0
        let tracked = stats.values.reduce(0, +)
        let masteryRate = totalWords == 0
            ? 0
            : Int((Double(mastered) / Double(totalWords) * 100.0).rounded())
        let studiedCount = min(totalWords, tracked)

        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(subject.color.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: subject.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(subject.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text("全\(totalWords)語")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                watchRingCard(
                    title: "習得率",
                    value: "\(masteryRate)%",
                    progress: Double(masteryRate) / 100.0,
                    color: masteredColor,
                    size: 70
                )
                watchRingCard(
                    title: "学習済み",
                    value: "\(studiedCount)語",
                    progress: totalWords == 0 ? 0 : Double(studiedCount) / Double(totalWords),
                    color: primary,
                    size: 70
                )
                watchRingCard(
                    title: "今日",
                    value: "\(learningStats.todayMinutes)分",
                    progress: min(Double(learningStats.todayMinutes) / 60.0, 1),
                    color: accent,
                    size: 70
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.95 : 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(border.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var quizProgressHeader: some View {
        let totalQuestions = max(questions.count, 1)
        let progress = Double(currentIndex + 1) / Double(totalQuestions)
        let answered = correctCount + wrongCount
        let accuracy = answered > 0
            ? Int((Double(correctCount) / Double(answered) * 100.0).rounded())
            : 0
        let timeLimitForCurrent = timeLimitForQuestion(at: currentIndex)
        let timeProgress = timeLimitForCurrent > 0
            ? Double(timeRemaining) / Double(timeLimitForCurrent)
            : 0
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let ringSize: CGFloat = 64

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                watchRingCard(
                    title: "進行",
                    value: "\(currentIndex + 1)/\(questions.count)",
                    progress: progress,
                    color: subject.color,
                    size: ringSize
                )
                watchRingCard(
                    title: "正答率",
                    value: "\(accuracy)%",
                    progress: Double(accuracy) / 100.0,
                    color: mastered,
                    size: ringSize
                )
                if timeLimit > 0 {
                    let timeColor = timeRemaining <= 5 ? weak : accent
                    watchRingCard(
                        title: "残り",
                        value: "\(timeRemaining)s",
                        progress: timeProgress,
                        color: timeColor,
                        size: ringSize
                    )
                }
            }

            HStack(spacing: 8) {
                PillBadge(title: "正解 \(correctCount)", color: mastered)
                PillBadge(title: "不正解 \(wrongCount)", color: weak)
                PillBadge(title: "全\(questions.count)問", color: accent)
                Spacer()
                Button {
                    mistakeReportNote = ""
                    mistakeReportError = ""
                    showMistakeReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(weak)
                        .padding(8)
                        .background(weak.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.95 : 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(border.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var quizResultsSummary: some View {
        let totalQuestions = max(correctCount + wrongCount, 1)
        let accuracy = totalQuestions > 0
            ? Int((Double(correctCount) / Double(totalQuestions) * 100.0).rounded())
            : 0
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let ringSize: CGFloat = 72

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                watchRingCard(
                    title: "正答率",
                    value: "\(accuracy)%",
                    progress: Double(accuracy) / 100.0,
                    color: subject.color,
                    size: ringSize
                )
                watchRingCard(
                    title: "正解",
                    value: "\(correctCount)",
                    progress: Double(correctCount) / Double(totalQuestions),
                    color: mastered,
                    size: ringSize
                )
                watchRingCard(
                    title: "不正解",
                    value: "\(wrongCount)",
                    progress: Double(wrongCount) / Double(totalQuestions),
                    color: weak,
                    size: ringSize
                )
            }

            Text("全\(correctCount + wrongCount)問")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.95 : 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(border.opacity(0.4), lineWidth: 1)
        )
    }

    private func watchRingCard(
        title: String,
        value: String,
        progress: Double,
        color: Color,
        size: CGFloat
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                HealthRingView(progress: progress, color: color, lineWidth: 8, size: size)
                Text(value)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quiz Content View

    private var quizContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                quizProgressHeader
                    .padding(.top, 12)

                Group {
                    if questions.indices.contains(currentIndex) {
                        switch mode {
                        case .fourChoice:
                            fourChoiceView
                        case .typing:
                            typingView
                        case .card:
                            cardView
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
    }

    private func saveRecentMistake(question: Question, chosen: String?) {
        struct RecentMistake: Codable {
            let subject: String
            let wordId: String
            let term: String
            let correct: String
            let chosen: String?
            let date: Date
        }

        let payload = RecentMistake(
            subject: subject.rawValue,
            wordId: question.id,
            term: question.questionText,
            correct: question.answerText,
            chosen: chosen,
            date: Date()
        )

        let key = "anki_hub_recent_mistake_v1"
        let listKey = "anki_hub_recent_mistakes_v1"
        let appGroupId = "group.com.ankihub.ios"
        let encoder = JSONEncoder()
        let data = try? encoder.encode(payload)

        if let data {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults(suiteName: appGroupId)?.set(data, forKey: key)
        }

        func updateList(defaults: UserDefaults?) {
            guard let defaults else { return }
            var list: [RecentMistake] = []
            if let existing = defaults.data(forKey: listKey),
                let decoded = try? JSONDecoder().decode([RecentMistake].self, from: existing)
            {
                list = decoded
            }
            list.append(payload)
            list.sort { $0.date > $1.date }
            if list.count > 20 {
                list = Array(list.prefix(20))
            }
            if let encoded = try? encoder.encode(list) {
                defaults.set(encoded, forKey: listKey)
            }
        }

        updateList(defaults: UserDefaults.standard)
        updateList(defaults: UserDefaults(suiteName: appGroupId))

        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "StudyWidget")
        #endif
    }

    private func isInvalidSeikeiChoice(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if t.contains("回答素材") { return true }
        if t.contains("空欄") { return true }
        return false
    }

    // MARK: - Four Choice View

    private var fourChoiceView: some View {
        let question = questions[currentIndex]
        let isKanbunQuestion = subject == .kanbun
        let cardSpacing: CGFloat = isKanbunQuestion ? 10 : 12
        let cardPadding: CGFloat = isKanbunQuestion ? 18 : 24
        let choiceSpacing: CGFloat = isKanbunQuestion ? 8 : 12
        let choiceFont: Font = isKanbunQuestion ? .subheadline : .body
        let choicePadding: CGFloat = isKanbunQuestion ? 12 : 16

        return VStack(spacing: 24) {
            // Question Card
            VStack(spacing: cardSpacing) {
                HStack {
                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Text(question.questionText)
                        .font(isKanbunQuestion ? .subheadline : .headline)
                        .foregroundStyle(.secondary)
                    Spacer()

                    if timeLimit > 0 {
                        let danger = theme.currentPalette.color(
                            .weak, isDark: theme.effectiveIsDark)
                        let accent = theme.currentPalette.color(
                            .accent, isDark: theme.effectiveIsDark)
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text("残り\(timeRemaining)秒")
                                .monospacedDigit()
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(timeRemaining <= 5 ? danger : accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            timeRemaining <= 5 ? danger.opacity(0.22) : accent.opacity(0.22)
                        )
                        .clipShape(Capsule())
                    }

                    Button {
                        speakWord(question.questionText)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(
                                theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    }
                }

                // For Seikei: Display fullText with blanks using SeikeiWebView
                if subject == .seikei, let fullText = question.fullText, !fullText.isEmpty {
                    let (seikeiContent, seikeiBlankMap) = cachedParseSeikeiQuizContent(fullText)
                    SeikeiWebView(
                        content: seikeiContent,
                        blankMap: seikeiBlankMap,
                        revealedId: $revealedSeikeiBlankId,
                        isAllRevealed: redSheetMode || showResult
                    ) { id, _ in
                        guard showResult || redSheetMode else { return }
                        revealedSeikeiBlankId = id
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }

                // Hide hints for Kanbun/Kobun until answer is shown (per user request)
                if let hint = question.hint {
                    if subject == .kobun {
                        if showKobunHint || showResult {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKobunHint = true
                            } label: {
                                Label("ヒントを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    } else if subject == .kanbun {
                        if showKanbunHint || showResult {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKanbunHint = true
                            } label: {
                                Label("ふりがなを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text(hint)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(cardPadding)
            .liquidGlass(cornerRadius: 20)
            .padding(.horizontal)
            .overlay(alignment: .topTrailing) {
                bookmarkButton
                    .padding(12)
            }

            // Choices
            VStack(spacing: choiceSpacing) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        selectAnswer(index, correctIndex: question.correctIndex)
                    } label: {
                        HStack {
                            Text(choice)
                                .font(choiceFont)
                                .multilineTextAlignment(.leading)
                                .lineLimit(isKanbunQuestion ? 3 : nil)
                                .minimumScaleFactor(isKanbunQuestion ? 0.75 : 1.0)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()

                            if showResult {
                                if index == question.correctIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(
                                            theme.currentPalette.color(
                                                .mastered, isDark: theme.effectiveIsDark))
                                } else if index == selectedAnswer {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(
                                            theme.currentPalette.color(
                                                .weak, isDark: theme.effectiveIsDark))
                                }
                            }
                        }
                        .padding(choicePadding)
                        .background(
                            choiceBackground(index: index, correctIndex: question.correctIndex)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(showResult || isProcessingAnswer)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)

            if !showResult {
                Button {
                    skipQuestion()
                } label: {
                    Label("スキップ", systemImage: "forward.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isProcessingAnswer)
                .padding(.horizontal)
            }

            if showResult {
                if !isCorrect, !didDecideRechallengeForCurrent {
                    retryButtons
                }
                Button {
                    nextQuestion()
                } label: {
                    let bg = subject.color
                    Text("次へ")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Typing View

    private var typingView: some View {
        let question = questions[currentIndex]

        return VStack(spacing: 24) {
            // Question Card
            VStack(spacing: 12) {
                HStack {
                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if subject == .kanbun {
                    if let example = question.example, !example.isEmpty {
                        Text(question.questionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    KanbunWebView(kanbunText: kanbunDisplayText(for: question), isCompact: true)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    Text(question.questionText)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }

                if subject == .seikei, let bid = question.seikeiBlankId {
                    Text("空欄 \(bid)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }

                if subject == .seikei, let fullText = question.fullText, !fullText.isEmpty {
                    let (seikeiContent, seikeiBlankMap) = cachedParseSeikeiQuizContent(fullText)
                    SeikeiWebView(
                        content: seikeiContent,
                        blankMap: seikeiBlankMap,
                        revealedId: $revealedSeikeiBlankId,
                        isAllRevealed: redSheetMode || showResult
                    ) { id, _ in
                        guard showResult || redSheetMode else { return }
                        revealedSeikeiBlankId = id
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }

                if let hint = question.hint {
                    if subject == .kobun {
                        if showKobunHint || showResult {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKobunHint = true
                            } label: {
                                Label("ヒントを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    } else if subject == .kanbun {
                        if showKanbunHint || showResult {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKanbunHint = true
                            } label: {
                                Label("ふりがなを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text(hint)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .liquidGlass(cornerRadius: 20)
            .padding(.horizontal)
            .overlay(alignment: .topTrailing) {
                bookmarkButton
                    .padding(12)
            }

            // Answer Input
            VStack(spacing: 16) {
                TextField("答えを入力...", text: $typingAnswer)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
                    .padding(.horizontal)

                if showResult {
                    HStack(spacing: 12) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(
                                isCorrect
                                    ? theme.currentPalette.color(
                                        .mastered, isDark: theme.effectiveIsDark)
                                    : theme.currentPalette.color(
                                        .weak, isDark: theme.effectiveIsDark))
                        Text(isCorrect ? "正解!" : "正解: \(question.answerText)")
                            .font(.headline)
                    }
                    .padding()
                    .liquidGlass(cornerRadius: 12)
                }

                if showResult && !isCorrect && !didDecideRechallengeForCurrent {
                    retryButtons
                }

                Button {
                    if showResult {
                        typingAnswer = ""
                        nextQuestion()
                    } else {
                        let correct = isTypingCorrect(typed: typingAnswer, answer: question.answerText)
                        selectTypingAnswer(isCorrect: correct)
                    }
                } label: {
                    let bg = showResult
                        ? theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                        : theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
                    Text(showResult ? "次へ" : "決定")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .foregroundStyle(theme.onColor(for: bg))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
        }
    }

    private func selectTypingAnswer(isCorrect: Bool) {
        guard !isProcessingAnswer else { return }
        isProcessingAnswer = true
        let responseTime = max(0.0, CACurrentMediaTime() - questionStartTime)
        self.isCorrect = isCorrect
        showResult = true

        lastChosenAnswerText = typingAnswer

        if isCorrect {
            correctCount += 1
        } else {
            wrongCount += 1
            sessionIncorrectQuestions.append(questions[currentIndex])
        }

        let question = questions[currentIndex]
        masteryTracker.recordAnswer(
            subject: subject.rawValue,
            wordId: question.id,
            isCorrect: isCorrect,
            responseTime: responseTime,
            blankCount: blankCount(for: question),
            sessionId: sessionId,
            chosenAnswerText: lastChosenAnswerText,
            correctAnswerText: question.answerText
        )

        if !isCorrect {
            saveRecentMistake(question: question, chosen: lastChosenAnswerText)
        }

        if isRankUpMode {
            rankUpManager.recordTestAnswer(isCorrect: isCorrect)
        }

        if reduceMotion {
            showResult = true
            showFeedbackOverlay = true
        } else {
            withAnimation(.spring(duration: 0.3)) {
                showResult = true
                showFeedbackOverlay = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackOverlayHideDelay) {
            if self.reduceMotion {
                self.showFeedbackOverlay = false
            } else {
                withAnimation {
                    self.showFeedbackOverlay = false
                }
            }
        }

        // Auto Advance if correct
        if isCorrect {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoAdvanceDelay) {
                if self.showResult && self.currentIndex < self.questions.count {
                    if self.reduceMotion {
                        self.nextQuestion()
                    } else {
                        withAnimation {
                            self.nextQuestion()
                        }
                    }
                }
            }
        } else {
            // allow user to tap Next
            isProcessingAnswer = false
        }
    }
    private var cardView: some View {
        let question = questions[currentIndex]

        let okColor = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let ngColor = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)

        return VStack(spacing: 24) {
            // Card
            VStack(spacing: 16) {
                HStack {
                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if subject == .kanbun {
                    if let example = question.example, !example.isEmpty {
                        Text(question.questionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    KanbunWebView(kanbunText: kanbunDisplayText(for: question))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Text(question.questionText)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                }

                if subject == .seikei, let bid = question.seikeiBlankId {
                    Text("空欄 \(bid)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }

                if subject == .seikei, let fullText = question.fullText, !fullText.isEmpty {
                    let (seikeiContent, seikeiBlankMap) = cachedParseSeikeiQuizContent(fullText)
                    SeikeiWebView(
                        content: seikeiContent,
                        blankMap: seikeiBlankMap,
                        revealedId: $revealedSeikeiBlankId,
                        isAllRevealed: redSheetMode || showAnswer
                    ) { id, _ in
                        guard showAnswer || redSheetMode else { return }
                        revealedSeikeiBlankId = id
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }

                if let hint = question.hint {
                    if subject == .kobun {
                        if showKobunHint || showAnswer {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKobunHint = true
                            } label: {
                                Label("ヒントを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    } else if subject == .kanbun {
                        if showKanbunHint || showAnswer {
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .selection, isDark: theme.effectiveIsDark))
                        } else {
                            Button {
                                showKanbunHint = true
                            } label: {
                                Label("ふりがなを見る", systemImage: "eye.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentPalette.color(
                                            .surface, isDark: theme.effectiveIsDark)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if showAnswer {
                    Divider()
                    Text(question.answerText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(subject.color)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(32)
            .liquidGlass(cornerRadius: 24)
            .padding(.horizontal)
            .overlay(alignment: .topTrailing) {
                bookmarkButton
                    .padding(12)
            }
            .overlay {
                let okOpacity = min(1.0, max(0.0, Double(cardDragX / 90.0)))
                let ngOpacity = min(1.0, max(0.0, Double(-cardDragX / 90.0)))
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ngColor)
                        .opacity(ngOpacity)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(okColor)
                        .opacity(okOpacity)
                }
                .padding(.horizontal, 20)
                .allowsHitTesting(false)
            }
            .offset(x: cardDragX)
            .rotationEffect(.degrees(Double(cardDragX / 14.0)))
            .onTapGesture {
                if reduceMotion {
                    showAnswer.toggle()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        showAnswer.toggle()
                    }
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard showAnswer, !showResult, !isProcessingAnswer else { return }
                        if !reduceMotion {
                            cardDragX = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard showAnswer, !showResult, !isProcessingAnswer else {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.3)) { cardDragX = 0 }
                            }
                            return
                        }

                        let threshold: CGFloat = 90
                        // In reduce motion, use smaller threshold or just detect swipe direction without animation
                        if value.translation.width > threshold {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    cardDragX = 500
                                }
                            }
                            recordCardAnswer(isCorrect: true)
                        } else if value.translation.width < -threshold {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    cardDragX = -500
                                }
                            }
                            recordCardAnswer(isCorrect: false)
                        } else {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.3)) {
                                    cardDragX = 0
                                }
                            }
                        }
                    }
            )

            if showAnswer {
                HStack(spacing: 16) {
                    Button {
                        #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        #endif
                        recordCardAnswer(isCorrect: false)
                    } label: {
                        let bg = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                        VStack {
                            Image(systemName: "xmark")
                                .font(.title2.bold())
                            Text("わからない")
                                .font(.footnote)
                        }
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(showResult || isProcessingAnswer)

                    Button {
                        #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        #endif
                        recordCardAnswer(isCorrect: true)
                    } label: {
                        let bg = theme.currentPalette.color(
                            .mastered, isDark: theme.effectiveIsDark)
                        VStack {
                            Image(systemName: "checkmark")
                                .font(.title2.bold())
                            Text("わかった")
                                .font(.footnote)
                        }
                        .foregroundStyle(theme.onColor(for: bg))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(showResult || isProcessingAnswer)
                }
                .padding(.horizontal)

                if showResult {
                    if !isCorrect {
                        retryButtons
                            .padding(.horizontal)
                    }
                    Button {
                        nextQuestion()
                    } label: {
                        let bg = subject.color
                        Text("次へ")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Results View

    private var quizResultsView: some View {
        let total = correctCount + wrongCount
        let accuracy = total > 0 ? Int((Double(correctCount) / Double(total)) * 100) : 0

        return VStack(spacing: 24) {
            Spacer()

            // Emoji & Title
            if isRankUpMode {
                let passed = rankUpManager.checkTestResult(
                    correctCount: correctCount, totalCount: total)

                Text(passed ? "🎉" : "💪")
                    .font(.largeTitle)

                Text(passed ? "ランクアップ！" : "不合格...")
                    .font(.largeTitle.bold())
                    .foregroundStyle(passed ? .green : .red)

                Text(passed ? "新しいチャプターが解放されました！" : "もう一度挑戦して合格を目指そう！")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onAppear {
                        if passed {
                            rankUpManager.completeRankUpTest(for: subject)
                        }
                    }
            } else {
                Text(accuracy >= 80 ? "🎉" : accuracy >= 60 ? "👍" : "📚")
                    .font(.largeTitle)

                // Score
                Text("\(accuracy)%")
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accuracy >= 80 ? .green : accuracy >= 60 ? .blue : .orange)

                Text(accuracy >= 80 ? "素晴らしい！" : accuracy >= 60 ? "よくできました！" : "もう少し頑張ろう！")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            quizResultsSummary
                .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if !sessionIncorrectQuestions.isEmpty {
                    Button {
                        startReviewRound()
                    } label: {
                        let bg = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                        Label("間違えた問題を復習", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                if isSequentialMode, currentChapterIndex < chapterOrder.count - 1 {
                    Button {
                        nextChapter()
                    } label: {
                        let bg = subject.color
                        Label("次のチャプターへ", systemImage: "arrow.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    Button {
                        resetQuiz()
                    } label: {
                        let bg = subject.color
                        Label("もう一度", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helper Views

    struct KanbunVerticalText: View {
        let text: String

        var body: some View {
            // Simplified vertical text display
            // In a real implementation this would handle Ruby/Kaeriten parsing
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(text.reversed().enumerated()), id: \.offset) { _, char in
                    VStack {
                        Text(String(char))
                            .font(.title2.weight(.bold))
                            .frame(width: 40)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helper Functions

    private func choiceBackground(index: Int, correctIndex: Int) -> Color {
        if !showResult {
            return Color.gray.opacity(0.1)
        }
        if index == correctIndex {
            return .green.opacity(0.2)
        }
        if index == selectedAnswer && index != correctIndex {
            return .red.opacity(0.2)
        }
        return Color.gray.opacity(0.1)
    }

    private func kanbunDisplayText(for question: Question) -> String {
        if let example = question.example, !example.isEmpty {
            return example
        }
        return question.questionText
    }

    private func startQuiz() {
        learningManager.incrementSessionCount()
        sessionId = learningManager.currentSessionCount
        quizStartTime = CACurrentMediaTime()

        // Sequential mode: solve selected chapters in order
        if isSequentialMode {
            // If we're already in a sequential run (nextChapter -> startQuiz), keep current chapter order.
            if chapterOrder.isEmpty {
                let selected = selectedChapters

                if selected.contains("すべて") || selected.isEmpty {
                    // Use all chapters in order (excluding "すべて")
                    chapterOrder = availableChapters.filter { $0 != "すべて" }
                } else {
                    func chapterNumberForSort(_ s: String) -> Int? {
                        let trimmed = s
                            .replacingOccurrences(of: "STAGE", with: "")
                            .replacingOccurrences(of: "Chapter", with: "")
                            .replacingOccurrences(of: "チャプター", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let digits = trimmed.prefix { $0.isNumber }
                        return Int(digits)
                    }

                    chapterOrder = selected.sorted { a, b in
                        let na = chapterNumberForSort(a)
                        let nb = chapterNumberForSort(b)
                        switch (na, nb) {
                        case let (x?, y?):
                            if x != y { return x < y }
                            return a < b
                        case (_?, nil):
                            return true
                        case (nil, _?):
                            return false
                        default:
                            return a < b
                        }
                    }
                }
                currentChapterIndex = 0

                if let first = chapterOrder.first {
                    selectedChapters = [first]
                }
            }
        }

        questions = generateQuestions(count: questionCount)

        if isShuffleMode {
            questions.shuffle()
        }

        if questions.isEmpty {
            startErrorMessage =
                "問題を生成できませんでした。\nデータが読み込めていないか、出題範囲フィルタで0件になっています。\n一度アプリを再起動するか、出題範囲/チャプター設定を確認してください。"
            showStartErrorAlert = true
            return
        }

        currentIndex = 0
        correctCount = 0
        wrongCount = 0
        quizCompleted = false
        showResult = false
        showAnswer = false
        cardDragX = 0
        isProcessingAnswer = false
        isRankUpMode = false
        questionStartTime = CACurrentMediaTime()
        revealedSeikeiBlankId = nil
        failedSeikeiArticleIds = []

        // Reset for new session
        sessionIncorrectQuestions = []
        isReviewRound = false

        // Start timer if time limit is set
        if timeLimit > 0 {
            timeRemaining = timeLimitForQuestion(at: 0)
            timerActive = true
        }
    }

    private func nextChapter() {
        guard isSequentialMode else {
            resetQuiz()
            return
        }

        if currentChapterIndex < chapterOrder.count - 1 {
            currentChapterIndex += 1
            selectedChapters = [chapterOrder[currentChapterIndex]]
            questions = []
            quizCompleted = false
            startQuiz()
            return
        }

        resetQuiz()
    }

    private func startRankUpTest() {
        learningManager.incrementSessionCount()
        sessionId = learningManager.currentSessionCount

        isRankUpMode = true
        let chunkIndex = rankUpManager.getUnlockedChunkCount(for: subject) - 1  // JS logic seems to be current UNLOCKED index is what we practice? Or the NEXT one?
        // JS: if unlockedChunks = 1, we test chunk 0.
        rankUpChunkIndex = chunkIndex

        let vocab = VocabularyData.shared.getVocabularyForChunk(
            subject: subject, chunkIndex: chunkIndex)
        guard !vocab.isEmpty else { return }

        // Settings for RankUp
        questionCount = min(rankUpManager.testQuestionCount, vocab.count)

        // Generate Questions for Rank Up (Shuffle chunk items)
        questions = generateQuestionsFromVocab(vocab, count: questionCount)

        currentIndex = 0
        correctCount = 0
        wrongCount = 0
        quizCompleted = false
        showResult = false
        showAnswer = false

        rankUpManager.startTest()

        quizStartTime = CACurrentMediaTime()

        questionStartTime = CACurrentMediaTime()
        revealedSeikeiBlankId = nil
        failedSeikeiArticleIds = []
        if timeLimit > 0 {
            timeRemaining = timeLimitForQuestion(at: 0)
            timerActive = true
        }
    }

    private func resolvedQuestionCount(requested: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        if requested <= 0 {
            return total
        }
        return min(requested, total)
    }

    private func generateQuestions(count: Int) -> [Question] {
        // Get vocabulary based on subject
        var vocab = VocabularyData.shared.getVocabulary(for: subject)

        if initialDueOnly {
            let desiredCount = resolvedQuestionCount(requested: count, total: vocab.count)
            if desiredCount <= 0 {
                print("QuizView: No vocabulary available")
                return []
            }
            // "テスト日までに回数をこなす"ため、期限到来(due)だけでなく期限直前(dueSoon)も含める
            let candidates = masteryTracker.getReviewCandidates(
                allItems: vocab, subject: subject.rawValue, includeDueSoon: true)
            var picked = Array(candidates.prefix(desiredCount))
            if picked.count < desiredCount {
                let usedIds = Set(picked.map { $0.id })
                let backfill =
                    masteryTracker
                    .sortByPriority(
                        items: vocab.filter { !usedIds.contains($0.id) }, subject: subject.rawValue)
                picked.append(contentsOf: backfill.prefix(desiredCount - picked.count))
            }
            return generateQuestionsFromVocab(picked, count: desiredCount)
        }

        if mistakesSessionMode {
            vocab = vocab.filter {
                masteryTracker.getMastery(subject: subject.rawValue, wordId: $0.id) == .weak
            }
        }

        if !masteryFilters.isEmpty {
            vocab = vocab.filter {
                masteryFilters.contains(
                    masteryTracker.getMastery(subject: subject.rawValue, wordId: $0.id))
            }
        }

        if specialTrainingMode {
            vocab = vocab.filter {
                masteryTracker.getMastery(subject: subject.rawValue, wordId: $0.id) != .mastered
            }
        }

        // Apply chapter filter (multi-select)
        let chaptersForFilter: Set<String> = {
            if let chapter = initialChapter, !chapter.isEmpty { return [chapter] }
            if subject == .seikei || subject == .kobun {
                if selectedChapters.contains("すべて") || selectedChapters.isEmpty {
                    return []
                }
                return selectedChapters
            }
            return []
        }()

        if !chaptersForFilter.isEmpty {
            var merged: [Vocabulary] = []
            var seen: Set<String> = []
            for chapter in chaptersForFilter {
                for v in filterVocabByChapter(vocab, chapter: chapter) {
                    if seen.insert(v.id).inserted {
                        merged.append(v)
                    }
                }
            }
            vocab = merged
        }

        guard !vocab.isEmpty else {
            print("QuizView: No vocabulary found for chapter filter")
            return []
        }

        let desiredCount = resolvedQuestionCount(requested: count, total: vocab.count)

        print("QuizView: Generating \(desiredCount) questions from \(vocab.count) vocabulary items")

        // Use Spaced Repetition Logic if not filtered by chapter
        var finalSelection: [Vocabulary] = []

        let candidateLimit = min(vocab.count, max(desiredCount, desiredCount * 3))

        if !chaptersForFilter.isEmpty {
            // If specific chapter is selected, still use a larger candidate pool so history filtering can't collapse to 1 item.
            finalSelection = Array(vocab.shuffled().prefix(candidateLimit))
        } else {
            // General study: Implementation of sugwrAnki V2 Algorithm
            // 1. Split into NEW and REVIEW
            let newWords = vocab.filter {
                masteryTracker.getMastery(subject: subject.rawValue, wordId: $0.id) == .new
            }.shuffled()
            let reviewWords = vocab.filter {
                masteryTracker.getMastery(subject: subject.rawValue, wordId: $0.id) != .new
            }

            // 2. Sort Review Words by Priority (WEAK > NEW > ... + Forget Curve)
            // Note: masteryTracker.sortByPriority handles the sorting logic efficiently.
            let sortedReviews = masteryTracker.sortByPriority(
                items: reviewWords, subject: subject.rawValue)

            // 3. Calculate quotas
            // Force 50% New items (at least 5 if possible) to ensure progress
            let forceNewCount = min(newWords.count, max(5, Int(Double(candidateLimit) * 0.5)))

            // 4. Build Queue
            var queue: [Vocabulary] = []

            // Add Priority New Words
            queue.append(contentsOf: newWords.prefix(forceNewCount))

            // Add Sorted Reviews for remaining slots
            let remainingSlots = candidateLimit - queue.count
            if remainingSlots > 0 {
                queue.append(contentsOf: sortedReviews.prefix(remainingSlots))
            }

            // 5. Fill if still under count (with more New words if available)
            if queue.count < candidateLimit {
                let stillNeeded = candidateLimit - queue.count
                let usedIds = Set(queue.map { $0.id })
                let unusedNew = newWords.filter { !usedIds.contains($0.id) }
                queue.append(contentsOf: unusedNew.prefix(stillNeeded))
            }

            // 6. If STILL under count (e.g. no new words, few reviews), fill with random reviews not yet picked
            if queue.count < candidateLimit {
                let stillNeeded = candidateLimit - queue.count
                let usedIds = Set(queue.map { $0.id })
                let unusedReviews = sortedReviews.filter { !usedIds.contains($0.id) }
                queue.append(contentsOf: unusedReviews.prefix(stillNeeded))
            }

            finalSelection = queue
        }

        let withHistory = learningManager.selectQuestionsWithHistory(
            words: finalSelection,
            count: desiredCount,
            subject: subject.rawValue,
            masteryTracker: masteryTracker
        )

        var picked = withHistory
        if picked.count < desiredCount {
            let usedIds = Set(picked.map { $0.id })
            let backfill =
                masteryTracker
                .sortByPriority(
                    items: vocab.filter { !usedIds.contains($0.id) }, subject: subject.rawValue)
            picked.append(contentsOf: backfill.prefix(desiredCount - picked.count))
        }

        return generateQuestionsFromVocab(picked, count: desiredCount)
    }

    // Helper to filter vocabulary by chapter
    private func filterVocabByChapter(_ vocab: [Vocabulary], chapter: String) -> [Vocabulary] {
        let chunkSize = 50

        if chapter == "すべて" {
            return vocab
        }

        if subject == .seikei {
            // Seikei: use category field (DataParser assigns exact chapter string)
            return vocab.filter { $0.category == chapter }
        }

        if subject == .kanbun {
            // Kanbun: use production data as-is.
            // If data has categories, use them; otherwise ignore chapter selection and use all.
            if chapter == "すべて" {
                return vocab
            }

            if vocab.contains(where: { ($0.category ?? "").isEmpty == false }) {
                return vocab.filter { $0.category == chapter }
            }

            return vocab
        }

        // Parse chapter to get index
        if chapter.hasPrefix("STAGE") {
            // English: STAGE1, STAGE2, ... STAGE38
            if let stageNum = Int(chapter.replacingOccurrences(of: "STAGE", with: "")) {
                let startIndex = (stageNum - 1) * chunkSize
                let endIndex = min(stageNum * chunkSize, vocab.count)
                if startIndex < vocab.count {
                    return Array(vocab[startIndex..<endIndex])
                }
            }
        } else if chapter.hasPrefix("Chapter") || chapter.hasPrefix("チャプター") {
            // Kobun/Kanbun/Seikei: Chapter 1, Chapter 2, etc.
            // Extract number from "Chapter X" or "Chapter X (Y-Z条)"
            let trimmed = chapter
                .replacingOccurrences(of: "Chapter", with: "")
                .replacingOccurrences(of: "チャプター", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let digits = trimmed.prefix { $0.isNumber }

            if let chapterNum = Int(digits) {
                let startIndex = (chapterNum - 1) * chunkSize
                let endIndex = min(chapterNum * chunkSize, vocab.count)
                if startIndex < vocab.count {
                    return Array(vocab[startIndex..<endIndex])
                }
            }
        }

        // Fallback: return all
        return vocab
    }

    private func generateQuestionsFromVocab(_ vocab: [Vocabulary], count: Int) -> [Question] {
        let allVocabPool = VocabularyData.shared.getVocabulary(for: subject)  // For wrong choices

        var results: [Question] = []

        for word in vocab {
            if subject == .seikei, word.questionType == "blank", let answers = word.allAnswers,
                !answers.isEmpty
            {
                let answerToBlankId: [String: Int] = {
                    guard let fullText = word.fullText, !fullText.isEmpty else { return [:] }
                    let (_, map) = cachedParseSeikeiQuizContent(fullText)
                    // map is [blankId: answer]
                    return Dictionary(uniqueKeysWithValues: map.map { ($0.value, $0.key) })
                }()

                let answerPool: [String] = {
                    let sameCategory = allVocabPool.filter {
                        $0.category == word.category && $0.id != word.id
                    }
                    let candidates = sameCategory.compactMap { $0.allAnswers }.flatMap { $0 }
                    return Array(Set(candidates)).filter { !isInvalidSeikeiChoice($0) }
                }()

                for (idx, answer) in answers.enumerated() {
                    let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !isInvalidSeikeiChoice(trimmedAnswer) else { continue }
                    let wrongs = answerPool.filter { $0 != trimmedAnswer }.shuffled()
                    var choices = [answer]
                    choices.append(contentsOf: wrongs.prefix(3))
                    choices = Array(Set(choices))
                    if choices.count < 4 {
                        let fallbackWrongs =
                            allVocabPool
                            .compactMap { $0.allAnswers }
                            .flatMap { $0 }
                            .filter { $0 != trimmedAnswer && !isInvalidSeikeiChoice($0) }
                            .shuffled()
                        choices.append(contentsOf: fallbackWrongs.prefix(max(0, 4 - choices.count)))
                        choices = Array(Set(choices))
                    }
                    choices = Array(choices.prefix(4)).shuffled()

                    let correctIndex = choices.firstIndex(of: trimmedAnswer) ?? 0

                    let bid = answerToBlankId[trimmedAnswer] ?? (idx + 1)
                    results.append(
                        Question(
                            id: word.id,
                            questionText: "\(word.term)（空欄\(bid)）",
                            answerText: trimmedAnswer,
                            hint: subject == .kobun
                                ? word.hint
                                : (subject == .kanbun ? (word.reading ?? word.hint) : nil),
                            example: word.example,
                            choices: choices,
                            correctIndex: correctIndex,
                            fullText: word.fullText,
                            seikeiBlankId: bid
                        )
                    )
                }
            } else if subject == .seikei, word.questionType == "number" {
                let pool: [Vocabulary] = {
                    let numbers = allVocabPool.filter { $0.questionType == "number" }
                    if let cat = word.category {
                        let same = numbers.filter { $0.category == cat && $0.id != word.id }
                        if same.count >= 3 { return same }
                    }
                    return numbers.filter { $0.id != word.id }
                }()

                let answer = word.meaning
                let allowedNumberChoices: (String) -> Bool = { s in
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t == "前文" || (t.hasPrefix("第") && t.hasSuffix("条"))
                }

                let wrongs =
                    pool
                    .map { $0.meaning }
                    .filter { $0 != answer && allowedNumberChoices($0) }
                    .shuffled()

                var choices = [answer]
                choices.append(contentsOf: wrongs.prefix(3))
                choices = Array(Set(choices))
                if choices.count < 4 {
                    let fallback =
                        allVocabPool
                        .filter { $0.questionType == "number" }
                        .map { $0.meaning }
                        .filter { $0 != answer && allowedNumberChoices($0) }
                        .shuffled()
                    choices.append(contentsOf: fallback.prefix(max(0, 4 - choices.count)))
                    choices = Array(Set(choices))
                }
                choices = Array(choices.prefix(4)).shuffled()
                let correctIndex = choices.firstIndex(of: answer) ?? 0

                results.append(
                    Question(
                        id: word.id,
                        questionText: word.term,
                        answerText: answer,
                        hint: subject == .kobun
                            ? word.hint : (subject == .kanbun ? (word.reading ?? word.hint) : nil),
                        example: word.example,
                        choices: choices,
                        correctIndex: correctIndex,
                        fullText: word.fullText
                    )
                )
            } else if subject == .seikei, word.questionType == "era" {
                // Handle era name questions for nengou
                let pool: [Vocabulary] = {
                    let eras = allVocabPool.filter { $0.questionType == "era" }
                    if let cat = word.category {
                        let same = eras.filter { $0.category == cat && $0.id != word.id }
                        if same.count >= 3 { return same }
                    }
                    return eras.filter { $0.id != word.id }
                }()
                
                let answer = word.meaning
                let wrongs = pool
                    .map { $0.meaning }
                    .filter { $0 != answer && $0 != "不明" }
                    .shuffled()
                
                var choices = [answer]
                choices.append(contentsOf: wrongs.prefix(3))
                choices = Array(Set(choices))
                if choices.count < 4 {
                    let fallback = allVocabPool
                        .filter { $0.questionType == "era" }
                        .map { $0.meaning }
                        .filter { $0 != answer && $0 != "不明" }
                        .shuffled()
                    choices.append(contentsOf: fallback.prefix(max(0, 4 - choices.count)))
                    choices = Array(Set(choices))
                }
                choices = Array(choices.prefix(4)).shuffled()
                let correctIndex = choices.firstIndex(of: answer) ?? 0
                
                results.append(
                    Question(
                        id: word.id,
                        questionText: word.term,
                        answerText: answer,
                        hint: nil,
                        example: word.example,
                        choices: choices,
                        correctIndex: correctIndex,
                        fullText: word.fullText
                    )
                )
            } else {
                let otherWords = allVocabPool.filter { $0.id != word.id }.shuffled()
                var choices = [word.meaning]
                choices.append(contentsOf: otherWords.prefix(3).map { $0.meaning })
                choices.shuffle()
                let correctIndex = choices.firstIndex(of: word.meaning) ?? 0

                results.append(
                    Question(
                        id: word.id,
                        questionText: word.term,
                        answerText: word.meaning,
                        hint: subject == .kobun
                            ? word.hint : (subject == .kanbun ? (word.reading ?? word.hint) : nil),
                        example: word.example,
                        choices: choices,
                        correctIndex: correctIndex,
                        fullText: word.fullText
                    )
                )
            }

            if results.count >= count {
                break
            }
        }

        if results.count > count {
            return Array(results.prefix(count))
        }
        return results
    }

    // Parse Seikei content for quiz display
    private func parseSeikeiQuizContent(_ text: String) -> (String, [Int: String]) {
        var content = text
        var blankMap: [Int: String] = [:]
        var answerToId: [String: Int] = [:]
        var nextId = 1

        let pattern = "【([^】]+)】"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches.reversed() {
                if let answerRange = Range(match.range(at: 1), in: text),
                    let fullRange = Range(match.range, in: text)
                {
                    let answer = String(text[answerRange])
                    let id: Int
                    if let existing = answerToId[answer] {
                        id = existing
                    } else {
                        id = nextId
                        nextId += 1
                        answerToId[answer] = id
                        blankMap[id] = answer
                    }

                    content = content.replacingCharacters(in: fullRange, with: "[\(id)]")
                }
            }
        }

        return (content, blankMap)
    }

    private func blankCount(for question: Question) -> Int {
        if subject == .seikei, let fullText = question.fullText, !fullText.isEmpty {
            let (_, map) = cachedParseSeikeiQuizContent(fullText)
            return max(1, map.count)
        }
        return 1
    }

    private func timeLimitForQuestion(at index: Int) -> Int {
        guard timeLimit > 0 else { return 0 }
        guard subject == .seikei else { return timeLimit }
        guard questions.indices.contains(index) else { return timeLimit }
        let bc = blankCount(for: questions[index])
        return baseTimeLimit + max(0, (bc - 1) * 10)
    }

    private func selectAnswer(_ index: Int, correctIndex: Int) {
        // Prevent multiple scoring if user taps repeatedly before UI disables
        guard selectedAnswer == nil, !showResult, !isProcessingAnswer else { return }
        isProcessingAnswer = true

        let responseTime = max(0.0, CACurrentMediaTime() - questionStartTime)
        selectedAnswer = index
        isCorrect = index == correctIndex

        let question = questions[currentIndex]

        if question.choices.indices.contains(index) {
            lastChosenAnswerText = question.choices[index]
        }

        // Seikei blank spec: if any blank is wrong, treat the whole article as wrong
        if subject == .seikei, question.seikeiBlankId != nil, !isCorrect {
            failedSeikeiArticleIds.insert(question.id)
        }

        let effectiveIsCorrect: Bool = {
            if subject == .seikei, question.seikeiBlankId != nil {
                return isCorrect && !failedSeikeiArticleIds.contains(question.id)
            }
            return isCorrect
        }()

        // Haptic Feedback
        #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(isCorrect ? .success : .error)
        #endif

        if isCorrect {
            correctCount += 1
        } else {
            wrongCount += 1
            sessionIncorrectQuestions.append(question)
        }

        // Record mastery
        masteryTracker.recordAnswer(
            subject: subject.rawValue,
            wordId: question.id,
            isCorrect: effectiveIsCorrect,
            responseTime: responseTime,
            blankCount: blankCount(for: question),
            sessionId: sessionId,
            chosenAnswerText: lastChosenAnswerText,
            correctAnswerText: question.answerText
        )

        if subject == .seikei, let bid = question.seikeiBlankId {
            revealedSeikeiBlankId = bid
        }

        timerActive = false

        withAnimation(.spring(duration: 0.3)) {
            showResult = true
            showFeedbackOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackOverlayHideDelay) {
            withAnimation {
                self.showFeedbackOverlay = false
            }
        }

        // Auto Advance if correct
        if isCorrect {
            let currentIdx = currentIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + autoAdvanceDelay) {
                // Only advance if we are still on the same question
                if self.currentIndex == currentIdx {
                    withAnimation {
                        self.nextQuestion()
                    }
                }
            }
        }
        // NOTE: incorrect answers wait for user to review and tap Next
    }

    private func recordCardAnswer(isCorrect: Bool) {
        guard !isProcessingAnswer else { return }
        isProcessingAnswer = true
        let responseTime = max(0.0, CACurrentMediaTime() - questionStartTime)
        lastChosenAnswerText = isCorrect ? "わかった" : "わからない"
        self.isCorrect = isCorrect
        if isCorrect {
            correctCount += 1
        } else {
            wrongCount += 1
            sessionIncorrectQuestions.append(questions[currentIndex])
        }

        let question = questions[currentIndex]
        masteryTracker.recordAnswer(
            subject: subject.rawValue,
            wordId: question.id,
            isCorrect: isCorrect,
            responseTime: responseTime,
            blankCount: blankCount(for: question),
            sessionId: sessionId,
            chosenAnswerText: lastChosenAnswerText,
            correctAnswerText: question.answerText
        )

        timerActive = false

        withAnimation(.spring(duration: 0.3)) {
            showResult = true
            showFeedbackOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackOverlayHideDelay) {
            withAnimation {
                self.showFeedbackOverlay = false
            }
        }

        // Auto Advance if correct
        if isCorrect {
            let currentIdx = currentIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + autoAdvanceDelay) {
                if self.currentIndex == currentIdx {
                    withAnimation {
                        self.nextQuestion()
                    }
                }
            }
        }
    }

    private func skipQuestion() {
        guard !isProcessingAnswer else { return }
        isProcessingAnswer = true
        let responseTime = max(0.0, CACurrentMediaTime() - questionStartTime)
        lastChosenAnswerText = "スキップ"
        // Record as wrong for skipping
        wrongCount += 1
        let question = questions[currentIndex]
        sessionIncorrectQuestions.append(question)
        masteryTracker.recordAnswer(
            subject: subject.rawValue,
            wordId: question.id,
            isCorrect: false,
            responseTime: responseTime,
            blankCount: blankCount(for: question),
            sessionId: sessionId,
            chosenAnswerText: lastChosenAnswerText,
            correctAnswerText: question.answerText
        )

        timerActive = false

        withAnimation(.spring(duration: 0.3)) {
            showResult = true
            showFeedbackOverlay = true
            isCorrect = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackOverlayHideDelay) {
            withAnimation {
                self.showFeedbackOverlay = false
            }
        }
    }

    private func addCurrentWordToWordbook() {
        guard currentIndex < questions.count else { return }
        let question = questions[currentIndex]

        // Load existing wordbook
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
            let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data)
        {
            words = decoded
        }

        // Add new entry
        let newEntry = WordbookEntry(
            id: question.id,
            term: question.questionText,
            meaning: question.answerText,
            hint: question.hint,
            example: question.example,
            source: "クイズ",
            mastery: .new,
            subject: subject
        )

        let alreadyAdded = words.contains(where: { $0.id == question.id })

        if alreadyAdded {
            words.removeAll { $0.id == question.id }
        } else {
            words.append(newEntry)
        }

        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }

        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }

        wordbookRefreshNonce += 1
    }

    private func speakWord(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        // Set language based on subject
        switch subject {
        case .english:
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        }
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    private func nextQuestion() {
        timerActive = false
        showKobunHint = false
        showKanbunHint = false
        showResult = false
        selectedAnswer = nil
        typingAnswer = ""
        isCorrect = false
        showFeedbackOverlay = false
        showAnswer = false
        cardDragX = 0
        lastChosenAnswerText = ""
        isProcessingAnswer = false
        didDecideRechallengeForCurrent = false
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            questionStartTime = CACurrentMediaTime()
            revealedSeikeiBlankId = nil
            if timeLimit > 0 {
                timeRemaining = timeLimitForQuestion(at: currentIndex)
                timerActive = true
            }
        } else if !rechallengeQuestions.isEmpty, !isReviewRound {
            // Append scheduled rechallenge questions and continue session
            questions.append(contentsOf: rechallengeQuestions.shuffled())
            rechallengeQuestions = []
            isReviewRound = true

            currentIndex += 1
            questionStartTime = CACurrentMediaTime()
            revealedSeikeiBlankId = nil
            if timeLimit > 0 {
                timeRemaining = timeLimitForQuestion(at: currentIndex)
                timerActive = true
            }
        } else {
            // Quiz complete
            timerActive = false
            quizCompleted = true
            learningStats.recordStudyWords(
                subject: subject.rawValue,
                wordsStudied: questions.count
            )

            if isRankUpMode {
                // Check pass rate
                if rankUpManager.checkTestResult(
                    correctCount: correctCount, totalCount: questions.count)
                {
                    // Passed
                }
            }
        }
    }

    private func resetQuiz() {
        questions = []
        currentIndex = 0
        correctCount = 0
        wrongCount = 0
        quizCompleted = false
        showResult = false
        showAnswer = false
    }

    private func startReviewRound() {
        guard !sessionIncorrectQuestions.isEmpty else { return }

        // Use the incorrect questions for the new round
        questions = sessionIncorrectQuestions.shuffled()
        questionCount = questions.count

        // Reset for review round
        currentIndex = 0
        correctCount = 0
        wrongCount = 0
        quizCompleted = false
        showResult = false
        showAnswer = false
        cardDragX = 0
        isProcessingAnswer = false
        isRankUpMode = false

        // Clear mistakes list so we can track new mistakes from this round
        sessionIncorrectQuestions = []
        isReviewRound = true

        questionStartTime = CACurrentMediaTime()
        revealedSeikeiBlankId = nil
        failedSeikeiArticleIds = []

        if timeLimit > 0 {
            timeRemaining = timeLimitForQuestion(at: 0)
            timerActive = true
        }
    }

    private func currentChosenAnswerText() -> String? {
        lastChosenAnswerText
    }

    private func submitMistakeReport() {
        guard questions.indices.contains(currentIndex) else { return }

        guard let user = authManager.currentUser else {
            mistakeReportError = "ログインが必要です"
            return
        }
        guard let token = SupabaseAuthService.shared.session?.accessToken else {
            mistakeReportError = "セッションが取得できませんでした（再ログインしてください）"
            return
        }

        let q = questions[currentIndex]
        let chosen = currentChosenAnswerText()

        isSubmittingMistakeReport = true
        mistakeReportError = ""

        Task {
            defer { isSubmittingMistakeReport = false }
            do {
                try await SupabaseMistakeReportService.shared.submit(
                    userId: user.id,
                    subject: subject.rawValue,
                    wordId: q.id,
                    questionText: q.questionText,
                    correctAnswer: q.answerText,
                    chosenAnswer: chosen,
                    note: mistakeReportNote,
                    accessToken: token
                )
                showMistakeReportSheet = false
            } catch {
                mistakeReportError = "送信に失敗しました: \(error)"
            }
        }
    }
}

// MARK: - Question Model

struct Question: Identifiable {
    let id: String
    let questionText: String
    let answerText: String
    let hint: String?
    let example: String?
    let choices: [String]
    let correctIndex: Int
    var fullText: String? = nil  // For Seikei fill-in-blank questions
    var seikeiBlankId: Int? = nil
}

// MARK: - Reset Functions

private extension QuizView {
    func resetToDefaults() {
        mode = .fourChoice
        questionCount = 10
        masteryFilters = [.new, .weak, .learning, .almost]
        specialTrainingMode = false
        mistakesSessionMode = false
        isShuffleMode = false
        isSequentialMode = false
        chapterOrder = []
        currentChapterIndex = 0
        redSheetMode = false
        selectedChapters = ["すべて"]
        timeLimit = timerLimitSetting
        baseTimeLimit = timerLimitSetting
    }
}

// Previews removed for SPM

// MARK: - String Extensions (Inlined for reliability)

extension String {
    func levenshteinDistance(to destination: String) -> Int {
        let sourceArray = Array(self)
        let destinationArray = Array(destination)

        let sourceLength = sourceArray.count
        let destinationLength = destinationArray.count

        var matrix = [[Int]](
            repeating: [Int](repeating: 0, count: destinationLength + 1), count: sourceLength + 1)

        for i in 0...sourceLength {
            matrix[i][0] = i
        }

        for j in 0...destinationLength {
            matrix[0][j] = j
        }

        for i in 1...sourceLength {
            for j in 1...destinationLength {
                if sourceArray[i - 1] == destinationArray[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = Swift.min(
                        matrix[i - 1][j] + 1,  // deletion
                        matrix[i][j - 1] + 1,  // insertion
                        matrix[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }

        return matrix[sourceLength][destinationLength]
    }

    func isFuzzyMatch(to other: String, tolerance: Double = 0.2) -> Bool {
        let s1 = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2 = other.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if s1 == s2 { return true }

        let distance = s1.levenshteinDistance(to: s2)
        let maxLength = Double(max(s1.count, s2.count))

        // Avoid division by zero
        if maxLength == 0 { return s1 == s2 }

        return Double(distance) / maxLength <= tolerance
    }
}

struct OverlayFeedbackView: View {
    let isCorrect: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack {
                Image(systemName: isCorrect ? "circle.circle" : "xmark.circle")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(isCorrect ? .green : .red)
                    .symbolEffect(.bounce, value: isCorrect)

                Text(isCorrect ? "正解!" : "不正解...")
                    .font(.largeTitle.bold())
                    .foregroundStyle(isCorrect ? .white : .white)
                    .shadow(radius: 2)
            }
            .padding(40)
            .liquidGlass()
            .shadow(radius: 10)
        }
    }
}
