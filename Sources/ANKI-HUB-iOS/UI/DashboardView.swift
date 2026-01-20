import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var learningStats: LearningStats
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("anki_hub_last_review_prompt_date") private var lastReviewPromptDate: String = ""
    @AppStorage("anki_hub_target_date_timestamp_v2") private var targetDateTimestamp: Double = 0
    @AppStorage("anki_hub_target_start_timestamp_v1") private var targetStartTimestamp: Double = 0
    @AppStorage("anki_hub_target_study_minutes_v1") private var targetStudyMinutes: Int = 600
    @State private var showReviewPrompt: Bool = false

    private enum Destination: Hashable {
        case weak
        case due
        case todo
        case examHistory
        case timer
        case timeline
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

    private var goalTargetDate: Date {
        if targetDateTimestamp == 0 {
            return Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }
        return Date(timeIntervalSince1970: targetDateTimestamp)
    }

    private var goalStartDate: Date {
        if targetStartTimestamp == 0 {
            return Calendar.current.startOfDay(for: Date())
        }
        return Date(timeIntervalSince1970: targetStartTimestamp)
    }

    private var goalDaysRemaining: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: goalTargetDate)
        let diff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, diff)
    }

    private var goalStudiedMinutes: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: goalStartDate)
        let end = calendar.startOfDay(for: Date())
        return learningStats.dailyHistory.compactMap { key, entry in
            guard let date = dateFromKey(key) else { return nil }
            let day = calendar.startOfDay(for: date)
            return (day >= start && day <= end) ? entry.minutes : nil
        }
        .reduce(0, +)
    }

    private var goalProgress: Double {
        guard targetStudyMinutes > 0 else { return 0 }
        return min(1.0, Double(goalStudiedMinutes) / Double(targetStudyMinutes))
    }

    private var goalProgressText: String {
        "\(formatMinutes(goalStudiedMinutes)) / \(formatMinutes(targetStudyMinutes))"
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

                        GoalCountdownCard(
                            daysRemaining: goalDaysRemaining,
                            targetDate: goalTargetDate,
                            progress: goalProgress,
                            progressText: goalProgressText
                        )
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

                            Button {
                                navigationPath.append(Destination.timeline)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("タイムライン")
                                            .font(.title3.bold())
                                        Text("学習ログを投稿")
                                            .font(.subheadline)
                                            .foregroundStyle(themeManager.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(
                                            themeManager.currentPalette.color(
                                                .primary, isDark: themeManager.effectiveIsDark))
                                }
                                .padding()
                                .liquidGlass()
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

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
                    TimerView()
                case .timeline:
                    TimelineView()
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

    private func dateFromKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)分" }
        if remainder == 0 { return "\(hours)時間" }
        return "\(hours)時間\(remainder)分"
    }
}

