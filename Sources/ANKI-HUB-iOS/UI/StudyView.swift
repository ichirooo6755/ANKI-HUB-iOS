import SwiftUI

struct StudyView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.background

                ScrollView {
                    VStack(spacing: 25) {
                        // Subject Selection Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("学習科目")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15
                            ) {
                                ForEach(Subject.allCases) { subject in
                                    SubjectGridItem(subject: subject)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Tools Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("ツール")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)

                            ToolsGridView()
                                .padding(.horizontal)

                            // Past Exam Analysis (Full Width)
                            NavigationLink(destination: PastExamAnalysisView()) {
                                HStack {
                                    let bg = theme.currentPalette.color(
                                        .primary, isDark: theme.effectiveIsDark)
                                    Image(systemName: "chart.xyaxis.line")
                                        .foregroundStyle(theme.onColor(for: bg))
                                        .padding(10)
                                        .background(bg)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading) {
                                        Text("過去問解析")
                                            .font(.headline)
                                            .foregroundColor(ThemeManager.shared.primaryText)
                                        Text("スコア管理・傾向分析")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(theme.secondaryText)
                                }
                                .padding()
                                .liquidGlass()
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("学習")
            .applyAppTheme()
        }
    }
}

// MARK: - Subviews
struct SubjectGridItem: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack {
            // All subjects go through chapter selection
            if subject == .kobun {
                NavigationLink(destination: KobunStudyMenuView()) {
                    SubjectCard(subject: subject)
                }
            } else {
                NavigationLink(destination: ChapterSelectionView(subject: subject)) {
                    SubjectCard(subject: subject)
                }
            }
        }
    }
}

struct KobunStudyMenuView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            theme.background

            VStack(spacing: 16) {
                NavigationLink(destination: ChapterSelectionView(subject: .kobun)) {
                    menuCard(title: "単語クイズ", subtitle: "チャプター別に4択/タイピング/カード")
                }

                NavigationLink(destination: FocusedMemorizationView(subject: .kobun)) {
                    menuCard(title: "インプットモード", subtitle: "3日集中で仕分け→高速復習")
                }

                NavigationLink(destination: KobunParticleQuizView()) {
                    menuCard(title: "助詞クイズ", subtitle: "助詞表の穴埋め（表形式UI）")
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("古文")
        .applyAppTheme()
    }

    private func menuCard(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .liquidGlass()
    }
}

struct ToolsGridView: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(destination: WordbookView()) {
                ToolCard(icon: "book.fill", title: "単語帳", color: .blue)
            }
            NavigationLink(destination: BookshelfView()) {
                ToolCard(icon: "books.vertical.fill", title: "教材", color: .cyan)
            }
            NavigationLink(destination: TodoView()) {
                ToolCard(icon: "list.bullet", title: "やること", color: .teal)
            }
            NavigationLink(destination: TimerView()) {
                ToolCard(icon: "timer", title: "タイマー", color: .red)
            }
            NavigationLink(destination: AppCalendarView()) {
                ToolCard(icon: "calendar", title: "カレンダー", color: .green)
            }
            NavigationLink(destination: ReportView()) {
                ToolCard(icon: "chart.pie.fill", title: "レポート", color: .purple)
            }
            NavigationLink(destination: ScanView()) {
                ToolCard(icon: "camera.viewfinder", title: "スキャン", color: .orange)
            }
            NavigationLink(destination: PaperWordbookSyncView()) {
                ToolCard(icon: "book.pages.fill", title: "紙の単語帳", color: .brown)
            }
            NavigationLink(destination: FocusedMemorizationView()) {
                ToolCard(icon: "brain.head.profile", title: "集中暗記", color: .orange)
            }
        }
    }
}

// MARK: - KobunParticleQuizView (Inlined)

struct KobunParticleQuizView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = ParticleQuizViewModel()
    @State private var showFeedbackOverlay = false
    @State private var isCorrect = false
    @State private var isAnswerLocked: Bool = false
    @State private var wordbookRefreshNonce: Int = 0

    var body: some View {
        ZStack {
            theme.background

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView("Loading Particles...")
                    Text("データを読み込み中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let err = viewModel.loadError {
                VStack(spacing: 12) {
                    Text("読み込みに失敗しました")
                        .font(.headline)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("リトライ") {
                        Task { await viewModel.loadData() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .liquidGlass()
            } else if viewModel.isQuizComplete {
                VStack(spacing: 24) {
                    Text("🎉 Quiz Complete!")
                        .font(.largeTitle.bold())

                    Text("Score: \(viewModel.score) / \(viewModel.totalQuestions)")
                        .font(.title)

                    Button("Restart") {
                        viewModel.restart()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .liquidGlass()
            } else {
                ZStack {
                    VStack(spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Text(
                                "Question \(viewModel.currentIndex + 1) / \(viewModel.totalQuestions)"
                            )
                            .font(.headline)
                            Spacer()
                            Text("Score: \(viewModel.score)")
                            bookmarkButton
                        }
                        .padding()

                        if let question = viewModel.currentQuestion {
                            ScrollView {
                                VStack(spacing: 32) {
                                    ParticleConjugationTableView(
                                        particleData: question.particle,
                                        blankTarget: question.blankTarget,
                                        choices: question.choices,
                                        correctAnswerIndex: question.correctIndex
                                    ) { correct in
                                        handleAnswer(correct: correct)
                                    }
                                    .allowsHitTesting(!isAnswerLocked)
                                    .id(viewModel.currentIndex)
                                }
                                .padding()
                            }
                        }
                    }
                    if showFeedbackOverlay {
                        OverlayFeedbackView(isCorrect: isCorrect)
                            .transition(.opacity)
                            .zIndex(100)
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            // Unlock when moving to the next question
            isAnswerLocked = false
        }
    }

    private func handleAnswer(correct: Bool) {
        guard !isAnswerLocked else { return }
        isAnswerLocked = true
        isCorrect = correct
        withAnimation {
            showFeedbackOverlay = true
        }

        // Hide overlay after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showFeedbackOverlay = false
            }
        }

        // Advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                viewModel.submitAnswer(correct: correct)
            }
        }
    }

    private var bookmarkButton: some View {
        _ = wordbookRefreshNonce
        let isBookmarked = isCurrentParticleBookmarked()
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)

        return Button {
            toggleCurrentParticleBookmark()
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(surface.opacity(theme.effectiveIsDark ? 0.85 : 0.95))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(border.opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.currentQuestion == nil)
    }

    private func isCurrentParticleBookmarked() -> Bool {
        guard let question = viewModel.currentQuestion else { return false }
        guard let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
              let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) else {
            return false
        }
        return decoded.contains(where: { $0.id == question.particle.id })
    }

    private func toggleCurrentParticleBookmark() {
        guard let question = viewModel.currentQuestion else { return }
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            words = decoded
        }

        let particle = question.particle
        let exampleText = particle.examples?.first
        let newEntry = WordbookEntry(
            id: particle.id,
            term: particle.particle,
            meaning: particle.meaning,
            hint: particle.type,
            example: exampleText,
            source: "古文助詞クイズ",
            mastery: .new,
            subject: .kobun
        )

        let alreadyAdded = words.contains(where: { $0.id == particle.id })
        if alreadyAdded {
            words.removeAll { $0.id == particle.id }
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
}

// MARK: - Logic

enum ConjugationType: String, CaseIterable {
    case mizen = "未然"
    case renyo = "連用"
    case shushi = "終止"
    case rentai = "連体"
    case izen = "已然"
    case meirei = "命令"

    var label: String { rawValue }
}

class ParticleQuizViewModel: ObservableObject {
    @Published var particles: [ParticleData] = []
    @Published var currentIndex = 0
    @Published var score = 0
    @Published var isQuizComplete = false

    @Published var isLoading: Bool = false
    @Published var loadError: String? = nil

    // Current Question State
    struct Question {
        let particle: ParticleData
        let blankTarget: ParticleConjugationTableView.BlankTarget
        let choices: [String]
        let correctIndex: Int
    }
    @Published var currentQuestion: Question?

    var totalQuestions: Int { particles.count }

    @MainActor
    func loadData() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let allVocab = VocabularyData.shared.getVocabulary(for: .kobun)
        var items = allVocab.compactMap { $0.particleData }

        // If no particle data found, use sample particles for testing
        if items.isEmpty {
            items = Self.sampleParticles
        }

        guard !items.isEmpty else {
            particles = []
            currentQuestion = nil
            loadError = "助詞データが見つかりませんでした。"
            return
        }

        particles = items.shuffled()
        currentIndex = 0
        score = 0
        isQuizComplete = false
        nextQuestion()
    }

    // Sample particle data for testing when particleData is not available in Vocabulary
    private static let sampleParticles: [ParticleData] = [
        ParticleData(
            id: "p1", type: "係助詞", particle: "こそ",
            meaning: "強調（最も強い）",
            examples: ["命こそ惜しけれ（命こそが惜しいのだ）"],
            conjugations: ConjugationData(desc: "接続: 連体形", forms: ["係り結び→已然形"])
        ),
        ParticleData(
            id: "p2", type: "係助詞", particle: "ぞ",
            meaning: "強調",
            examples: ["花ぞ散りける"],
            conjugations: ConjugationData(desc: "接続: 連体形", forms: ["係り結び→連体形"])
        ),
        ParticleData(
            id: "p3", type: "係助詞", particle: "なむ",
            meaning: "強調（願望）",
            examples: ["雨なむ降りける"],
            conjugations: ConjugationData(desc: "接続: 連体形", forms: ["係り結び→連体形"])
        ),
        ParticleData(
            id: "p4", type: "接続助詞", particle: "ば",
            meaning: "仮定・確定条件",
            examples: ["行かば（行くならば）", "行けば（行ったので）"],
            conjugations: ConjugationData(desc: "接続: 未然形・已然形", forms: ["未然形＋ば＝仮定", "已然形＋ば＝確定"])
        ),
        ParticleData(
            id: "p5", type: "接続助詞", particle: "ど",
            meaning: "逆接（〜けれども）",
            examples: ["行けど帰らず"],
            conjugations: ConjugationData(desc: "接続: 已然形", forms: ["已然形に接続"])
        ),
        ParticleData(
            id: "p6", type: "接続助詞", particle: "ども",
            meaning: "逆接（〜けれども）",
            examples: ["見れども飽かず"],
            conjugations: ConjugationData(desc: "接続: 已然形", forms: ["已然形に接続"])
        ),
        ParticleData(
            id: "p7", type: "格助詞", particle: "の",
            meaning: "主格・連体修飾",
            examples: ["山の桜", "我の行く"],
            conjugations: ConjugationData(desc: "接続: 体言・連体形", forms: ["体言に接続"])
        ),
        ParticleData(
            id: "p8", type: "格助詞", particle: "が",
            meaning: "主格・連体修飾",
            examples: ["花が咲く", "山が紫"],
            conjugations: ConjugationData(desc: "接続: 体言・連体形", forms: ["体言に接続"])
        ),
    ]

    func nextQuestion() {
        guard currentIndex < particles.count else {
            isQuizComplete = true
            return
        }

        let p = particles[currentIndex]
        if let generated = ParticleQuizGenerator.generateQuestion(from: p, allParticles: particles)
        {
            currentQuestion = Question(
                particle: p,
                blankTarget: generated.blankTarget,
                choices: generated.choices,
                correctIndex: generated.correctIndex
            )
        } else {
            // Skip if question can't be generated
            currentIndex += 1
            nextQuestion()
        }
    }

    func submitAnswer(correct: Bool) {
        if correct {
            score += 1
        }
        currentIndex += 1
        nextQuestion()
    }

    func restart() {
        currentIndex = 0
        score = 0
        isQuizComplete = false
        particles.shuffle()
        nextQuestion()
    }
}
