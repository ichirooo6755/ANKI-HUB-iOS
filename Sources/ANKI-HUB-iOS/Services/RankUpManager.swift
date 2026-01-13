import Foundation
import SwiftUI

class RankUpManager: ObservableObject {
    static let shared = RankUpManager()
    
    @Published var unlockedChunks: [String: Int] = [:] // Subject: Max Unlocked Chunk Index (1-based count in JS, 0-based index here? JS says unlockedChunks starts at 1)
    // JS unlockedChunks = 1 means Chunk 0 is unlocked.
    // Let's stick to: value is the COUNT of unlocked chunks.
    // So 1 means index 0 is available.
    
    @Published var completedTests: [RankUpResult] = []
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var passRate: Int = 80
    @Published var testQuestionCount: Int = 50
    
    struct RankUpResult: Codable {
        let subject: String
        let chunkIndex: Int
        let date: Date
        let streak: Int
    }
    
    private let userDefaultsKey = "anki_hub_rank_up"
    
    init() {
        loadData()
    }
    
    func loadData() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(StoredData.self, from: data) {
            unlockedChunks = decoded.unlockedChunks
            completedTests = decoded.completedTests
            currentStreak = decoded.currentStreak
            bestStreak = decoded.bestStreak
            passRate = decoded.passRate
            testQuestionCount = decoded.testQuestionCount
        } else {
            // Initialize defaults (1 chunk unlocked for each subject)
            unlockedChunks = [
                Subject.english.rawValue: 1, // Start with 1 chunk unlocked
                Subject.kobun.rawValue: 1,
                Subject.kanbun.rawValue: 1,
                Subject.seikei.rawValue: 1
            ]
            // Seikei might default to all unlocked? JS: chaptersUnlocked: true
            // We can handle that in the UI or here.
            unlockedChunks[Subject.seikei.rawValue] = 999 // Unlock all for Seikei
        }
    }
    
    func saveData() {
        let data = StoredData(
            unlockedChunks: unlockedChunks,
            completedTests: completedTests,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            passRate: passRate,
            testQuestionCount: testQuestionCount
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }

        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
    }
    
    func getUnlockedChunkCount(for subject: Subject) -> Int {
        return unlockedChunks[subject.rawValue] ?? 1
    }
    
    func canTakeRankUpTest(for subject: Subject) -> Bool {
        let current = getUnlockedChunkCount(for: subject)
        let total = VocabularyData.shared.getChunkCount(for: subject)
        return current < total
    }
    
    func startTest() {
        currentStreak = 0
        saveData()
    }
    
    func recordTestAnswer(isCorrect: Bool) {
        if isCorrect {
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        } else {
            currentStreak = 0
        }
        saveData()
    }
    
    func checkTestResult(correctCount: Int, totalCount: Int) -> Bool {
        guard totalCount > 0 else { return false }
        let percentage = Double(correctCount) / Double(totalCount) * 100
        return percentage >= Double(passRate)
    }
    
    func completeRankUpTest(for subject: Subject) {
        let current = getUnlockedChunkCount(for: subject)
        unlockedChunks[subject.rawValue] = current + 1
        
        completedTests.append(RankUpResult(
            subject: subject.rawValue,
            chunkIndex: current, // The chunk that was just unlocked (index is current count?) No, we just finished the test FOR chunk 'current', so we unlock 'current + 1'
            // In JS: unlockedChunks++; completed chunk = unlockedChunks - 1.
            date: Date(),
            streak: currentStreak
        ))
        
        currentStreak = 0
        saveData()
    }
    
    struct StoredData: Codable {
        var unlockedChunks: [String: Int]
        var completedTests: [RankUpResult]
        var currentStreak: Int
        var bestStreak: Int
        var passRate: Int
        var testQuestionCount: Int
    }
}
