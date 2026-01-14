import SwiftUI

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

    @State private var sessionStartTime = Date()

    // Day 2 Flip State
    @State private var isCardFlipped = false

    // Day 3 Reveal
    @State private var showDay3Answer = false
    
    // Shuffle mode
    @State private var isShuffleMode: Bool = false

    // Day 2 Timer
    @State private var timeRemaining: CGFloat = 1.0
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
                        let totalBlocks = max(1, Int(ceil(Double(cappedWords.count) / 50.0)))
                        Picker("チャプター", selection: $selectedBlockIndex) {
                            ForEach(0..<totalBlocks, id: \.self) { i in
                                let start = i * 50 + 1
                                let end = min((i + 1) * 50, cappedWords.count)
                                Text("チャプター \(i + 1)（\(start)-\(end)）").tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.bottom, 8)

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

                        Button {
                            isShuffleMode = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle")
                                    .foregroundStyle(
                                        theme.currentPalette.color(
                                            .primary, isDark: theme.effectiveIsDark))
                                Text("デフォルトに戻す")
                            }
                        }
                        .padding(.horizontal)

                        // Day 2 Timer Setting
                        if manager.currentDay == 2 {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundStyle(
                                            theme.currentPalette.color(
                                                .accent, isDark: theme.effectiveIsDark))
                                    Text("制限時間: \(String(format: "%.1f", day2TimeLimitSetting))秒")
                                }
                                .font(.headline)

                                Slider(value: $day2TimeLimitSetting, in: 1.0...5.0, step: 0.5)
                                    .tint(
                                        theme.currentPalette.color(
                                            .accent, isDark: theme.effectiveIsDark))

                                Toggle(isOn: $day2UnknownOnly) {
                                    Text("2日目は1日目で「わからない」のみ")
                                }
                            }
                            .padding()
                            .liquidGlass()
                            .padding(.horizontal)
                        }

                        Text("この日の未処理単語はありません")
                            .padding()
                        Button("開始") {
                            manager.currentDay = 1
                            loadWords()
                        }
                    }
                    .padding(.vertical, 12)
                }
            } else if currentIndex < words.count {
                VStack {
                    // Header
                    HStack {
                        Text("\(manager.currentDay)日目")
                            .font(.headline)
                            .padding(8)
                            .liquidGlass()

                        Spacer()

                        Button {
                            addCurrentWordToWordbook()
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    theme.currentPalette.color(
                                        .accent, isDark: theme.effectiveIsDark))
                                .frame(width: 56, height: 56)
                                .liquidGlassCircle()
                        }
                        .buttonStyle(.plain)

                        Text(selectedSubject.displayName)
                            .font(.caption)
                            .padding(6)
                            .liquidGlass()

                        Text("\(currentIndex + 1) / \(words.count)")
                    }
                    .padding()

                    // Timer Circle (Day 2 Only)
                    if manager.currentDay == 2 {
                        let border = theme.currentPalette.color(
                            .border, isDark: theme.effectiveIsDark)
                        let primary = theme.currentPalette.color(
                            .primary, isDark: theme.effectiveIsDark)
                        let danger = theme.currentPalette.color(
                            .weak, isDark: theme.effectiveIsDark)
                        ZStack {
                            Circle()
                                .stroke(border.opacity(0.35), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: timeRemaining)
                                .stroke(timeRemaining > 0.3 ? primary : danger, lineWidth: 10)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.2), value: timeRemaining)
                        }
                        .frame(width: 60, height: 60)
                        .padding()
                    }

                    Spacer()

                    // Main Card Interaction
                    let word = words[currentIndex]

                    if manager.currentDay == 1 {
                        // Day 1: Sorting (Known/Unknown buttons)
                        VStack(spacing: 30) {
                            Text(word.term)
                                .font(.system(size: 40, weight: .bold))

                            Text(word.meaning)
                                .font(.title3)
                                .foregroundStyle(theme.primaryText)
                                .opacity(theme.effectiveIsDark ? 0.95 : 0.85)

                            HStack(spacing: 40) {
                                let danger = theme.currentPalette.color(
                                    .weak, isDark: theme.effectiveIsDark)
                                let ok = theme.currentPalette.color(
                                    .mastered, isDark: theme.effectiveIsDark)
                                Button(action: { processDay1(known: false) }) {
                                    VStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(danger)
                                        Text("わからない")
                                    }
                                }

                                Button(action: { processDay1(known: true) }) {
                                    VStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(ok)
                                        Text("わかる")
                                    }
                                }
                            }
                        }
                        .padding()
                        .liquidGlass()
                        .padding()

                    } else if manager.currentDay == 2 {
                        // Day 2: Speed Flashcard (Swipe)
                        FlashcardView(
                            vocabulary: word,
                            subject: selectedSubject,
                            isFlipped: $isCardFlipped,
                            showsHintOnFront: false,
                            showsHintOnBack: true,
                            showsReadingOnBack: false,
                            onSwipeLeft: {
                                processDay2(correct: false)
                            },
                            onSwipeRight: {
                                processDay2(correct: true)
                            }
                        )

                    } else {
                        // Day 3: Check/Fixation
                        // Similar to Day 1 but for "weak" words
                        VStack(spacing: 30) {
                            Text(word.term)
                                .font(.system(size: 40, weight: .bold))

                            Group {
                                if showDay3Answer {
                                    VStack(spacing: 12) {
                                        Text(word.meaning)
                                            .font(.title3.bold())
                                            .foregroundStyle(theme.primaryText)
                                            .multilineTextAlignment(.center)

                                        let sub = [word.hint, word.reading].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
                                        if !sub.isEmpty {
                                            Text(sub)
                                                .font(.subheadline)
                                                .foregroundStyle(theme.secondaryText)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .padding()
                                    .liquidGlass(cornerRadius: 16)
                                } else {
                                    Text("タップで答えを表示（音読）")
                                        .padding()
                                        .liquidGlass(cornerRadius: 16)
                                }
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    showDay3Answer.toggle()
                                }
                            }

                            HStack(spacing: 40) {
                                let danger = theme.currentPalette.color(
                                    .weak, isDark: theme.effectiveIsDark)
                                let ok = theme.currentPalette.color(
                                    .mastered, isDark: theme.effectiveIsDark)
                                Button(action: { processDay3(correct: false) }) {
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

                                Button(action: { processDay3(correct: true) }) {
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
                        }
                        .padding()
                        .liquidGlass()
                    }

                    Spacer()
                }
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
                timeRemaining = CGFloat(fraction)

                if remaining <= 0 {
                    break
                }
            }
        }
        .applyAppTheme()
    }

    private func loadWords() {
        showResult = false
        currentIndex = 0
        showDay3Answer = false
        sessionStartTime = Date()
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

    private func recentMistakeIds(for subject: Subject) -> Set<String> {
        let listKey = "anki_hub_recent_mistakes_v1"

        let primaryDefaults = UserDefaults.standard
        let appGroupDefaults = UserDefaults(suiteName: "group.com.ankihub.ios")

        let candidates: [UserDefaults?] = [primaryDefaults, appGroupDefaults]
        for defaults in candidates {
            guard let defaults else { continue }
            guard let data = defaults.data(forKey: listKey) else { continue }
            guard let list = try? JSONDecoder().decode([RecentMistake].self, from: data) else { continue }
            let ids = list
                .filter { $0.subject == subject.rawValue }
                .map { $0.wordId }
            if !ids.isEmpty {
                return Set(ids)
            }
        }

        return []
    }

    private func startTimer() {
        limitSeconds = day2TimeLimitSetting
        timeRemaining = 1.0
        startTime = Date()
    }

    private func nextWord() {
        withAnimation {
            isCardFlipped = false  // Reset flip
            showDay3Answer = false
            if currentIndex < words.count - 1 {
                currentIndex += 1
                if manager.currentDay == 2 {
                    startTimer()
                }
            } else {
                showResult = true

                let elapsed = max(0.0, Date().timeIntervalSince(sessionStartTime))
                let minutes = max(1, Int(ceil(elapsed / 60.0)))
                LearningStats.shared.recordStudySession(
                    subject: selectedSubject.rawValue,
                    wordsStudied: words.count,
                    minutes: minutes
                )
            }
        }
    }

    // Logic Wrappers

    private func processDay1(known: Bool) {
        manager.processDay1(wordId: words[currentIndex].id, isKnown: known)
        nextWord()
    }

    private func processDay2(correct: Bool) {
        let responseTime = Date().timeIntervalSince(startTime)
        manager.processDay2(
            wordId: words[currentIndex].id, isCorrect: correct, responseTime: responseTime)
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
            mastery: .new,
            subject: selectedSubject
        )

        if !stored.contains(where: { $0.id == newEntry.id }) {
            stored.append(newEntry)
            if let data = try? JSONEncoder().encode(stored) {
                UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
            }
            Task { @MainActor in
                SyncManager.shared.requestAutoSync()
            }
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
