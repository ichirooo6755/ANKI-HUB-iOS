import Foundation
import SwiftUI

#if canImport(WidgetKit)
    import WidgetKit
#endif

struct PomodoroStartRequest: Identifiable {
    let id = UUID()
    let mode: String
    let minutes: Int
    let open: Bool
}

// MARK: - Vocabulary
struct Vocabulary: Identifiable, Codable {
    let id: String
    let term: String
    let meaning: String
    let reading: String?

    // Optional fields for extended data types
    var hint: String?
    var example: String?
    var explanation: String?

    // Seikei specifics
    var questionType: String?  // "combined", "blank", etc.
    var allAnswers: [String]?
    var blankMap: [Int]?
    var articleNumbers: [String]?
    var fullText: String?
    var category: String?

    // Kobun specifics
    var type: String?  // "vocab" or "particle"
    var particleData: ParticleData?

    // Default initializer for basic items
    init(
        id: String, term: String, meaning: String, reading: String? = nil, hint: String? = nil,
        example: String? = nil, explanation: String? = nil
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.reading = reading
        self.hint = hint
        self.example = example
        self.explanation = explanation
    }
}

struct WordbookEntry: Identifiable, Codable {
    let id: String
    var term: String
    var meaning: String
    var hint: String?
    var mastery: MasteryLevel
    var subject: Subject?
    
    init(id: String, term: String, meaning: String, hint: String? = nil, mastery: MasteryLevel = .new, subject: Subject? = nil) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.hint = hint
        self.mastery = mastery
        self.subject = subject
    }
}

// MARK: - Kobun Structures
struct ParticleData: Codable {
    let id: String
    let type: String
    let particle: String
    let meaning: String
    let examples: [String]?
    let conjugations: ConjugationData?
}

struct ConjugationData: Codable {
    let desc: String
    let forms: [String]
}

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    @Published var currentUser: User?
    @Published var isInvited: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastAuthErrorMessage: String?

    struct User: Codable, Equatable {
        let id: String
        let email: String
        var displayName: String {
            // Extract name from email or return default
            email.components(separatedBy: "@").first?.capitalized ?? "ユーザー"
        }
    }

    private let userKey = "anki_hub_user"
    private let inviteKey = "anki_hub_invited"

    init() {
        loadUser()
        Task {
            await restoreSessionIfPossible()
        }
    }

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
            let user = try? JSONDecoder().decode(User.self, from: data)
        {
            currentUser = user
        }
        isInvited = UserDefaults.standard.bool(forKey: inviteKey)
    }

    private func saveUser() {
        if let user = currentUser,
            let data = try? JSONEncoder().encode(user)
        {
            UserDefaults.standard.set(data, forKey: userKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userKey)
        }
        UserDefaults.standard.set(isInvited, forKey: inviteKey)
    }

    private func restoreSessionIfPossible() async {
        if currentUser != nil { return }

        SupabaseAuthService.shared.loadSessionFromKeychain()
        guard let session = SupabaseAuthService.shared.session else { return }

        let email = session.user.email ?? ""
        currentUser = User(id: session.user.id, email: email)

        isInvited =
            (try? await SupabaseInvitationService.shared.checkInvitation(
                userId: session.user.id,
                accessToken: session.accessToken
            )) ?? false

        saveUser()

        if isInvited {
            await SyncManager.shared.loadAll()
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await SupabaseAuthService.shared.signInWithGoogle()
            let email = session.user.email ?? ""
            currentUser = User(id: session.user.id, email: email)

            if !email.isEmpty {
                try? await SupabaseUserService.shared.upsertUser(
                    id: session.user.id,
                    email: email,
                    accessToken: session.accessToken
                )
            }

            // Check invitation status from cloud
            isInvited =
                (try? await SupabaseInvitationService.shared.checkInvitation(
                    userId: session.user.id,
                    accessToken: session.accessToken
                )) ?? false

            saveUser()

            if isInvited {
                await SyncManager.shared.loadAll()
            }

            lastAuthErrorMessage = nil
        } catch {
            lastAuthErrorMessage = error.localizedDescription
        }
    }

    func clearAuthError() {
        lastAuthErrorMessage = nil
    }

    func signOut() async {
        await SupabaseAuthService.shared.signOut()
        currentUser = nil
        isInvited = false
        saveUser()
    }

    func verifyInviteCode(_ code: String) async -> Bool {
        guard let user = currentUser, let token = SupabaseAuthService.shared.session?.accessToken
        else {
            return false
        }

        do {
            let ok = try await SupabaseInvitationService.shared.verifyInviteCode(
                code: code,
                userId: user.id,
                accessToken: token
            )
            if ok {
                isInvited = true
                saveUser()
                await SyncManager.shared.loadAll()
            }
            return ok
        } catch {
            return false
        }
    }
}

// MARK: - Learning Stats

@MainActor
class LearningStats: ObservableObject {
    static let shared = LearningStats()
    @Published var streak: Int = 0
    @Published var todayMinutes: Int = 0
    @Published var masteredCount: Int = 0
    @Published var learningCount: Int = 0
    @Published var masteryRate: Int = 0
    @Published var totalWords: Int = 0

    @Published var dailyHistory: [String: DailyEntry] = [:]

    struct DailyEntry: Codable {
        var words: Int
        var minutes: Int
        var subjects: [String: Int]
    }

    private let userDefaultsKey = "anki_hub_learning_stats"
    private let appGroupId = "group.com.ankihub.ios"

    init() {
        loadStats()
        syncTodayMinutesFromHistory()
        calculateStreak()
    }

    func applyStored(_ stored: StoredStats) {
        streak = stored.streak
        todayMinutes = stored.todayMinutes
        masteredCount = stored.masteredCount
        learningCount = stored.learningCount
        masteryRate = stored.masteryRate
        dailyHistory = stored.dailyHistory
        syncTodayMinutesFromHistory()
        calculateStreak()
    }

    func loadStats() {
        let groupDefaults = UserDefaults(suiteName: appGroupId)
        let data =
            groupDefaults?.data(forKey: userDefaultsKey)
            ?? UserDefaults.standard.data(forKey: userDefaultsKey)
        if let data,
            let decoded = try? JSONDecoder().decode(StoredStats.self, from: data)
        {
            streak = decoded.streak
            todayMinutes = decoded.todayMinutes
            masteredCount = decoded.masteredCount
            learningCount = decoded.learningCount
            masteryRate = decoded.masteryRate
            dailyHistory = decoded.dailyHistory
            syncTodayMinutesFromHistory()
            calculateStreak()
        }
    }

    private func syncTodayMinutesFromHistory() {
        let key = todayKey()
        todayMinutes = dailyHistory[key]?.minutes ?? 0
    }

    func saveStats() {
        let stored = StoredStats(
            streak: streak,
            todayMinutes: todayMinutes,
            masteredCount: masteredCount,
            learningCount: learningCount,
            masteryRate: masteryRate,
            dailyHistory: dailyHistory
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            if let groupDefaults = UserDefaults(suiteName: appGroupId) {
                groupDefaults.set(data, forKey: userDefaultsKey)
            }
        }

        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "StudyWidget")
        #endif

        SyncManager.shared.requestAutoSync()
    }

    func recordStudyMinutes(minutes: Int) {
        guard minutes > 0 else { return }
        let key = todayKey()

        var entry = dailyHistory[key] ?? DailyEntry(words: 0, minutes: 0, subjects: [:])
        entry.minutes += minutes
        dailyHistory[key] = entry

        todayMinutes = entry.minutes
        calculateStreak()
        saveStats()
    }

    func updateMasterySnapshot(from masteryItems: [String: [String: MasteryItem]]) {
        let all = masteryItems.values.flatMap { $0.values }
        let total = all.count
        let mastered = all.filter { $0.mastery == .mastered }.count
        let learning = all.filter { $0.mastery == .learning || $0.mastery == .almost }.count

        masteredCount = mastered
        learningCount = learning
        totalWords = total
        masteryRate = total == 0 ? 0 : Int((Double(mastered) / Double(total) * 100.0).rounded())
        saveStats()
    }

    func applyMasterySnapshot(from masteryItems: [String: [String: MasteryItem]]) {
        let all = masteryItems.values.flatMap { $0.values }
        let total = all.count
        let mastered = all.filter { $0.mastery == .mastered }.count
        let learning = all.filter { $0.mastery == .learning || $0.mastery == .almost }.count

        masteredCount = mastered
        learningCount = learning
        totalWords = total
        masteryRate = total == 0 ? 0 : Int((Double(mastered) / Double(total) * 100.0).rounded())
    }

    func recordStudySession(subject: String, wordsStudied: Int, minutes: Int) {
        let key = todayKey()

        var entry = dailyHistory[key] ?? DailyEntry(words: 0, minutes: 0, subjects: [:])

        if wordsStudied > 0 {
            entry.words += wordsStudied
            if !subject.isEmpty {
                entry.subjects[subject, default: 0] += wordsStudied
            }
        }
        if minutes > 0 {
            entry.minutes += minutes
        }
        dailyHistory[key] = entry

        todayMinutes = entry.minutes
        calculateStreak()
        saveStats()
    }

    func setDailyEntry(dateKey: String, words: Int, minutes: Int, subjects: [String: Int]) {
        dailyHistory[dateKey] = DailyEntry(words: words, minutes: minutes, subjects: subjects)
        if dateKey == todayKey() {
            todayMinutes = minutes
        }
        calculateStreak()
        saveStats()
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func calculateStreak() {
        let calendar = Calendar.current
        var currentStreak = 0
        var checkDate = Date()

        // Check if today has activity
        let todayK = todayKey()
        if let entry = dailyHistory[todayK], entry.words > 0 || entry.minutes > 0 {
            currentStreak = 1
        } else {
            // Check yesterday first
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count consecutive days
        while true {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: checkDate)

            if let entry = dailyHistory[key], entry.words > 0 || entry.minutes > 0 {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }

            if currentStreak > 365 { break }  // Safety limit
        }

        streak = currentStreak
    }

    struct StoredStats: Codable {
        var streak: Int
        var todayMinutes: Int
        var masteredCount: Int
        var learningCount: Int
        var masteryRate: Int
        var dailyHistory: [String: DailyEntry]
    }
}

// MARK: - Mastery Levels

enum MasteryLevel: Int, Codable, CaseIterable, Comparable {
    case new = 0  // 未学習
    case weak = 1  // 苦手
    case learning = 2  // うろ覚え
    case almost = 3  // ほぼ覚えた
    case mastered = 4  // 覚えた

    static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .new: return "未学習"
        case .weak: return "苦手"
        case .learning: return "うろ覚え"
        case .almost: return "ほぼ覚えた"
        case .mastered: return "覚えた"
        }
    }

    var color: Color {
        let theme = ThemeManager.shared
        let isDark = theme.effectiveIsDark
        switch self {
        case .new: return theme.currentPalette.color(.new, isDark: isDark)
        case .weak: return theme.currentPalette.color(.weak, isDark: isDark)
        case .learning: return theme.currentPalette.color(.learning, isDark: isDark)
        case .almost: return theme.currentPalette.color(.almost, isDark: isDark)
        case .mastered: return theme.currentPalette.color(.mastered, isDark: isDark)
        }
    }
}

// MARK: - Mastery Item

struct MasteryItem: Codable {
    var id: String
    var mastery: MasteryLevel
    var correct: Int
    var wrong: Int
    var consecutiveFast: Int
    var fluencyScore: Int  // 0-100
    var lastSeen: Date
    var lastChosenAnswerText: String?
    var lastCorrectAnswerText: String?
    var lastAnswerWasCorrect: Bool?
    var sessionHistory: [Int: SessionResult]  // SessionID: Result

    struct SessionResult: Codable {
        let correct: Bool
        let responseTime: TimeInterval
        let timestamp: Date
    }

    // Default Init
    init(id: String) {
        self.id = id
        self.mastery = .new
        self.correct = 0
        self.wrong = 0
        self.consecutiveFast = 0
        self.fluencyScore = 0
        self.lastSeen = Date()
        self.lastChosenAnswerText = nil
        self.lastCorrectAnswerText = nil
        self.lastAnswerWasCorrect = nil
        self.sessionHistory = [:]
    }
}

// MARK: - Mastery Tracker

@MainActor
class MasteryTracker: ObservableObject {
    static let shared = MasteryTracker()
    @Published var items: [String: [String: MasteryItem]] = [:]  // [Subject: [WordID: Item]]

    private let userDefaultsKey = "anki_hub_mastery_v2"

    init() {
        // Init happens on launch, load mostly async
    }

    func loadData() {
        Task {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                let decoded = try? JSONDecoder().decode(
                    [String: [String: MasteryItem]].self, from: data)
            {
                await MainActor.run {
                    self.items = decoded
                    LearningStats.shared.applyMasterySnapshot(from: decoded)
                }
            } else {
                await MainActor.run {
                    self.items = [:]
                    LearningStats.shared.applyMasterySnapshot(from: [:])
                }
            }
        }
    }

    func saveData() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }

        LearningStats.shared.updateMasterySnapshot(from: items)

        SyncManager.shared.requestAutoSync()
    }

    func getMastery(subject: String, wordId: String) -> MasteryLevel {
        items[subject]?[wordId]?.mastery ?? .new
    }

    func getFluency(subject: String, wordId: String) -> Int {
        items[subject]?[wordId]?.fluencyScore ?? 0
    }

    func recordAnswer(
        subject: String, wordId: String, isCorrect: Bool, responseTime: TimeInterval = 2.0,
        blankCount: Int = 1, sessionId: Int? = nil, chosenAnswerText: String? = nil,
        correctAnswerText: String? = nil
    ) {
        if items[subject] == nil { items[subject] = [:] }
        var item = items[subject]?[wordId] ?? MasteryItem(id: wordId)

        item.lastSeen = Date()
        item.lastChosenAnswerText = chosenAnswerText
        item.lastCorrectAnswerText = correctAnswerText
        item.lastAnswerWasCorrect = isCorrect

        if let sessionId {
            item.sessionHistory[sessionId] = MasteryItem.SessionResult(
                correct: isCorrect,
                responseTime: responseTime,
                timestamp: Date()
            )

            // Keep only latest 20 sessions (spec)
            if item.sessionHistory.count > 20 {
                let sortedKeys = item.sessionHistory.keys.sorted()
                let overflow = item.sessionHistory.count - 20
                for key in sortedKeys.prefix(overflow) {
                    item.sessionHistory.removeValue(forKey: key)
                }
            }
        }

        if isCorrect {
            // --- Fluency Score Calculation (0-100) ---
            var fluencyGain = 100
            if responseTime >= 10.0 {
                fluencyGain = 10
            } else if responseTime >= 5.0 {
                fluencyGain = 40
            } else if responseTime >= 2.0 {
                fluencyGain = 70
            }
            // else < 2.0 remains 100

            // Weighted moving average (New = 40%)
            item.fluencyScore = Int(Double(item.fluencyScore) * 0.6 + Double(fluencyGain) * 0.4)

            // --- Consecutive Fast Calculation ---
            if responseTime < 3.0 {
                item.consecutiveFast += 1
            } else {
                item.consecutiveFast = 0
            }

            // --- Time Limits for Promotion logic ---
            // Based on learning-core.js logic
            let fastLimit = 3.0 + Double(blankCount - 1) * 1.5
            let veryFastLimit = 1.5 + Double(blankCount - 1) * 1.0
            let slowLimit = 8.0 + Double(blankCount - 1) * 3.0

            let isFast = responseTime < fastLimit
            let isSlow = responseTime > slowLimit
            let isVeryFast = responseTime < veryFastLimit
            let highFluency = item.fluencyScore >= 80

            // --- Promotion Logic (Normal Difficulty Thresholds) ---
            // Thresholds: Learning=2, Almost=4, Mastered=6

            item.correct += 1

            switch item.mastery {
            case .new:
                // New -> Learning
                item.mastery = .learning
                item.correct = 0

            case .weak:
                // Weak -> Learning (Harder, requires 2 correct)
                if item.correct >= 2 {
                    item.mastery = .learning
                    item.correct = 0
                }

            case .learning:
                // Learning -> Almost (Base threshold: 4 - 2 = 2)
                let baseThreshold = 2
                var reqCorrect = baseThreshold
                if isFast {
                    reqCorrect = Int(ceil(Double(baseThreshold) / 2.0))
                }  // 1
                else if isSlow {
                    reqCorrect = baseThreshold * 2
                }  // 4

                if item.correct >= reqCorrect {
                    item.mastery = .almost
                    item.correct = 0
                }

            case .almost:
                // Almost -> Mastered (Base threshold: 6 - 4 = 2)
                let baseThreshold = 2
                var reqCorrect = baseThreshold

                if isFast {
                    reqCorrect = baseThreshold
                }  // 2
                else if isSlow {
                    reqCorrect = baseThreshold * 3
                }  // 6
                else {
                    reqCorrect = baseThreshold * 2
                }  // 4 (Normal speed penalty)

                // Special Promotion Conditions
                if isVeryFast && item.consecutiveFast >= 3 {
                    // Instant mastery for 3 consecutive very fast answers
                    item.mastery = .mastered
                    item.correct = 0
                } else if highFluency && item.correct >= baseThreshold {
                    // High fluency shortcut
                    item.mastery = .mastered
                    item.correct = 0
                } else if item.correct >= reqCorrect {
                    item.mastery = .mastered
                    item.correct = 0
                }

            case .mastered:
                break  // Already mastered
            }

        } else {
            // Incorrect
            item.wrong += 1
            item.correct = 0
            item.consecutiveFast = 0
            // Avoid collapsing everything to .weak; degrade one level.
            switch item.mastery {
            case .mastered:
                item.mastery = .almost
            case .almost:
                item.mastery = .learning
            case .learning:
                item.mastery = .weak
            case .weak, .new:
                item.mastery = .weak
            }
            item.fluencyScore = max(0, item.fluencyScore - 20)
        }

        items[subject]?[wordId] = item
        saveData()
    }

    func getStats(for subject: String) -> [MasteryLevel: Int] {
        guard let subjectData = items[subject] else { return [:] }

        var stats: [MasteryLevel: Int] = [:]
        for level in MasteryLevel.allCases {
            stats[level] = 0
        }

        for (_, item) in subjectData {
            stats[item.mastery, default: 0] += 1
        }

        return stats
    }
}

// MARK: - Subject

enum Subject: String, CaseIterable, Identifiable, Codable {
    case english = "english"
    case kobun = "kobun"
    case kanbun = "kanbun"
    case seikei = "seikei"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "英単語"
        case .kobun: return "古文"
        case .kanbun: return "漢文"
        case .seikei: return "政経"
        }
    }

    var icon: String {
        let isJapaneseLocale: Bool = {
            if #available(iOS 16.0, *) {
                return Locale.current.language.languageCode?.identifier == "ja"
            }
            return Locale.current.identifier.hasPrefix("ja")
        }()
        switch self {
        case .english:
            return isJapaneseLocale ? "character.book.closed" : "book.closed"
        case .kobun:
            // Use generic text book icons as specialized language variants might not exist in all SF Symbols versions
            return "text.book.closed"
        case .kanbun:
            return "text.book.closed.fill"
        case .seikei: return "books.vertical"
        }
    }

    var color: Color {
        let theme = ThemeManager.shared
        let isDark = theme.effectiveIsDark
        switch self {
        case .english: return theme.currentPalette.color(ThemeColorKey.primary, isDark: isDark)
        case .kobun: return theme.currentPalette.color(ThemeColorKey.selection, isDark: isDark)
        case .kanbun: return theme.currentPalette.color(ThemeColorKey.weak, isDark: isDark)
        case .seikei: return theme.currentPalette.color(ThemeColorKey.accent, isDark: isDark)
        }
    }

    var description: String {
        switch self {
        case .english: return "ターゲット1900"
        case .kobun: return "古典文法・単語"
        case .kanbun: return "句法・語彙"
        case .seikei: return "憲法・政治経済"
        }
    }
}

// Extension to MasteryTracker for Sorting Logic
extension MasteryTracker {
    private func retentionTargetDays() -> Int {
        let keyV2 = "anki_hub_target_date_timestamp_v2"
        let timestamp = UserDefaults.standard.double(forKey: keyV2)

        if timestamp == 0 {
            let raw = UserDefaults.standard.integer(forKey: "anki_hub_retention_target_days_v1")
            return raw == 0 ? 7 : raw
        }

        let targetDate = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.startOfDay(for: targetDate)

        let components = calendar.dateComponents([.day], from: startOfDay, to: endOfDay)
        let diff = components.day ?? 7

        return max(1, diff)
    }

    private func retentionScale() -> Double {
        let days = retentionTargetDays()
        return max(0.2, min(10.0, Double(days) / 7.0))
    }

    private func baseIntervalSeconds(for mastery: MasteryLevel) -> TimeInterval {
        switch mastery {
        case .weak:
            return 1 * 3600
        case .learning:
            return 4 * 3600
        case .almost:
            return 24 * 3600
        case .mastered:
            return 7 * 24 * 3600
        case .new:
            return 0
        }
    }

    private func intervalSeconds(itemId: String, subject: String) -> TimeInterval? {
        guard let item = self.items[subject]?[itemId], item.mastery != .new else { return nil }
        return baseIntervalSeconds(for: item.mastery) * retentionScale()
    }

    private func urgencyRatio(itemId: String, subject: String) -> Double {
        guard let item = self.items[subject]?[itemId],
            let interval = intervalSeconds(itemId: itemId, subject: subject),
            interval > 0
        else { return 0 }
        let elapsed = Date().timeIntervalSince(item.lastSeen)
        return elapsed / interval
    }

    private func isDue(itemId: String, subject: String) -> Bool {
        return urgencyRatio(itemId: itemId, subject: subject) >= 1.0
    }

    private func isDueSoon(itemId: String, subject: String) -> Bool {
        // "テスト日までに回数をこなす" ため、期限直前(>=80%)も優先する
        return urgencyRatio(itemId: itemId, subject: subject) >= 0.8
    }

    func getReviewCandidates(allItems: [Vocabulary], subject: String, includeDueSoon: Bool = true)
        -> [Vocabulary]
    {
        let filtered = allItems.filter { vocab in
            guard let item = self.items[subject]?[vocab.id] else { return false }
            if item.mastery == .new { return false }
            if isDue(itemId: vocab.id, subject: subject) { return true }
            if includeDueSoon, isDueSoon(itemId: vocab.id, subject: subject) { return true }
            return false
        }
        return sortByPriority(items: filtered, subject: subject)
    }

    // 優先度に基づいて問題をソート（忘却曲線を補助的に考慮）
    func sortByPriority(items: [Vocabulary], subject: String) -> [Vocabulary] {
        let priorityOrder: [MasteryLevel: Int] = [
            .weak: 0,
            .new: 1,
            .learning: 2,
            .almost: 3,
            .mastered: 4,
        ]

        func getForgetBoost(itemId: String) -> Double {
            guard let item = self.items[subject]?[itemId],
                item.mastery != .new,
                item.mastery != .weak
            else { return 0 }

            let hoursSince = Date().timeIntervalSince(item.lastSeen) / 3600.0
            let scale = retentionScale()

            if item.mastery == .mastered {
                if hoursSince >= 24 * 14 * scale { return 0.5 }
                if hoursSince >= 24 * 7 * scale { return 0.4 }
                if hoursSince >= 24 * 3 * scale { return 0.2 }
                return 0
            }

            if item.mastery == .almost || item.mastery == .learning {
                if hoursSince >= 24 * 3 * scale { return 0.8 }
                if hoursSince >= 24 * scale { return 0.5 }
                if hoursSince >= 12 * scale { return 0.3 }
                return 0
            }
            return 0
        }

        return items.sorted { a, b in
            let aDue = isDue(itemId: a.id, subject: subject)
            let bDue = isDue(itemId: b.id, subject: subject)
            if aDue != bDue { return aDue }

            // dueじゃなくても「期限が近い」ものを上へ（回数担保）
            let aSoon = isDueSoon(itemId: a.id, subject: subject)
            let bSoon = isDueSoon(itemId: b.id, subject: subject)
            if aSoon != bSoon { return aSoon }

            // 期限までの進み具合(=経過/間隔)が大きいほど優先
            let aUrgency = urgencyRatio(itemId: a.id, subject: subject)
            let bUrgency = urgencyRatio(itemId: b.id, subject: subject)
            if aUrgency != bUrgency { return aUrgency > bUrgency }

            let aItem = self.items[subject]?[a.id]
            let bItem = self.items[subject]?[b.id]

            let aMastery = aItem?.mastery ?? .new
            let bMastery = bItem?.mastery ?? .new

            let aBaseP = Double(priorityOrder[aMastery] ?? 4)
            let bBaseP = Double(priorityOrder[bMastery] ?? 4)

            let aBoost = getForgetBoost(itemId: a.id)
            let bBoost = getForgetBoost(itemId: b.id)

            let aFinal = aBaseP - aBoost
            let bFinal = bBaseP - bBoost

            return aFinal < bFinal
        }
    }

    func getSpacedRepetitionItems(allItems: [Vocabulary], subject: String) -> [Vocabulary] {
        let now = Date()

        return allItems.filter { vocab in
            guard let item = self.items[subject]?[vocab.id] else { return false }  // New items excluded from SR check usually, or handled separately
            if item.mastery == .new { return false }  // New items handled by normal flow

            let interval = baseIntervalSeconds(for: item.mastery) * retentionScale()
            return now.timeIntervalSince(item.lastSeen) >= interval
        }.sorted { a, b in
            let aM = self.items[subject]?[a.id]?.mastery ?? .mastered
            let bM = self.items[subject]?[b.id]?.mastery ?? .mastered
            return aM < bM  // Weak first
        }
    }

    func getDueCount(subject: String, allItems: [Vocabulary]) -> Int {
        getSpacedRepetitionItems(allItems: allItems, subject: subject).count
    }
}
