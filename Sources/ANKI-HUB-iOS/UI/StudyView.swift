import SwiftUI

struct StudyView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var stats = LearningStats.shared
    @ObservedObject private var effects = VisualEffectsManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 16) {
                        StudySessionBentoCard()
                            .padding(.horizontal, 16)

                        StudySectionCard(
                            accent: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                        ) {
                            SectionHeader(
                                title: "学習ダッシュボード",
                                subtitle: nil,
                                trailing: nil
                            )

                            summaryMetrics
                        }

                        StudySectionCard(
                            accent: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                        ) {
                            SectionHeader(title: "学習科目", subtitle: nil, trailing: nil)

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16
                            ) {
                                ForEach(Subject.allCases) { subject in
                                    SubjectGridItem(subject: subject)
                                }
                            }
                        }

                        ToolsGridView()
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .adaptiveVisualEffect(enableOverlay: true)
            .navigationTitle("学習")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: VisualEffectsSettingsView()) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    NavigationLink(destination: VisualEffectsSettingsView()) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                #endif
            }
            .applyAppTheme()
        }
    }

    private var summaryMetrics: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let todayProgress = min(1.0, Double(stats.todayMinutes) / 30.0)
        let streakProgress = min(1.0, Double(stats.streak) / 30.0)
        let masteredProgress = stats.totalWords == 0
            ? 0
            : min(1.0, Double(stats.masteredCount) / Double(stats.totalWords))
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            HealthMetricCard(
                title: "今日の学習",
                value: "\(stats.todayMinutes)",
                unit: "分",
                icon: "clock.fill",
                color: accent,
                progress: todayProgress
            )
            HealthMetricCard(
                title: "連続日数",
                value: "\(stats.streak)",
                unit: "日",
                icon: "flame.fill",
                color: accent,
                progress: streakProgress
            )
            HealthMetricCard(
                title: "習得語彙",
                value: "\(stats.masteredCount)",
                unit: "語",
                icon: "checkmark.seal.fill",
                color: mastered,
                progress: masteredProgress
            )
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
                    menuCard(title: "単語クイズ")
                }

                NavigationLink(destination: FocusedMemorizationView(subject: .kobun)) {
                    menuCard(title: "インプットモード")
                }

                NavigationLink(destination: KobunParticleQuizView()) {
                    menuCard(title: "助詞クイズ")
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("古文")
        .applyAppTheme()
    }

    private func menuCard(title: String) -> some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.24 : 0.06)
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        return ZStack(alignment: .topTrailing) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 96, weight: .bold, design: .default))
                .foregroundStyle(accent.opacity(theme.effectiveIsDark ? 0.18 : 0.14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(x: 24)
                .accessibilityHidden(true)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.9 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: shadow, radius: 6, x: 0, y: 4)
        }
    }
}

struct ToolsGridView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolSection(
                title: "計画・管理",
                accent: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
            ) {
                NavigationLink(destination: WordbookView()) {
                    ToolCard(title: "単語帳", icon: "book.fill", color: .blue)
                }
                NavigationLink(destination: BookshelfView()) {
                    ToolCard(title: "教材", icon: "books.vertical.fill", color: .cyan)
                }
                NavigationLink(destination: TodoView()) {
                    ToolCard(title: "やること", icon: "list.bullet", color: .teal)
                }
                NavigationLink(destination: PaperWordbookSyncView()) {
                    ToolCard(title: "紙の単語帳", icon: "book.pages.fill", color: .brown)
                }
            }

            toolSection(
                title: "学習サポート",
                accent: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
            ) {
                NavigationLink(destination: TimerView()) {
                    ToolCard(title: "タイマー", icon: "timer", color: .red)
                }
                NavigationLink(destination: FocusedMemorizationView()) {
                    ToolCard(title: "集中暗記", icon: "brain.head.profile", color: .orange)
                }
                NavigationLink(destination: ScanView()) {
                    ToolCard(title: "スキャン", icon: "doc.viewfinder", color: .yellow)
                }
                NavigationLink(destination: FrontCameraView()) {
                    ToolCard(title: "ミラー", icon: "camera.fill", color: .pink)
                }
            }

            toolSection(
                title: "記録・分析",
                accent: theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
            ) {
                NavigationLink(destination: ReportView()) {
                    ToolCard(title: "レポート", icon: "chart.pie.fill", color: .purple)
                }
                NavigationLink(destination: PastExamAnalysisView()) {
                    ToolCard(title: "過去問解析", icon: "chart.xyaxis.line", color: .indigo)
                }
            }
        }
    }

    @ViewBuilder
    private func toolSection(
        title: String,
        accent: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        StudySectionCard(accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(theme.primaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    content()
                }
            }
        }
    }
}

struct StudySectionCard<Content: View>: View {
    let accent: Color
    let content: Content

    @ObservedObject private var theme = ThemeManager.shared

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let highlight = theme.currentPalette.color(.background, isDark: isDark)
        let shadow = Color.black.opacity(isDark ? 0.24 : 0.06)
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let cardGradient = LinearGradient(
            colors: [surface.opacity(isDark ? 0.95 : 0.98), highlight.opacity(isDark ? 0.8 : 0.94)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(16)
        }
        .background(cardShape.fill(cardGradient))
        .overlay(
            cardShape
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.35), accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(accent)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.leading, 16)
        }
        .clipShape(cardShape)
        .shadow(color: shadow, radius: 6, x: 0, y: 4)
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

        if items.isEmpty {
            items = VocabularyData.shared.getParticles()
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
