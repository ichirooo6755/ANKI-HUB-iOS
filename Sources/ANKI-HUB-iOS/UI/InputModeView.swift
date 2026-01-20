import SwiftUI
import UserNotifications
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Speech)
import Speech
#endif

struct InputModeView: View {
    @StateObject private var manager = InputModeManager.shared
    @StateObject private var vocabData = VocabularyData.shared

    @ObservedObject private var theme = ThemeManager.shared

    @AppStorage("anki_hub_kobun_inputmode_use_all_v1") private var kobunInputModeUseAll: Bool =
        true
    @AppStorage("anki_hub_inputmode_day2_limit_v1") private var day2TimeLimitSetting: Double = 3.0
    @AppStorage("anki_hub_inputmode_day2_unknown_only_v1") private var day2UnknownOnly: Bool = true
    @AppStorage("anki_hub_inputmode_mistakes_only_v1") private var inputModeMistakesOnly: Bool = false

    @State private var selectedSubject: Subject = .kobun
    @State private var selectedBlockIndex: Int = 0

    @State private var words: [Vocabulary] = []
    @State private var currentIndex = 0
    @State private var startTime = Date()
    @State private var showResult = false

    // Day 2 Flip State
    @State private var isCardFlipped = false

    // Day 3 Reveal
    @State private var showDay3Answer = false

    @StateObject private var transcriber = CustomSpeechTranscriber()
    @State private var showSpeechPermissionAlert = false
    @State private var speechPermissionMessage = ""
    
    // Shuffle mode
    @State private var isShuffleMode: Bool = false

    @State private var wordbookRefreshNonce: Int = 0

    // Day 2 Timer
    @State private var timeRemaining: Double = 1.0
    @State private var limitSeconds: Double = 3.0

    private struct RecentMistake: Codable {
        let subject: String
        let wordId: String
        let term: String
        let answer: String
        let chosen: String?
        let date: Date
    }

    var body: some View {
        ZStack {
            theme.background

            if showResult {
                InputResultView(
                    day: manager.currentDay,
                    count: words.count,
                    onNextDay: {
                        if manager.currentDay < 3 {
                            manager.currentDay += 1
                        } else {
                            manager.currentDay = 1  // Reset or finish
                        }
                        loadWords()
                    },
                    onRetry: {
                        loadWords()
                    }
                )
            } else if words.isEmpty {
                emptyWordSelectionView
            } else {
                InputModeSessionView(
                    manager: manager,
                    words: words,
                    currentIndex: $currentIndex,
                    isCardFlipped: $isCardFlipped,
                    showDay3Answer: $showDay3Answer,
                    selectedSubject: selectedSubject,
                    speechTranscriber: transcriber,
                    timeRemaining: timeRemaining,
                    onProcessDay1: { known in
                        processDay1(known: known)
                    },
                    onProcessDay2: { correct in
                        processDay2(correct: correct)
                    },
                    onProcessDay3: { correct in
                        processDay3(correct: correct)
                    },
                    onBookmark: {
                        addCurrentWordToWordbook()
                    },
                    isBookmarked: isCurrentWordBookmarked,
                    onToggleSpeechRecording: {
                        toggleSpeechRecording()
                    },
                    onSessionComplete: {
                        showResult = true
                    }
                )
            }
        }
        .onAppear {
            loadWords()
        }
        .onChange(of: selectedSubject) { _, _ in
            selectedBlockIndex = 0
            loadWords()
        }
        .onChange(of: selectedBlockIndex) { _, _ in
            loadWords()
        }
        .onChange(of: inputModeMistakesOnly) { _, _ in
            selectedBlockIndex = 0
            loadWords()
        }
        .onChange(of: isShuffleMode) { _, _ in
            loadWords()
        }
        .onChange(of: kobunInputModeUseAll) { _, _ in
            loadWords()
        }
        .task(id: startTime) {
            guard manager.currentDay == 2 else { return }
            guard !showResult else { return }
            guard currentIndex < words.count else { return }

            let tickNanoseconds: UInt64 = 200_000_000
            while manager.currentDay == 2, !showResult, currentIndex < words.count {
                do {
                    try await Task.sleep(nanoseconds: tickNanoseconds)
                } catch {
                    break
                }
                guard manager.currentDay == 2, !showResult, currentIndex < words.count else { break }

                let elapsed = Date().timeIntervalSince(startTime)
                let remaining = max(0, limitSeconds - elapsed)
                let fraction = limitSeconds > 0 ? max(0, min(1, remaining / limitSeconds)) : 0
                timeRemaining = fraction

                if remaining <= 0 {
                    break
                }
            }
        }
        .alert("音声認識の許可", isPresented: $showSpeechPermissionAlert) {
            Button("設定", action: {
                #if canImport(UIKit)
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
                #endif
            })
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text(speechPermissionMessage)
        }
        .onDisappear {
            transcriber.stopTranscribing()
        }
        .applyAppTheme()
    }
    
    private var emptyWordSelectionView: some View {
        ScrollView {
            VStack {
                Text("\(manager.currentDay)日目")
                    .font(.largeTitle)
                    .bold()

                let allWords = vocabData.getVocabulary(for: selectedSubject)
                let filteredWords: [Vocabulary] = {
                    if inputModeMistakesOnly {
                        let ids = recentMistakeIds(for: selectedSubject)
                        return allWords.filter { ids.contains($0.id) }
                    }
                    return allWords
                }()

                let cappedWords: [Vocabulary] = {
                    if selectedSubject == .kobun {
                        return kobunInputModeUseAll ? filteredWords : Array(filteredWords.prefix(350))
                    }
                    return filteredWords
                }()
                let totalBlocks = Int(ceil(Double(cappedWords.count) / 50.0))
                if cappedWords.isEmpty {
                    Text("チャプターを表示できません（単語が0件）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                } else {
                    Picker("チャプター", selection: $selectedBlockIndex) {
                        ForEach(0..<totalBlocks, id: \.self) { i in
                            let start = i * 50 + 1
                            let end = min((i + 1) * 50, cappedWords.count)
                            Text("チャプター \(i + 1)（\(start)-\(end)）").tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.bottom, 8)
                    .onAppear {
                        if selectedBlockIndex >= totalBlocks {
                            selectedBlockIndex = max(0, totalBlocks - 1)
                        }
                    }
                    .onChange(of: totalBlocks) { _, newValue in
                        if selectedBlockIndex >= newValue {
                            selectedBlockIndex = max(0, newValue - 1)
                        }
                    }
                }

                Picker("教科", selection: $selectedSubject) {
                    ForEach(Subject.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Toggle(isOn: $inputModeMistakesOnly) {
                    Text("間違えた単語だけ")
                }
                .padding(.horizontal)
                
                Toggle(isOn: $isShuffleMode) {
                    HStack {
                        Image(systemName: "shuffle")
                            .foregroundStyle(
                                theme.currentPalette.color(
                                    .accent, isDark: theme.effectiveIsDark))
                        Text("出題順をシャッフル")
                    }
                }
                .padding(.horizontal)
                
                if selectedSubject == .kobun {
                    Toggle(isOn: $kobunInputModeUseAll) {
                        Text("全単語を使用")
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    startNewSession()
                }) {
                    Text("開始")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding()
        }
    }
    
    private var accentColor: Color {
        theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
    }

    private func loadWords() {
        transcriber.stopTranscribing()
        transcriber.transcript = ""
        showResult = false
        currentIndex = 0
        showDay3Answer = false
        let allWordsRaw = vocabData.getVocabulary(for: selectedSubject)
        let filteredWords: [Vocabulary] = {
            if inputModeMistakesOnly {
                let ids = recentMistakeIds(for: selectedSubject)
                return allWordsRaw.filter { ids.contains($0.id) }
            }
            return allWordsRaw
        }()

        let allWords: [Vocabulary] = {
            if selectedSubject == .kobun {
                return kobunInputModeUseAll ? filteredWords : Array(filteredWords.prefix(350))
            }
            return filteredWords
        }()
        let start = max(0, selectedBlockIndex * 50)
        let end = min(start + 50, allWords.count)
        let blockWords = (start < end) ? Array(allWords[start..<end]) : []

        if manager.currentDay == 2 {
            words = day2UnknownOnly ? manager.getWordsForDay(2, allWords: blockWords) : blockWords
        } else {
            words = manager.getWordsForDay(manager.currentDay, allWords: blockWords)
        }
        
        // Apply shuffle mode if enabled
        if isShuffleMode {
            words.shuffle()
        }

        // Setup Day 2 timer
        if manager.currentDay == 2 {
            startTimer()
        }
    }
    
    private func startNewSession() {
        startTime = Date()
        loadWords()
    }

    private func recentMistakeIds(for subject: Subject) -> Set<String> {
        let listKey = "anki_hub_recent_mistakes_v1"

        let primaryDefaults = UserDefaults.standard
        let appGroupDefaults = UserDefaults(suiteName: "group.com.ankihub.ios")

        let candidates: [UserDefaults?] = [primaryDefaults, appGroupDefaults]
        for defaults in candidates {
            guard let defaults else { continue }
            guard let data = defaults.data(forKey: listKey) else { continue }
            guard let decoded = try? JSONDecoder().decode([RecentMistake].self, from: data) else {
                continue
            }
            let filtered = decoded.filter { $0.subject == subject.rawValue }
            return Set(filtered.map(\.wordId))
        }
        return []
    }

    private func toggleSpeechRecording() {
        if transcriber.isRecording {
            transcriber.stopTranscribing()
        } else {
            Task {
                let allowed = await transcriber.ensureAuthorization()
                if allowed {
                    transcriber.startTranscribing()
                } else {
                    speechPermissionMessage = transcriber.errorMessage
                        ?? "音声認識とマイクの許可を設定してください。"
                    showSpeechPermissionAlert = true
                }
            }
        }
    }
    private func startTimer() {
        limitSeconds = day2TimeLimitSetting
        timeRemaining = 1.0
        startTime = Date()
    }

    private func nextWord() {
        withAnimation {
            isCardFlipped = false
            showDay3Answer = false
            if currentIndex < words.count - 1 {
                currentIndex += 1
                if manager.currentDay == 2 {
                    startTimer()
                }
            } else {
                showResult = true
                LearningStats.shared.recordStudyWords(
                    subject: selectedSubject.rawValue,
                    wordsStudied: words.count
                )
            }
        }
    }

    private func processDay1(known: Bool) {
        manager.processDay1(wordId: words[currentIndex].id, isKnown: known)
        nextWord()
    }

    private func processDay2(correct: Bool) {
        let responseTime = Date().timeIntervalSince(startTime)
        manager.processDay2(
            wordId: words[currentIndex].id,
            isCorrect: correct,
            responseTime: responseTime
        )
        nextWord()
    }

    private func processDay3(correct: Bool) {
        manager.processDay3(wordId: words[currentIndex].id, isCorrect: correct)
        nextWord()
    }

    private func addCurrentWordToWordbook() {
        guard words.indices.contains(currentIndex) else { return }
        let vocab = words[currentIndex]

        var stored: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            stored = decoded
        }

        let newEntry = WordbookEntry(
            id: vocab.id,
            term: vocab.term,
            meaning: vocab.meaning,
            hint: vocab.hint,
            example: vocab.example,
            source: "インプットモード",
            mastery: .new,
            subject: selectedSubject
        )

        if !stored.contains(where: { $0.id == newEntry.id }) {
            stored.append(newEntry)
            if let data = try? JSONEncoder().encode(stored) {
                UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
            }
            wordbookRefreshNonce += 1
            Task { @MainActor in
                SyncManager.shared.requestAutoSync()
            }
        }
    }

    private var isCurrentWordBookmarked: Bool {
        _ = wordbookRefreshNonce
        guard words.indices.contains(currentIndex) else { return false }
        let vocab = words[currentIndex]

        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            return decoded.contains(where: { $0.id == vocab.id })
        }
        return false
    }
}

struct InputModeSessionView: View {
    @ObservedObject var manager: InputModeManager
    let words: [Vocabulary]
    @Binding var currentIndex: Int
    @Binding var isCardFlipped: Bool
    @Binding var showDay3Answer: Bool
    let selectedSubject: Subject
    @ObservedObject var speechTranscriber: CustomSpeechTranscriber
    let timeRemaining: Double
    let onProcessDay1: (Bool) -> Void
    let onProcessDay2: (Bool) -> Void
    let onProcessDay3: (Bool) -> Void
    let onBookmark: () -> Void
    let isBookmarked: Bool
    let onToggleSpeechRecording: () -> Void
    let onSessionComplete: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            headerView

            if manager.currentDay == 2 {
                timerView
            }

            Spacer()

            if let word = currentWord {
                switch manager.currentDay {
                case 1:
                    day1View(for: word)
                case 2:
                    day2View(for: word)
                default:
                    day3View(for: word)
                }
            } else {
                Button("結果を見る") {
                    onSessionComplete()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }

    private var currentWord: Vocabulary? {
        guard words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    private var headerView: some View {
        HStack {
            Text("\(manager.currentDay)日目")
                .font(.headline)
                .padding(8)
                .liquidGlass()

            Spacer()

            Text(selectedSubject.displayName)
                .font(.caption)
                .padding(6)
                .liquidGlass()

            Text("\(min(currentIndex + 1, max(1, words.count))) / \(words.count)")
        }
    }

    private var timerView: some View {
        VStack(spacing: 8) {
            ProgressView(value: timeRemaining)
                .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            Text("タイムリミット")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal)
    }

    private func day1View(for word: Vocabulary) -> some View {
        let danger = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let ok = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)

        return VStack(spacing: 24) {
            Text(word.term)
                .font(.system(size: 40, weight: .bold))

            Text(word.meaning)
                .font(.title3)
                .foregroundStyle(theme.primaryText)
                .opacity(theme.effectiveIsDark ? 0.95 : 0.85)

            HStack(spacing: 32) {
                Button(action: { onProcessDay1(false) }) {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(danger)
                        Text("わからない")
                            .foregroundStyle(theme.primaryText)
                    }
                }

                Button(action: { onProcessDay1(true) }) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ok)
                        Text("わかる")
                            .foregroundStyle(theme.primaryText)
                    }
                }
            }

            Button(action: { onBookmark() }) {
                HStack(spacing: 8) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    Text("単語帳に追加")
                        .foregroundStyle(theme.primaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .liquidGlass()
    }

    private func day2View(for word: Vocabulary) -> some View {
        FlashcardView(
            vocabulary: word,
            subject: selectedSubject,
            isFlipped: $isCardFlipped,
            showsHintOnFront: false,
            showsHintOnBack: true,
            showsReadingOnBack: false,
            onSwipeLeft: { onProcessDay2(false) },
            onSwipeRight: { onProcessDay2(true) },
            onBookmark: { onBookmark() },
            isBookmarked: isBookmarked
        )
    }

    private func day3View(for word: Vocabulary) -> some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let danger = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let ok = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let hint = word.hint ?? ""
        let reading = word.reading ?? ""

        return VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text(word.term)
                    .font(.system(size: 36, weight: .bold))

                if showDay3Answer {
                    VStack(spacing: 8) {
                        Text(word.meaning)
                            .font(.title3.bold())
                            .foregroundStyle(theme.primaryText)

                        if !hint.isEmpty {
                            Text(hint)
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        }

                        if !reading.isEmpty {
                            Text(reading)
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                } else {
                    Text("タップで答えを表示")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding()
            .liquidGlass(cornerRadius: 16)
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showDay3Answer.toggle()
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(accent)
                    Text("音声入力で発音確認")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Button(action: { onToggleSpeechRecording() }) {
                    Label(
                        speechTranscriber.isRecording ? "録音停止" : "録音開始",
                        systemImage: speechTranscriber.isRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                if speechTranscriber.isRecording {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("録音中...")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                if !speechTranscriber.transcript.isEmpty {
                    Text(speechTranscriber.transcript)
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 14)
                }
            }

            HStack(spacing: 12) {
                Button(action: { onProcessDay3(false) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(danger)
                        Text("まだ苦手")
                            .foregroundStyle(theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .liquidGlass(cornerRadius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(danger.opacity(0.35), lineWidth: 2)
                    )
                }

                Button(action: { onProcessDay3(true) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ok)
                        Text("覚えた")
                            .foregroundStyle(theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .liquidGlass(cornerRadius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ok.opacity(0.35), lineWidth: 2)
                    )
                }
            }

            Button(action: { onBookmark() }) {
                HStack(spacing: 8) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(accent)
                    Text("単語帳に追加")
                        .foregroundStyle(theme.primaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

struct InputResultView: View {
    let day: Int
    let count: Int
    let onNextDay: () -> Void
    let onRetry: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        VStack(spacing: 30) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(primary)

            Text("\(day)日目 完了！")
                .font(.title)
                .bold()

            Text("\(count)語を処理しました")
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button("もう一度") {
                    onRetry()
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlass(cornerRadius: 12)

                Button("次の日へ") {
                    onNextDay()
                }
                .font(.headline)
                .foregroundStyle(theme.onColor(for: primary))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(40)
        .liquidGlass()
    }
}
