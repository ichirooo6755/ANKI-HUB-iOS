import SwiftUI

@main
struct ANKIHUBApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var learningStats = LearningStats.shared
    @StateObject private var masteryTracker = MasteryTracker.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var rankUpManager = RankUpManager.shared
    @StateObject private var appUsageTracker = AppUsageTracker.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
            .environmentObject(authManager)
            .environmentObject(learningStats)
            .environmentObject(masteryTracker)
            .environmentObject(themeManager)
            .environmentObject(rankUpManager)
            .environmentObject(appUsageTracker)
        }
    }
}
