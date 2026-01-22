import SwiftUI

/// Focused Memorization View (InputMode)
/// Matches the web app's input_mode.html with:
/// - 3 Day modes (1日目 3s, 2日目 2s, 3日目 1s)
/// - Block selection (50 words each)
/// - Circular timer countdown
/// - Weak word reprocessing (Day 2)
/// - Swipe-enabled flashcards
struct FocusedMemorizationView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var theme = ThemeManager.shared

    private let subjectOptions: [Subject] = [.english, .kobun]
    
    // MARK: - State
    @State private var currentScreen: ScreenState = .daySelect
    @State private var currentDay: Int = 1
    @State private var currentBlockIndex: Int = 0
    @State private var words: [Vocabulary] = []
    @State private var currentWordIndex: Int = 0
    @State private var knownCount: Int = 0
    @State private var unknownCount: Int = 0
    @State private var weakWords: [Vocabulary] = []
    @State private var isFlipped: Bool = false

    @State private var cardDragX: CGFloat = 0
    @State private var isSwipeLocked: Bool = false
    
    // Timer
    @State private var timeRemaining: Double = 3.0
    @State private var totalTime: Double = 3.0
    @State private var timerActive: Bool = false
    
    // Settings
    @State private var showSettings: Bool = false
    @AppStorage("anki_hub_inputmode_day2_seconds_v1") private var day2Seconds: Double = 1.5
    @AppStorage("anki_hub_inputmode_day3_seconds_v1") private var day3Seconds: Double = 1.0
    @AppStorage("anki_hub_inputmode_day2_unknown_only_v1") private var day2UnknownOnly: Bool = false

    // Day1 unknown persistence (per subject+block)
    @AppStorage("input_mode_day1_unknown_ids_v1") private var day1UnknownIdsData: Data = Data()

    @State private var noWordsAlertMessage: String = ""
    @State private var showNoWordsAlert: Bool = false

    @State private var selectedSubject: Subject
    
    // Progress persistence
    @AppStorage("input_mode_block_completions") private var blockCompletionsData: Data = Data()
    @AppStorage("anki_hub_kobun_inputmode_use_all_v1") private var kobunInputModeUseAll: Bool = true
    @AppStorage("anki_hub_kobun_inputmode_use_all_migrated_v1")
    private var kobunInputModeUseAllMigrated: Bool = false
    
    enum ScreenState {
        case daySelect
        case blockSelect
        case study
        case weakReprocess
        case result
    }

    private func migrateKobunInputModeSettingIfNeeded() {
        guard !kobunInputModeUseAllMigrated else { return }
        let kobunCount = VocabularyData.shared.getVocabulary(for: .kobun).count
        if kobunCount > 350 {
            kobunInputModeUseAll = true
        }
        kobunInputModeUseAllMigrated = true
    }

    private func handleSwipeAnswer(known: Bool) {
        isSwipeLocked = true
        let direction: CGFloat = known ? 1 : -1

        if reduceMotion {
            // Reduce Motion: Skip large movement animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                recordAnswer(known: known)
                cardDragX = 0
                isSwipeLocked = false
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                cardDragX = direction * 500
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                recordAnswer(known: known)
                withAnimation(.spring(response: 0.25)) {
                    cardDragX = 0
                }
                isSwipeLocked = false
            }
        }
    }
    
    let blockSize = 50

    private var inputModeVocab: [Vocabulary] {
        let vocab = VocabularyData.shared.getVocabulary(for: selectedSubject)
        if selectedSubject == .kobun {
            return kobunInputModeUseAll ? vocab : Array(vocab.prefix(350))
        }
        return vocab
    }

    var totalBlocks: Int {
        max(1, Int(ceil(Double(inputModeVocab.count) / Double(blockSize))))
    }

    init(subject: Subject = .kobun) {
        _selectedSubject = State(initialValue: subject)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                
                switch currentScreen {
                case .daySelect:
                    daySelectView
                case .blockSelect:
                    blockSelectView
                case .study:
                    studyView
                case .weakReprocess:
                    weakReprocessView
                case .result:
                    resultView
                }
            }
            .navigationTitle("集中暗記")
            .alert("対象がありません", isPresented: $showNoWordsAlert) {
                Button("OK") {}
            } message: {
                Text(noWordsAlertMessage)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
        }
        .applyAppTheme()
        .onAppear {
            migrateKobunInputModeSettingIfNeeded()
        }
        .task(id: timerActive) {
            guard timerActive, totalTime > 0 else { return }
            let tick: Double = 0.1
            while timerActive, totalTime > 0 {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    break
                }
                guard timerActive, totalTime > 0 else { break }
                if timeRemaining > tick {
                    timeRemaining -= tick
                } else {
                    // Auto mark as unknown on timeout
                    recordAnswer(known: false)
                    break
                }
            }
        }
    }
    
    // MARK: - Day Select View
    
    private var daySelectView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                Text("インプットモード")
                    .font(.largeTitle.weight(.bold))

                Picker("教科", selection: $selectedSubject) {
                    ForEach(subjectOptions) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Progress Summary
                VStack(spacing: 8) {
                    HStack(spacing: 24) {
                        statItem(value: getKnownTotal(), label: "わかる", color: .green)
                        statItem(value: getUnknownTotal(), label: "わからない", color: .red)
                        statItem(value: getNewTotal(), label: "未処理", color: .gray)
                    }
                }
                .padding()
                .liquidGlass()
                .padding(.horizontal)

                SubjectMasteryChart(subject: selectedSubject, masteryTracker: masteryTracker)
                    .padding(.horizontal)

                // Day Buttons
                VStack(spacing: 12) {
                    dayButton(
                        day: 1,
                        icon: "sun.max.fill",
                        title: "1日目",
                        subtitle: "時間制限なし",
                        gradient: [.orange, .yellow]
                    )
                    dayButton(
                        day: 2,
                        icon: "bolt.fill",
                        title: "2日目",
                        subtitle: "\(String(format: "%.1f", day2Seconds))秒/語",
                        gradient: [.yellow, .orange]
                    )
                    dayButton(
                        day: 3,
                        icon: "mic.fill",
                        title: "3日目",
                        subtitle: "\(String(format: "%.1f", day3Seconds))秒/語",
                        gradient: [.purple, .indigo]
                    )
                }
                .padding(.horizontal)

                Button("進捗をリセット") {
                    resetProgress()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private func dayButton(day: Int, icon: String, title: String, subtitle: String, gradient: [Color]) -> some View {
        Button {
            currentDay = day
            currentScreen = .blockSelect
        } label: {
            let fg = theme.onColor(for: gradient.first ?? theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(title)
                        .font(.headline.weight(.semibold))
                }
                Spacer()
                Text(subtitle)
                    .font(.footnote)
                    .monospacedDigit()
                    .opacity(0.8)
            }
            .foregroundStyle(fg)
            .padding()
            .background(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    @ViewBuilder
    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Block Select View
    
    private var blockSelectView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(dayLabel(currentDay))
                    .font(.title2.weight(.bold))

                Text("ブロックを選択（各50語）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Block Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(0..<totalBlocks, id: \.self) { index in
                        let completionCount = getBlockCompletionCount(day: currentDay, block: index)
                        let highlight = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                        Button {
                            startBlock(index)
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.callout.weight(.semibold))
                                    .monospacedDigit()
                                if completionCount > 0 {
                                    Text("\(completionCount)回")
                                        .font(.footnote.weight(.medium))
                                        .monospacedDigit()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
                                    .opacity(theme.effectiveIsDark ? 0.55 : 0.7)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(completionCount > 0 ? highlight.opacity(0.18) : Color.clear)
                            )
                            .foregroundStyle(completionCount > 0 ? highlight : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(completionCount > 0 ? highlight : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal)

                Button("戻る") {
                    currentScreen = .daySelect
                }
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            .padding(.top)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Study View
    
    private var studyView: some View {
        VStack(spacing: 16) {
            // Progress Bar
            ProgressView(value: Double(currentWordIndex + 1), total: Double(words.count))
                .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                .accessibilityLabel(Text("学習進捗"))
                .accessibilityValue(Text("\(currentWordIndex + 1) / \(words.count)"))
                .accessibilityHint(Text("現在の学習位置"))
                .padding(.horizontal)
            
            HStack {
                Text("\(currentWordIndex + 1) / \(words.count)")
                    .font(.callout)
                    .monospacedDigit()
                Spacer()
                Text("ブロック \(currentBlockIndex + 1)")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            // Circular Timer
            if totalTime > 0 {
                CircularTimerView(remaining: timeRemaining, total: totalTime)
                    .frame(width: 80, height: 80)
            } else {
                Text("時間制限なし")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            // Flashcard
            if currentWordIndex < words.count {
                let word = words[currentWordIndex]
                ZStack {
                    FlashcardInputView(
                        word: word.term,
                        hint: word.hint ?? "",
                        meaning: word.meaning,
                        isFlipped: $isFlipped,
                        showsHintWithAnswer: true
                    )
                    .frame(height: 180)

                    let okOpacity = min(1.0, max(0.0, Double(cardDragX / 90.0)))
                    let ngOpacity = min(1.0, max(0.0, Double(-cardDragX / 90.0)))

                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title.weight(.bold))
                            .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                            .opacity(ngOpacity)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title.weight(.bold))
                            .foregroundStyle(theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark))
                            .opacity(okOpacity)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal)
                .offset(x: cardDragX)
                .rotationEffect(.degrees(Double(cardDragX / 14.0)))
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isSwipeLocked else { return }
                            cardDragX = value.translation.width
                        }
                        .onEnded { value in
                            guard !isSwipeLocked else { return }
                            let threshold: CGFloat = 90
                            if value.translation.width > threshold {
                                handleSwipeAnswer(known: true)
                            } else if value.translation.width < -threshold {
                                handleSwipeAnswer(known: false)
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    cardDragX = 0
                                }
                            }
                        }
                )
                
                Text("← わからない ｜ わかる →")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Answer Buttons
            HStack(spacing: 16) {
                let wrongColor = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                let okColor = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
                Button {
                    recordAnswer(known: false)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("わからない")
                    }
                    .font(.headline)
                    .foregroundStyle(wrongColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(wrongColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(wrongColor.opacity(0.3), lineWidth: 2))
                }
                
                Button {
                    recordAnswer(known: true)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("わかる")
                    }
                    .font(.headline)
                    .foregroundStyle(okColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(okColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(okColor.opacity(0.3), lineWidth: 2))
                }
            }
            .padding(.horizontal)
            
            Button("学習を終了") {
                timerActive = false
                currentScreen = .daySelect
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
    }
    
    // MARK: - Weak Reprocess View
    
    private var weakReprocessView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            
            Text("弱点語の再処理")
                .font(.title2.weight(.bold))
            
            Text("\(weakWords.count)語が「わからない」でした。\n再度処理しますか？")
                .font(.footnote)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("スキップ") {
                    showResult()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .liquidGlass()
                
                Button("再処理する") {
                    startWeakReprocess()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(
                    theme.onColor(for: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "party.popper.fill")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            
            Text("ブロック完了！")
                .font(.title2.weight(.bold))
            
            HStack(spacing: 32) {
                VStack {
                    Text("\(knownCount)")
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark))
                    Text("わかる")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(unknownCount)")
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                    Text("わからない")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .liquidGlass()
            
            Spacer()
            
            Button {
                currentScreen = .daySelect
            } label: {
                let bg = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                Text("ホームに戻る")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.onColor(for: bg))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark),
                                theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Settings Sheet
    
    private var settingsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Text("1日目（初接触）")
                    Spacer()
                    Text("時間制限なし")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent {
                        Text("\(String(format: "%.1f", day2Seconds))秒")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    } label: {
                        Text("2日目（高速判定）")
                    }

                    Slider(value: $day2Seconds, in: 0.5...10.0, step: 0.5) {
                        Text("2日目")
                    } minimumValueLabel: {
                        Text("0.5")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    } maximumValueLabel: {
                        Text("10.0")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    }
                    .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                }

                Toggle(isOn: $day2UnknownOnly) {
                    Text("2日目は1日目で『わからない』のみ")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent {
                        Text("\(String(format: "%.1f", day3Seconds))秒")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark))
                    } label: {
                        Text("3日目（音読固定）")
                    }

                    Slider(value: $day3Seconds, in: 0.5...10.0, step: 0.5) {
                        Text("3日目")
                    } minimumValueLabel: {
                        Text("0.5")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    } maximumValueLabel: {
                        Text("10.0")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                    }
                    .tint(theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark))
                }
                
                // Quick Presets
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach([0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 7.0, 10.0], id: \.self) { preset in
                        Button("\(String(format: preset == 10.0 ? "%.0f" : "%.1f", preset))秒") {
                            day2Seconds = preset
                            day3Seconds = preset
                        }
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("秒数設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        showSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func dayLabel(_ day: Int) -> String {
        switch day {
        case 1: return "1日目（初接触）"
        case 2: return "2日目（高速判定）"
        case 3: return "3日目（音読固定）"
        default: return "学習"
        }
    }
    
    private func getSecondsForDay(_ day: Int) -> Double {
        switch day {
        case 1: return 0
        case 2: return day2Seconds
        case 3: return day3Seconds
        default: return 3.0
        }
    }
    
    private func startBlock(_ index: Int) {
        currentBlockIndex = index
        let allVocab = inputModeVocab
        let startIdx = index * blockSize
        let endIdx = min(startIdx + blockSize, allVocab.count)
        
        if startIdx < allVocab.count {
            var blockWords = Array(allVocab[startIdx..<endIdx])

            if currentDay == 1 {
                // Reset Day1 unknown list for this block at the start of Day1
                setDay1UnknownSet(subject: selectedSubject, block: index, ids: [])
            }

            if currentDay == 2, day2UnknownOnly {
                let unknownIds = getDay1UnknownSet(subject: selectedSubject, block: index)
                if unknownIds.isEmpty {
                    noWordsAlertMessage = "このブロックの1日目『わからない』履歴がありません。先に1日目を実行してください。"
                    showNoWordsAlert = true
                    return
                }
                blockWords = blockWords.filter { unknownIds.contains($0.id) }
                if blockWords.isEmpty {
                    noWordsAlertMessage = "このブロックの1日目『わからない』が0語でした。"
                    showNoWordsAlert = true
                    return
                }
            }

            words = blockWords
        } else {
            words = []
        }
        
        currentWordIndex = 0
        knownCount = 0
        unknownCount = 0
        weakWords = []
        isFlipped = false
        
        totalTime = getSecondsForDay(currentDay)
        timeRemaining = totalTime
        timerActive = totalTime > 0
        currentScreen = .study
    }
    
    private func recordAnswer(known: Bool) {
        timerActive = false
        
        if currentWordIndex < words.count {
            let word = words[currentWordIndex]
            masteryTracker.recordAnswer(
                subject: selectedSubject.rawValue,
                wordId: word.id,
                isCorrect: known,
                chosenAnswerText: known ? "わかる" : "わからない",
                correctAnswerText: nil
            )

            if currentDay == 1, !known {
                addDay1Unknown(subject: selectedSubject, block: currentBlockIndex, wordId: word.id)
            }
            
            if known {
                knownCount += 1
            } else {
                unknownCount += 1
                weakWords.append(word)
            }
        }
        
        if currentWordIndex < words.count - 1 {
            currentWordIndex += 1
            isFlipped = false
            cardDragX = 0
            timeRemaining = totalTime
            timerActive = totalTime > 0
        } else {
            // Block complete
            incrementBlockCompletion(day: currentDay, block: currentBlockIndex)
            
            if currentDay == 2 && !weakWords.isEmpty {
                currentScreen = .weakReprocess
            } else {
                showResult()
            }
        }
    }
    
    private func startWeakReprocess() {
        words = weakWords
        weakWords = []
        currentWordIndex = 0
        isFlipped = false
        timeRemaining = totalTime
        timerActive = totalTime > 0
        currentScreen = .study
    }
    
    private func showResult() {
        timerActive = false
        currentScreen = .result
    }
    
    private func resetProgress() {
        blockCompletionsData = Data()
        day1UnknownIdsData = Data()
    }

    private func day1UnknownKey(subject: Subject, block: Int) -> String {
        "s\(subject.rawValue)_b\(block)"
    }

    private func getDay1UnknownSet(subject: Subject, block: Int) -> Set<String> {
        guard let dict = try? JSONDecoder().decode([String: [String]].self, from: day1UnknownIdsData) else {
            return []
        }
        return Set(dict[day1UnknownKey(subject: subject, block: block)] ?? [])
    }

    private func setDay1UnknownSet(subject: Subject, block: Int, ids: Set<String>) {
        var dict = (try? JSONDecoder().decode([String: [String]].self, from: day1UnknownIdsData)) ?? [:]
        dict[day1UnknownKey(subject: subject, block: block)] = Array(ids)
        if let data = try? JSONEncoder().encode(dict) {
            day1UnknownIdsData = data
        }
    }

    private func addDay1Unknown(subject: Subject, block: Int, wordId: String) {
        var ids = getDay1UnknownSet(subject: subject, block: block)
        ids.insert(wordId)
        setDay1UnknownSet(subject: subject, block: block, ids: ids)
    }
    
    // MARK: - Persistence Helpers
    
    private func getBlockCompletionCount(day: Int, block: Int) -> Int {
        guard let dict = try? JSONDecoder().decode([String: Int].self, from: blockCompletionsData) else { return 0 }
        return dict[completionKey(day: day, block: block)] ?? 0
    }
    
    private func incrementBlockCompletion(day: Int, block: Int) {
        var dict = (try? JSONDecoder().decode([String: Int].self, from: blockCompletionsData)) ?? [:]
        let key = completionKey(day: day, block: block)
        dict[key] = (dict[key] ?? 0) + 1
        if let data = try? JSONEncoder().encode(dict) {
            blockCompletionsData = data
        }
    }

    private func completionKey(day: Int, block: Int) -> String {
        "s\(selectedSubject.rawValue)_d\(day)b\(block)"
    }
    
    private func getKnownTotal() -> Int {
        let data = masteryTracker.items[selectedSubject.rawValue] ?? [:]
        return data.values.filter { $0.mastery == .learning || $0.mastery == .almost || $0.mastery == .mastered }.count
    }

    private func getUnknownTotal() -> Int {
        let data = masteryTracker.items[selectedSubject.rawValue] ?? [:]
        return data.values.filter { $0.mastery == .weak }.count
    }

    private func getNewTotal() -> Int {
        let total = VocabularyData.shared.getVocabulary(for: selectedSubject).count
        let processed = (masteryTracker.items[selectedSubject.rawValue] ?? [:]).count
        return max(0, total - processed)
    }
}

// MARK: - Circular Timer View

struct CircularTimerView: View {
    let remaining: Double
    let total: Double

    @ObservedObject private var theme = ThemeManager.shared
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return remaining / total
    }
    
    var body: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let danger = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        @Environment(\.accessibilityReduceMotion) var reduceMotion
        
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    remaining <= 1 ? danger : accent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: remaining)
            
            Text(String(format: "%.1f", max(0, remaining)))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(remaining <= 1 ? danger : accent)
        }
    }
}

// MARK: - Flashcard Input View

struct FlashcardInputView: View {
    let word: String
    let hint: String
    let meaning: String
    @Binding var isFlipped: Bool
    var showsHintWithAnswer: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        let okColor = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        ZStack {
            // Back
            VStack(spacing: 12) {
                if showsHintWithAnswer, !hint.isEmpty {
                    Text(hint)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Text(meaning.components(separatedBy: CharacterSet(charactersIn: "　 、,")).first ?? meaning)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(okColor.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(okColor)
                
                Text(meaning)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(okColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)
            
            // Front
            VStack(spacing: 12) {
                Text(word)
                    .font(.title.weight(.bold))

                if !showsHintWithAnswer, !hint.isEmpty {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .opacity(isFlipped ? 0 : 1)
        }
        .rotation3DEffect(reduceMotion ? .zero : .degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: isFlipped)
        .onTapGesture {
            if reduceMotion {
                isFlipped.toggle()
            } else {
                withAnimation {
                    isFlipped.toggle()
                }
            }
        }
    }
}
