import Foundation
import Combine

@MainActor
class InputModeManager: ObservableObject {
    static let shared = InputModeManager()
    
    // Status tracking separate from MasteryTracker
    struct InputData: Codable {
        var id: String
        var status: String // "known", "unknown", "weak"
        var lastReview: Date
    }
    
    @Published var data: [String: InputData] = [:] // WordID: Data
    @Published var currentDay: Int = 1 // 1, 2, 3
    
    private let key = "anki_hub_input_mode_v1"
    
    private init() {
        loadData()
    }
    
    func loadData() {
        if let stored = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: InputData].self, from: stored) {
            data = decoded
        }
    }
    
    func saveData() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }

        SyncManager.shared.requestAutoSync()
    }
    
    // MARK: - Core Logic per Day
    
    // Day 1: Sorting into Known/Unknown
    func processDay1(wordId: String, isKnown: Bool) {
        var item = data[wordId] ?? InputData(id: wordId, status: "unknown", lastReview: Date())
        item.status = isKnown ? "known" : "unknown"
        item.lastReview = Date()
        data[wordId] = item
        saveData()
    }
    
    // Day 2: Quick Judgment (Time Limit based)
    // Target: "unknown" words from Day 1 need review.
    func processDay2(wordId: String, isCorrect: Bool, responseTime: TimeInterval) {
        var item = data[wordId] ?? InputData(id: wordId, status: "unknown", lastReview: Date())
        
        let timeLimit = 1.5 // Tight limit for Day 2
        
        if isCorrect && responseTime < timeLimit {
            item.status = "known"
        } else {
            item.status = "weak"
        }
        item.lastReview = Date()
        data[wordId] = item
        saveData()
    }
    
    // Day 3: Fixation / Weak Review
    // Target: "weak" words
    func processDay3(wordId: String, isCorrect: Bool) {
        var item = data[wordId] ?? InputData(id: wordId, status: "weak", lastReview: Date())
        
        if isCorrect {
            item.status = "known" // Finally mastered
        } else {
            item.status = "weak" // Keep as weak
        }
        item.lastReview = Date()
        data[wordId] = item
        saveData()
    }
    
    // MARK: - Data Retrieval
    
    func getWordsForDay(_ day: Int, allWords: [Vocabulary]) -> [Vocabulary] {
        switch day {
        case 1:
            // All words, or words never seen? 
            // Usually Day 1 processes new batch.
            // For demo/simplicity, return all words that don't have "known" status yet?
            return allWords.filter { data[$0.id] == nil } // Fresh words
            
        case 2:
            // "unknown" words from Day 1
            return allWords.filter { data[$0.id]?.status == "unknown" }
            
        case 3:
            // "weak" words from Day 2
            return allWords.filter { data[$0.id]?.status == "weak" }
            
        default:
            return []
        }
    }
    
    func resetData() {
        data = [:]
        saveData()
    }
}
