import SwiftUI
import StoreKit

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var learningStats: LearningStats
    @EnvironmentObject var masteryTracker: MasteryTracker
    @EnvironmentObject var themeManager: ThemeManager

    @Environment(\.requestReview) private var requestReview: RequestReviewAction

    @AppStorage("anki_hub_last_review_prompt_date") private var lastReviewPromptDate: String = ""
    @AppStorage("anki_hub_target_date_timestamp_v2") private var targetDateTimestamp: Double = 0
    @AppStorage("anki_hub_target_start_timestamp_v1") private var targetStartTimestamp: Double = 0
    @AppStorage("anki_hub_target_study_minutes_v1") private var targetStudyMinutes: Int = 600
    @State private var showReviewPrompt: Bool = false
    @ScaledMetric private var quickIconSize: CGFloat = 40

    private enum Destination: Hashable {
        case weak
        case due
        case todo
        case examHistory
        case timer
        case timeline
        case mirror
        case inputMode
    }

    @State private var navigationPath: [Destination] = []

    @State private var heroPullNavigating: Bool = false

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
        let heroAccent = themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark)
        let heroSecondary = themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark)
        let heroItems: [HeroCarouselItem] = [
            HeroCarouselItem(
                id: "timer",
                title: "集中タイマー",
                subtitle: "",
                detail: "すぐ開始",
                icon: "timer",
                gradient: [heroAccent.opacity(0.95), heroSecondary.opacity(0.75)],
                action: { navigate(to: .timer) }
            ),
            HeroCarouselItem(
                id: "due",
                title: "期限到来",
                subtitle: "",
                detail: "\(totalDueCount)語",
                icon: "clock.badge.exclamationmark",
                gradient: [heroSecondary.opacity(0.95), heroSecondary.opacity(0.6)],
                action: { navigate(to: .due) }
            ),
            HeroCarouselItem(
                id: "weak",
                title: "苦手克服",
                subtitle: "",
                detail: "\(totalWeakCount)語",
                icon: "bolt.fill",
                gradient: [themeManager.currentPalette.color(.weak, isDark: themeManager.effectiveIsDark).opacity(0.95),
                           themeManager.currentPalette.color(.weak, isDark: themeManager.effectiveIsDark).opacity(0.6)],
                action: { navigate(to: .weak) }
            ),
            HeroCarouselItem(
                id: "inputmode",
                title: "インプット",
                subtitle: "",
                detail: "",
                icon: "keyboard",
                gradient: [themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.95),
                           themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark).opacity(0.65)],
                action: { navigate(to: .inputMode) }
            )
        ]
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemeManager.shared.background

                if learningStats.streak == 0 && learningStats.todayMinutes == 0
                    && masteryTracker.items.isEmpty
                {
                    // Simple check for initial load or empty state
                }

                ScrollView {
                    VStack(spacing: 16) {
                        Button {
                            navigate(to: .weak)
                        } label: {
                            DashboardHeroHeader(
                                title: "今日の学習 \(learningStats.todayMinutes)分",
                                subtitle: "",
                                caption: "学習時間",
                                detail: goalProgressText,
                                icon: "sparkles",
                                accent: heroAccent,
                                secondary: heroSecondary
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("苦手一括復習へ"))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 24)
                                .onEnded { value in
                                    guard value.translation.height > 80 else { return }
                                    guard !heroPullNavigating else { return }
                                    heroPullNavigating = true
                                    navigate(to: .weak)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        heroPullNavigating = false
                                    }
                                }
                        )
                        .padding(.horizontal)

                        HeroCarouselView(items: heroItems)
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 4)

                        // Header Stats
                        HStack(spacing: 16) {
                            StatCard(
                                title: "連続学習", value: "\(learningStats.streak)", unit: "日",
                                icon: "flame.fill", color: .orange)
                            StatCard(
                                title: "今日", value: "\(learningStats.todayMinutes)", unit: "分",
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
                            HStack {
                                Text("Recommended")
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text("今やるべきこと")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(themeManager.secondaryText)
                            }
                            .padding(.horizontal)

                            if totalDueCount > 0 {
                                Button {
                                    navigate(to: .due)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("復習待ち（期限到来）")
                                                .font(.headline.weight(.semibold))
                                            Text("\(totalDueCount)語")
                                                .font(.footnote.weight(.medium))
                                                .monospacedDigit()
                                                .foregroundStyle(themeManager.secondaryText)
                                        }
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                                .frame(width: quickIconSize, height: quickIconSize)
                                            Image(systemName: "clock.badge.exclamationmark")
                                                .font(.callout.weight(.semibold))
                                                .foregroundStyle(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark))
                                        }
                                    }
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                        themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                navigate(to: .timeline)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("タイムライン")
                                            .font(.headline.weight(.semibold))
                                        Text("学習ログを投稿")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(themeManager.secondaryText)
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                            .frame(width: quickIconSize, height: quickIconSize)
                                        Image(systemName: "sparkles")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark))
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                    themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: themeManager.currentPalette.color(.primary, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            if totalWeakCount > 0 {
                                NavigationLink(destination: WeakWordsView()) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("復習待ち")
                                                .font(.headline.weight(.semibold))
                                            Text("\(totalWeakCount)語")
                                                .font(.footnote.weight(.medium))
                                                .monospacedDigit()
                                                .foregroundStyle(themeManager.secondaryText)
                                        }
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(themeManager.currentPalette.color(.selection, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                                .frame(width: quickIconSize, height: quickIconSize)
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.callout.weight(.semibold))
                                                .foregroundStyle(themeManager.currentPalette.color(.selection, isDark: themeManager.effectiveIsDark))
                                        }
                                    }
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        themeManager.currentPalette.color(.selection, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                        themeManager.currentPalette.color(.selection, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: themeManager.currentPalette.color(.selection, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("今日の復習")
                                        .font(.headline.weight(.semibold))
                                    Text("\(learningStats.todayMinutes)分")
                                        .font(.footnote.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundStyle(themeManager.secondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .layoutPriority(1)
                                Spacer()
                                CircularProgressView(
                                    progress: Double(learningStats.todayMinutes) / 30.0,
                                    color: themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark),
                                    lineWidth: 6,
                                    accessibilityLabel: "今日の復習進捗"
                                )
                                .frame(width: 50, height: 50)
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                            .padding(.horizontal)

                            // ToDo Card
                            Button {
                                navigate(to: .todo)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("やることリスト")
                                            .font(.headline.weight(.semibold))
                                        Text("学習タスクを管理")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(themeManager.secondaryText)
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.currentPalette.color(.new, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                            .frame(width: quickIconSize, height: quickIconSize)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(themeManager.currentPalette.color(.new, isDark: themeManager.effectiveIsDark))
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentPalette.color(.new, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                    themeManager.currentPalette.color(.new, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: themeManager.currentPalette.color(.new, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            // Exam History Card
                            Button {
                                navigate(to: .examHistory)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("テスト履歴")
                                            .font(.headline.weight(.semibold))
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                            .frame(width: quickIconSize, height: quickIconSize)
                                        Image(systemName: "doc.text")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark))
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                    themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            // Timer / Stopwatch Card
                            Button {
                                navigate(to: .timer)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("タイマー")
                                            .font(.headline.weight(.semibold))
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.18))
                                            .frame(width: quickIconSize, height: quickIconSize)
                                        Image(systemName: "stopwatch.fill")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark))
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.35),
                                                    themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.08),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: themeManager.currentPalette.color(.accent, isDark: themeManager.effectiveIsDark).opacity(0.10), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            Button {
                                navigate(to: .mirror)
                            } label: {
                                let mirrorColor = themeManager.currentPalette.color(
                                    .learning,
                                    isDark: themeManager.effectiveIsDark
                                )
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("ミラー")
                                            .font(.headline.weight(.semibold))
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(mirrorColor.opacity(0.18))
                                            .frame(width: quickIconSize, height: quickIconSize)
                                        Image(systemName: "camera.fill")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(mirrorColor)
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(themeManager.currentPalette.color(.surface, isDark: themeManager.effectiveIsDark))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    mirrorColor.opacity(0.35),
                                                    mirrorColor.opacity(0.08),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: mirrorColor.opacity(0.10), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 24)
                    }
                }
                .coordinateSpace(name: "scroll")
                .alert("レビューのお願い", isPresented: $showReviewPrompt) {
                    Button("今はしない", role: .cancel) {
                        lastReviewPromptDate = todayKey()
                    }
                    Button("レビューする") {
                        requestReview()
                        lastReviewPromptDate = todayKey()
                    }
                } message: {
                    Text("\(totalWeakCount)語")
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
            .coordinateSpace(name: "scroll")
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
                case .mirror:
                    FrontCameraView()
                case .inputMode:
                    InputModeView()
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

    private func navigate(to destination: Destination) {
        if navigationPath.last == destination {
            return
        }
        navigationPath.append(destination)
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

