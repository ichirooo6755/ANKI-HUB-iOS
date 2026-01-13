import Foundation
import SwiftUI

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // private let supabaseUrl = URL(string: "https://uahrjcauawtftpecpxsq.supabase.co")!
    // private let supabaseAnonKey = "..."

    // let client: SupabaseClient

    // MARK: - App State
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil

    private var syncDebounceTask: Task<Void, Never>? = nil
    private var lastLoadAttemptAt: Date? = nil
    private var isApplyingRemoteData: Bool = false

    private var isPerformingSync: Bool = false
    private var pendingSyncRequested: Bool = false

    private var isPerformingLoad: Bool = false
    private var pendingLoadRequested: Bool = false

    // Spec v2 (storage.js)
    private let debounceSeconds: TimeInterval = 2.0
    private let minLoadIntervalSeconds: TimeInterval = 30.0

    private func logSyncError(_ context: String, _ error: Error) {
        if let httpErr = error as? SupabaseHTTPClient.HTTPError {
            switch httpErr {
            case .invalidURL:
                print("[Sync] ERROR(\(context)): invalidURL")
            case .invalidResponse:
                print("[Sync] ERROR(\(context)): invalidResponse")
            case .httpError(let statusCode, let body):
                print("[Sync] ERROR(\(context)): http \(statusCode) body=\(body)")
            }
            return
        }
        print("[Sync] ERROR(\(context)): \(error)")
    }

    private func runWithRetry(
        _ label: String,
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> Void
    ) async throws {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                try await operation()
                return
            } catch {
                lastError = error
                logSyncError("\(label) attempt \(attempt)", error)
                if attempt == maxAttempts { break }
                let delaySeconds = Double(min(8, Int(pow(2.0, Double(attempt - 1)))))
                try? await Task.sleep(for: .seconds(delaySeconds))
            }
        }
        throw lastError ?? SupabaseHTTPClient.HTTPError.invalidResponse
    }

    private init() {
        // self.client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseAnonKey)
    }

    // MARK: - Constants

    enum AppID: String, CaseIterable {
        case stats = "stats"
        case english = "english"
        case kobun = "kobun"
        case kanbun = "kanbun"
        case seikei = "seikei"
        case wordbook = "wordlist"
        case theme = "theme"
        case rankUp = "rank_up"
        case examScores = "exam_scores"
        case retention = "retention"
        case todo = "todo"
        case inputMode = "input_mode"
    }

    // MARK: - Sync Operations

    /// Spec v2: auto-sync trigger (called after local saves). This schedules a debounced sync
    /// only when user is logged-in + invited and session token exists.
    func requestAutoSync() {
        guard !isApplyingRemoteData else { return }
        guard AuthManager.shared.currentUser != nil else { return }
        guard AuthManager.shared.isInvited else { return }
        guard SupabaseAuthService.shared.session?.accessToken != nil else { return }

        if isPerformingSync {
            pendingSyncRequested = true
            return
        }

        Task {
            await SyncManager.shared.syncAllDebounced()
        }
    }

    /// Spec v2: Debounced sync (2 seconds). Cancels previous scheduled sync.
    func syncAllDebounced() async {
        syncDebounceTask?.cancel()

        // Indicate syncing state immediately (even while waiting) like web app's debounce save.
        isSyncing = true

        let task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.debounceSeconds))
            if Task.isCancelled {
                self.isSyncing = false
                return
            }
            await self.syncAll()
        }

        syncDebounceTask = task
        await task.value
    }

    /// Sync All Data (Upload Local to Cloud)
    func syncAll() async {
        if isPerformingSync {
            pendingSyncRequested = true
            return
        }

        isPerformingSync = true
        isSyncing = true
        defer {
            isPerformingSync = false
            isSyncing = false
        }

        guard let user = AuthManager.shared.currentUser,
            SupabaseAuthService.shared.session?.accessToken != nil
        else {
            return
        }

        await SupabaseAuthService.shared.refreshIfNeeded()

        guard let freshToken = SupabaseAuthService.shared.session?.accessToken else {
            return
        }

        do {
            try await self.runWithRetry("syncAll") {
                try await self.performSyncAll(userId: user.id, accessToken: freshToken)
            }
            lastSyncDate = Date()
        } catch {
            logSyncError("syncAll", error)
        }

        if pendingSyncRequested {
            pendingSyncRequested = false
            await syncAll()
        }
    }

    private func performSyncAll(userId: String, accessToken: String) async throws {
        // 1) Learning Stats
        let stats = LearningStats.shared
        let storedStats = LearningStats.StoredStats(
            streak: stats.streak,
            todayMinutes: stats.todayMinutes,
            masteredCount: stats.masteredCount,
            learningCount: stats.learningCount,
            masteryRate: stats.masteryRate,
            dailyHistory: stats.dailyHistory
        )
        let statsData = try JSONEncoder().encode(storedStats)
        let statsAny = try JSONSerialization.jsonObject(with: statsData, options: [])
        try await SupabaseStudyService.shared.upsert(
            userId: userId, appId: AppID.stats.rawValue, data: statsAny,
            accessToken: accessToken)

        // 2) Mastery per subject
        let mastery = MasteryTracker.shared
        for subject in [Subject.english, .kobun, .kanbun, .seikei] {
            let perSubject = mastery.items[subject.rawValue] ?? [:]
            let encoded = try JSONEncoder().encode(perSubject)
            let any = try JSONSerialization.jsonObject(with: encoded, options: [])
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: subject.rawValue, data: any, accessToken: accessToken)
        }

        // 3) Wordbook
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: AppID.wordbook.rawValue, data: any,
                accessToken: accessToken)
        }

        // 4) RankUp
        if let data = UserDefaults.standard.data(forKey: "anki_hub_rank_up"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: AppID.rankUp.rawValue, data: any,
                accessToken: accessToken)
        }

        // 5) Theme
        let themeId = UserDefaults.standard.string(forKey: "selectedThemeId") ?? "default"
        let wallpaperKind =
            UserDefaults.standard.string(forKey: "anki_hub_wallpaper_kind") ?? ""
        let wallpaperValue =
            UserDefaults.standard.string(forKey: "anki_hub_wallpaper_value") ?? ""
        var masteryColorsAny: Any = NSNull()
        if let data = UserDefaults.standard.data(forKey: "anki_hub_mastery_colors_v1"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            masteryColorsAny = any
        }
        let themeAny: [String: Any] = [
            "selectedThemeId": themeId,
            "wallpaperKind": wallpaperKind,
            "wallpaperValue": wallpaperValue,
            "masteryColors": masteryColorsAny,
        ]
        try await SupabaseStudyService.shared.upsert(
            userId: userId, appId: AppID.theme.rawValue, data: themeAny,
            accessToken: accessToken)

        // 6) Past exam scores
        if let data = UserDefaults.standard.data(forKey: "anki_hub_exam_scores_v1"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: AppID.examScores.rawValue, data: any,
                accessToken: accessToken)
        }

        // 7) Todo
        if let data = UserDefaults.standard.data(forKey: "anki_hub_todo_items_v1"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: AppID.todo.rawValue, data: any,
                accessToken: accessToken)
        }

        // 8) Input Mode
        if let data = UserDefaults.standard.data(forKey: "anki_hub_input_mode_v1"),
            let any = try? JSONSerialization.jsonObject(with: data, options: [])
        {
            try await SupabaseStudyService.shared.upsert(
                userId: userId, appId: AppID.inputMode.rawValue, data: any,
                accessToken: accessToken)
        }

        // 9) Retention target days
        let storedDays = UserDefaults.standard.integer(forKey: "anki_hub_retention_target_days_v1")
        let fallbackDays = storedDays == 0 ? 7 : storedDays
        let kobunInputModeUseAll = UserDefaults.standard.bool(
            forKey: "anki_hub_kobun_inputmode_use_all_v1")
        let day2LimitSeconds = UserDefaults.standard.double(forKey: "anki_hub_inputmode_day2_limit_v1")
        let day2UnknownOnly = UserDefaults.standard.bool(forKey: "anki_hub_inputmode_day2_unknown_only_v1")
        let inputModeMistakesOnly = UserDefaults.standard.bool(forKey: "anki_hub_inputmode_mistakes_only_v1")
        let storedTimestamp = UserDefaults.standard.double(forKey: "anki_hub_target_date_timestamp_v2")

        // Prefer v2 timestamp. If missing, derive from v1 days.
        let targetDateTimestamp: Double = {
            if storedTimestamp != 0 { return storedTimestamp }
            let date = Calendar.current.date(byAdding: .day, value: fallbackDays, to: Date()) ?? Date()
            return date.timeIntervalSince1970
        }()

        // Keep legacy field for compatibility
        let targetDays: Int = {
            if storedTimestamp == 0 { return fallbackDays }
            let targetDate = Date(timeIntervalSince1970: targetDateTimestamp)
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.startOfDay(for: targetDate)
            let diff = calendar.dateComponents([.day], from: start, to: end).day ?? fallbackDays
            return max(1, diff)
        }()
        let retentionAny: [String: Any] = [
            "targetDays": targetDays,
            "kobunInputModeUseAll": kobunInputModeUseAll,
            "day2LimitSeconds": day2LimitSeconds,
            "day2UnknownOnly": day2UnknownOnly,
            "inputModeMistakesOnly": inputModeMistakesOnly,
            "targetDateTimestamp": targetDateTimestamp,
        ]
        try await SupabaseStudyService.shared.upsert(
            userId: userId, appId: AppID.retention.rawValue, data: retentionAny,
            accessToken: accessToken)
    }

    /// Load All Data (Download Cloud to Local)
    func loadAll(force: Bool = false) async {
        if isPerformingLoad {
            pendingLoadRequested = true
            return
        }

        isPerformingLoad = true
        isSyncing = true
        defer {
            isPerformingLoad = false
            isSyncing = false
        }

        if !force, let last = lastLoadAttemptAt,
            Date().timeIntervalSince(last) < minLoadIntervalSeconds
        {
            return
        }
        lastLoadAttemptAt = Date()

        guard let user = AuthManager.shared.currentUser,
            SupabaseAuthService.shared.session?.accessToken != nil
        else {
            return
        }

        await SupabaseAuthService.shared.refreshIfNeeded()

        guard let freshToken = SupabaseAuthService.shared.session?.accessToken else {
            return
        }

        do {
            try await self.runWithRetry("loadAll") {
                try await self.performLoadAll(userId: user.id, accessToken: freshToken)
            }
        } catch {
            logSyncError("loadAll", error)
        }

        if pendingLoadRequested {
            pendingLoadRequested = false
            await loadAll(force: true)
        }
    }

    private func performLoadAll(userId: String, accessToken: String) async throws {
        isApplyingRemoteData = true
        defer { isApplyingRemoteData = false }
        do {
            // 1) Learning Stats
            let legacyStatsAppId = "learning_stats"
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.stats.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                let decoded = try JSONDecoder().decode(LearningStats.StoredStats.self, from: data)
                LearningStats.shared.applyStored(decoded)
                LearningStats.shared.saveStats()
            } else if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: legacyStatsAppId, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                let decoded = try JSONDecoder().decode(LearningStats.StoredStats.self, from: data)
                LearningStats.shared.applyStored(decoded)
                LearningStats.shared.saveStats()
            }

            // 2) Mastery per subject
            for subject in [Subject.english, .kobun, .kanbun, .seikei] {
                if let any = try await SupabaseStudyService.shared.fetch(
                    userId: userId, appId: subject.rawValue, accessToken: accessToken),
                    JSONSerialization.isValidJSONObject(any),
                    let data = try? JSONSerialization.data(withJSONObject: any, options: [])
                {
                    let decoded = try JSONDecoder().decode([String: MasteryItem].self, from: data)
                    MasteryTracker.shared.items[subject.rawValue] = decoded
                }
            }
            MasteryTracker.shared.saveData()

            // 3) Wordbook
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.wordbook.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
            }

            // 4) RankUp
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.rankUp.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                UserDefaults.standard.set(data, forKey: "anki_hub_rank_up")
                RankUpManager.shared.loadData()
            }

            // 5) Theme
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.theme.rawValue, accessToken: accessToken)
                as? [String: Any]
            {
                if let selected = any["selectedThemeId"] as? String {
                    ThemeManager.shared.applyTheme(id: selected)
                }
                if let kind = any["wallpaperKind"] as? String,
                    let value = any["wallpaperValue"] as? String,
                    !kind.isEmpty
                {
                    ThemeManager.shared.applyWallpaper(kind: kind, value: value)
                }
                if let masteryColors = any["masteryColors"],
                    !(masteryColors is NSNull),
                    let data = try? JSONSerialization.data(
                        withJSONObject: masteryColors, options: [])
                {
                    UserDefaults.standard.set(data, forKey: "anki_hub_mastery_colors_v1")

                    if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                        let palette = ThemeManager.shared.currentPalette
                        ThemeManager.shared.applyMasteryColors(
                            new: Color(hex: dict["new"] ?? palette.new),
                            weak: Color(hex: dict["weak"] ?? palette.weak),
                            learning: Color(hex: dict["learning"] ?? palette.learning),
                            almost: Color(hex: dict["almost"] ?? palette.almost),
                            mastered: Color(hex: dict["mastered"] ?? palette.mastered)
                        )
                    }
                }
            }

            // 6) Past exam scores
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.examScores.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                UserDefaults.standard.set(data, forKey: "anki_hub_exam_scores_v1")
            }

            // 7) Todo
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.todo.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                UserDefaults.standard.set(data, forKey: "anki_hub_todo_items_v1")
                NotificationCenter.default.post(name: Notification.Name("anki_hub_todo_items_updated"), object: nil)
            }

            // 8) Input Mode
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.inputMode.rawValue, accessToken: accessToken),
                JSONSerialization.isValidJSONObject(any),
                let data = try? JSONSerialization.data(withJSONObject: any, options: [])
            {
                UserDefaults.standard.set(data, forKey: "anki_hub_input_mode_v1")
                InputModeManager.shared.loadData()
            }

            // 9) Retention target days
            if let any = try await SupabaseStudyService.shared.fetch(
                userId: userId, appId: AppID.retention.rawValue, accessToken: accessToken)
                as? [String: Any]
            {
                if let useAll = any["kobunInputModeUseAll"] as? Bool {
                    UserDefaults.standard.set(useAll, forKey: "anki_hub_kobun_inputmode_use_all_v1")
                }

                if let limit = any["day2LimitSeconds"] as? Double, limit != 0 {
                    UserDefaults.standard.set(limit, forKey: "anki_hub_inputmode_day2_limit_v1")
                }

                if let unknownOnly = any["day2UnknownOnly"] as? Bool {
                    UserDefaults.standard.set(unknownOnly, forKey: "anki_hub_inputmode_day2_unknown_only_v1")
                }

                if let mistakesOnly = any["inputModeMistakesOnly"] as? Bool {
                    UserDefaults.standard.set(mistakesOnly, forKey: "anki_hub_inputmode_mistakes_only_v1")
                }

                if let ts = any["targetDateTimestamp"] as? Double, ts != 0 {
                    UserDefaults.standard.set(ts, forKey: "anki_hub_target_date_timestamp_v2")
                }

                // Backward compatibility: if only days exist, persist v1 and derive v2.
                if let days = any["targetDays"] as? Int {
                    let normalized = days == 0 ? 7 : days
                    UserDefaults.standard.set(normalized, forKey: "anki_hub_retention_target_days_v1")

                    let existingTs = UserDefaults.standard.double(forKey: "anki_hub_target_date_timestamp_v2")
                    if existingTs == 0 {
                        let date = Calendar.current.date(byAdding: .day, value: normalized, to: Date()) ?? Date()
                        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "anki_hub_target_date_timestamp_v2")
                    }
                }
            }

            lastSyncDate = Date()
        } catch {
            // Keep lastSyncDate as-is
        }
    }

    // MARK: - Helper Functions (Mocked for reference)

    /*
    func save<T: Encodable>(appId: String, data: T) async throws {
        // Implementation for Supabase upsert
    }
    
    func load<T: Decodable>(appId: String, type: T.Type) async throws -> T? {
        // Implementation for Supabase select
        return nil
    }
    */
}
