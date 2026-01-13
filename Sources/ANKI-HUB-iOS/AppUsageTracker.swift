import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class AppUsageTracker: ObservableObject {
    static let shared = AppUsageTracker()
    
    @Published var todayUsageMinutes: Int = 0
    @Published var weeklyUsageMinutes: Int = 0
    @Published var isAppActive: Bool = false
    
    private var sessionStartTime: Date?
    private var sessionDateKey: String?
    private var backgroundTime: Date?
    private let userDefaultsKey = "anki_hub_app_usage"
    private let appGroupId = "group.com.ankihub.ios"

    private var liveUpdateTask: Task<Void, Never>?
    
    // Weekly target: 120 minutes
    private let weeklyTargetMinutes: Int = 120
    
    public struct UsageEntry: Codable {
        var date: String // yyyy-MM-dd
        var usageMinutes: Int
        var sessions: [SessionEntry]
        
        public struct SessionEntry: Codable {
            var startTime: Date
            var endTime: Date?
            var duration: Int // minutes
        }
    }
    
    private var usageHistory: [String: UsageEntry] = [:]
    
    init() {
        loadUsageHistory()
        setupNotifications()
    }
    
    func applicationDidBecomeActive() {
        isAppActive = true
        sessionStartTime = Date()
        sessionDateKey = todayKey()
        startLiveUpdateLoop()
        
        // If returning from background within 5 minutes, continue previous session
        if let backgroundTime = backgroundTime,
           Date().timeIntervalSince(backgroundTime) < 300 {
            // Continue previous session
        } else {
            // Start new session
        }
        backgroundTime = nil
    }
    
    func applicationWillResignActive() {
        isAppActive = false
        stopLiveUpdateLoop()
        endCurrentSession()
        backgroundTime = Date()
    }
    
    func applicationDidEnterBackground() {
        isAppActive = false
        stopLiveUpdateLoop()
        endCurrentSession()
        backgroundTime = Date()
    }
    
    func applicationWillEnterForeground() {
        // Will become active shortly
    }
    
    private func endCurrentSession() {
        guard let startTime = sessionStartTime else { return }
        
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
        
        if duration > 0 {
            recordUsageSession(startTime: startTime, endTime: endTime, duration: duration)
        }
        
        sessionStartTime = nil
        sessionDateKey = nil
    }
    
    private func recordUsageSession(startTime: Date, endTime: Date, duration: Int) {
        let today = sessionDateKey ?? todayKey()
        let session = UsageEntry.SessionEntry(
            startTime: startTime,
            endTime: endTime,
            duration: duration
        )
        
        var entry = usageHistory[today] ?? UsageEntry(date: today, usageMinutes: 0, sessions: [])
        entry.usageMinutes += duration
        entry.sessions.append(session)
        
        usageHistory[today] = entry
        todayUsageMinutes = entry.usageMinutes
        weeklyUsageMinutes = calculateWeeklyUsage()
        
        saveUsageHistory()
    }

    private func startLiveUpdateLoop() {
        liveUpdateTask?.cancel()
        liveUpdateTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // 省電力：1秒更新はしない（分が変わる程度で十分）
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { break }
                guard self.isAppActive else { continue }
                self.refreshLiveUsage()
            }
        }
        refreshLiveUsage()
    }

    private func stopLiveUpdateLoop() {
        liveUpdateTask?.cancel()
        liveUpdateTask = nil
    }

    private func refreshLiveUsage() {
        // 日付跨ぎ対策：日付が変わっていたら一旦セッションを区切る
        if let sessionDateKey, sessionDateKey != todayKey() {
            endCurrentSession()
            sessionStartTime = Date()
            self.sessionDateKey = todayKey()
        }

        let liveMinutes = computeLiveTodayMinutes()
        if todayUsageMinutes != liveMinutes {
            todayUsageMinutes = liveMinutes
            weeklyUsageMinutes = calculateWeeklyUsage() + computeLiveSessionMinutesIfNeeded()
        }
    }

    private func computeLiveTodayMinutes() -> Int {
        let today = todayKey()
        let base = usageHistory[today]?.usageMinutes ?? 0
        return base + computeLiveSessionMinutesIfNeeded()
    }

    private func computeLiveSessionMinutesIfNeeded() -> Int {
        guard isAppActive, let start = sessionStartTime else { return 0 }
        let minutes = Int(Date().timeIntervalSince(start) / 60)
        return max(0, minutes)
    }
    
    private func calculateWeeklyUsage() -> Int {
        let calendar = Calendar.current
        let today = Date()
        var weeklyTotal = 0
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = dateKey(from: date)
                weeklyTotal += usageHistory[key]?.usageMinutes ?? 0
            }
        }
        
        return weeklyTotal
    }
    
    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func loadUsageHistory() {
        let groupDefaults = UserDefaults(suiteName: appGroupId)
        let data = groupDefaults?.data(forKey: userDefaultsKey) ?? UserDefaults.standard.data(forKey: userDefaultsKey)
        
        if let data, let decoded = try? JSONDecoder().decode([String: UsageEntry].self, from: data) {
            usageHistory = decoded
            todayUsageMinutes = usageHistory[todayKey()]?.usageMinutes ?? 0
            weeklyUsageMinutes = calculateWeeklyUsage()
        }
    }
    
    private func saveUsageHistory() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            if let groupDefaults = UserDefaults(suiteName: appGroupId) {
                groupDefaults.set(data, forKey: userDefaultsKey)
            }
        }
        
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "StudyWidget")
        #endif
    }
    
    private func setupNotifications() {
        // Setup weekly usage notifications
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActiveNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActiveNotification),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    func getWeeklyProgress() -> Double {
        return Double(weeklyUsageMinutes) / Double(weeklyTargetMinutes)
    }
    
    func getUsageHistory(days: Int = 7) -> [UsageEntry] {
        let calendar = Calendar.current
        let today = Date()
        var history: [UsageEntry] = []
        
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = dateKey(from: date)
                if let entry = usageHistory[key] {
                    history.append(entry)
                }
            }
        }
        
        return history.sorted { $0.date > $1.date }
    }
    
    func clearOldData() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffKey = dateKey(from: cutoffDate)
        
        usageHistory = usageHistory.filter { $0.key >= cutoffKey }
        saveUsageHistory()
    }
}

// MARK: - Notification Selectors
#if os(iOS)
@objc extension AppUsageTracker {
    private func applicationDidBecomeActiveNotification() {
        applicationDidBecomeActive()
    }
    
    private func applicationWillResignActiveNotification() {
        applicationWillResignActive()
    }
    
    private func applicationDidEnterBackgroundNotification() {
        applicationDidEnterBackground()
    }
    
    private func applicationWillEnterForegroundNotification() {
        applicationWillEnterForeground()
    }
}
#endif
