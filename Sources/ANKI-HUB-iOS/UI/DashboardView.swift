import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var learningStats: LearningStats
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("anki_hub_last_review_prompt_date") private var lastReviewPromptDate: String = ""
    @State private var showReviewPrompt: Bool = false

    private enum Destination: Hashable {
        case weak
        case due
        case todo
        case examHistory
        case timer
    }

    @State private var navigationPath = NavigationPath()

    private var totalWeakCount: Int {
        let subjects = [Subject.english, .kobun, .kanbun, .seikei]
        return subjects.reduce(0) { partial, subject in
            let data = masteryTracker.items[subject.rawValue] ?? [:]
            return partial + data.values.filter { $0.mastery == .weak }.count
        }
    }

    private var totalDueCount: Int {
        let subjects = [Subject.english, .kobun, .kanbun, .seikei]
        return subjects.reduce(0) { partial, subject in
            let vocab = VocabularyData.shared.getVocabulary(for: subject)
            let due = masteryTracker.getSpacedRepetitionItems(
                allItems: vocab, subject: subject.rawValue)
            return partial + due.count
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemeManager.shared.background

                if learningStats.streak == 0 && learningStats.todayMinutes == 0
                    && masteryTracker.items.isEmpty
                {
                    // Simple check for initial load or empty state
                }

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Stats
                        HStack(spacing: 15) {
                            StatCard(
                                title: "連続学習", value: "\(learningStats.streak)",
                                icon: "flame.fill", color: .orange)
                            StatCard(
                                title: "今日", value: "\(learningStats.todayMinutes)",
                                icon: "clock.fill", color: .blue)
                        }
                        .padding(.horizontal)

                        // Charts
                        DashboardCharts(
                            learningStats: learningStats, masteryTracker: masteryTracker
                        )
                        .padding(.horizontal)

                        // Quick Action / Insight
                        VStack(alignment: .leading) {
                            Text("Recommended")
                                .font(.headline)
                                .padding(.horizontal)

                            if totalDueCount > 0 {
                                Button {
                                    navigationPath.append(Destination.due)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("復習待ち（期限到来）")
                                                .font(.title3.bold())
                                            Text("\(totalDueCount)語")
                                                .font(.subheadline)
                                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .foregroundStyle(
                                                ThemeManager.shared.currentPalette.color(
                                                    .accent,
                                                    isDark: ThemeManager.shared.effectiveIsDark))
                                    }
                                    .padding()
                                    .liquidGlass()
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }

                            if totalWeakCount > 0 {
                                NavigationLink(destination: WeakWordsView()) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("復習待ち")
                                                .font(.title3.bold())
                                            Text("\(totalWeakCount)語")
                                                .font(.subheadline)
                                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(
                                                ThemeManager.shared.currentPalette.color(
                                                    .selection,
                                                    isDark: ThemeManager.shared.effectiveIsDark))
                                    }
                                    .padding()
                                    .padding()
                                    .liquidGlass()
                                    .padding(.horizontal)
                                }
                            }

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("今日の復習")
                                        .font(.title3.bold())
                                    Text("\(learningStats.todayMinutes)分")
                                        .font(.subheadline)
                                        .foregroundStyle(ThemeManager.shared.secondaryText)
                                }
                                Spacer()
                                CircularProgressView(
                                    progress: Double(learningStats.todayMinutes) / 30.0
                                )
                                .frame(width: 50, height: 50)
                            }
                            .padding()
                            .liquidGlass()
                            .padding(.horizontal)

                            // ToDo Card
                            Button {
                                navigationPath.append(Destination.todo)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("やることリスト")
                                            .font(.title3.bold())
                                    }
                                    Spacer()
                                    Image(systemName: "list.bullet")
                                        .foregroundStyle(
                                            ThemeManager.shared.currentPalette.color(
                                                .primary,
                                                isDark: ThemeManager.shared.effectiveIsDark))
                                }
                                .padding()
                                .padding()
                                .liquidGlass()
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            // Exam History Card
                            Button {
                                navigationPath.append(Destination.examHistory)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("テスト履歴")
                                            .font(.title3.bold())
                                    }
                                    Spacer()
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(
                                            ThemeManager.shared.currentPalette.color(
                                                .accent, isDark: ThemeManager.shared.effectiveIsDark
                                            ))
                                }
                                .padding()
                                .padding()
                                .liquidGlass()
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            // Timer / Stopwatch Card
                            Button {
                                navigationPath.append(Destination.timer)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("タイマー")
                                            .font(.title3.bold())
                                    }
                                    Spacer()
                                    Image(systemName: "stopwatch.fill")
                                        .foregroundStyle(
                                            ThemeManager.shared.currentPalette.color(
                                                .accent, isDark: ThemeManager.shared.effectiveIsDark
                                            ))
                                }
                                .padding()
                                .padding()
                                .liquidGlass()
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top)
                }
                .navigationTitle("ホーム")
                .alert("復習待ち", isPresented: $showReviewPrompt) {
                    Button("今すぐ復習") {
                        lastReviewPromptDate = todayKey()
                        navigationPath.append(Destination.weak)
                    }
                    Button("今日はしない", role: .cancel) {
                        lastReviewPromptDate = todayKey()
                    }
                } message: {
                    Text("苦手が\(totalWeakCount)語あります。今のうちに一括復習しましょう。")
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        if authManager.currentUser != nil && authManager.isInvited {
                            Button(action: {
                                Task {
                                    await SyncManager.shared.syncAllDebounced()
                                }
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Destination.self) { dest in
                switch dest {
                case .weak:
                    WeakWordsView()
                case .due:
                    DueReviewView()
                case .todo:
                    TodoView()
                case .examHistory:
                    ExamHistoryView()
                case .timer:
                    PomodoroView()
                }
            }
        }
        .applyAppTheme()
        .onAppear {
            learningStats.loadStats()
            masteryTracker.loadData()

            if totalWeakCount > 0 {
                let today = todayKey()
                if lastReviewPromptDate != today {
                    showReviewPrompt = true
                }
            }
        }
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// Subcomponents

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(theme.primaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass()
    }
}

struct SubjectCard: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack {
            Image(systemName: subject.icon)
                .font(.system(size: 40))
                .foregroundColor(subject.color)
                .padding(.bottom, 10)

            Text(subject.displayName)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text(subject.description)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minHeight: 150)
        .frame(maxWidth: .infinity)
        .liquidGlass()
    }
}

struct ToolCard: View {
    let icon: String
    let title: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .liquidGlass()
    }
}
