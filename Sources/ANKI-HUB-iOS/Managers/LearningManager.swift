import Foundation
import Combine

@MainActor
class LearningManager: ObservableObject {
    static let shared = LearningManager()
    
    @Published var currentSessionCount: Int = 0
    private let sessionKey = "anki_hub_session_count"
    
    private init() {
        loadSessionCount()
    }
    
    private func loadSessionCount() {
        currentSessionCount = UserDefaults.standard.integer(forKey: sessionKey)
    }
    
    func incrementSessionCount() {
        currentSessionCount += 1
        UserDefaults.standard.set(currentSessionCount, forKey: sessionKey)
    }
    
    /// Replicates `selectQuestionsWithHistory` from `learning-core.js`
    func selectQuestionsWithHistory(words: [Vocabulary], count: Int, subject: String, masteryTracker: MasteryTracker) -> [Vocabulary] {
        var immediateWords: [Vocabulary] = []
        var delayedWords: [Vocabulary] = []
        var excludedWords: [Vocabulary] = []
        
        for word in words {
            let item = masteryTracker.items[subject]?[word.id]
            
            // If no history, it's new/immediate
            guard let history = item?.sessionHistory.values.sorted(by: { $0.timestamp > $1.timestamp }).first,
                  let lastSessionID = item?.sessionHistory.keys.max() else {
                immediateWords.append(word)
                continue
            }
            
            // Logic from learning-core.js:
            // if (correct && responseTime < 5000) -> excluded (mastered/fast enough)
            // if (correct && responseTime >= 5000) -> delayed checks
            
            if history.correct && history.responseTime < 5.0 {
                // Fully Mastered for now (in this session context)
                // But wait, existing logic says "Correct and Fast" -> Excluded
                excludedWords.append(word)
            } else if history.correct && history.responseTime >= 5.0 {
                // Correct but slow
                // if (sessionCount >= wordHistory.session + 2) -> delayed (bring back)
                // else -> excluded (wait more)
                
                if currentSessionCount >= lastSessionID + 2 {
                    delayedWords.append(word)
                } else {
                    excludedWords.append(word)
                }
            } else {
                // Incorrect or weird state -> Immediate
                immediateWords.append(word)
            }
        }
        
        // Sorting function based on mastery (Weak > New > Learning > Almost > Mastered)
        func sortByMastery(_ items: [Vocabulary]) -> [Vocabulary] {
            let shuffled = items.shuffled()
            return shuffled.sorted { a, b in
                let m1 = masteryTracker.getMastery(subject: subject, wordId: a.id)
                let m2 = masteryTracker.getMastery(subject: subject, wordId: b.id)
                
                // Priority Map (lower is higher priority)
                let p1 = priority(for: m1)
                let p2 = priority(for: m2)
                
                return p1 < p2
            }
        }
        
        func priority(for level: MasteryLevel) -> Int {
            switch level {
            case .weak: return 0
            case .new: return 1
            case .learning: return 2
            case .almost: return 3
            case .mastered: return 4
            }
        }
        
        let sortedImmediate = sortByMastery(immediateWords)
        let sortedDelayed = sortByMastery(delayedWords)
        
        var finalList = sortedImmediate + sortedDelayed

        // If we don't have enough items to satisfy the requested count,
        // backfill from excluded words (avoid duplicates).
        if finalList.count < count {
            let usedIds = Set(finalList.map { $0.id })
            let backfill = sortByMastery(excludedWords).filter { !usedIds.contains($0.id) }
            let needed = max(0, count - finalList.count)
            if needed > 0 {
                finalList.append(contentsOf: backfill.prefix(needed))
            }
        }
        
        // If list is empty (user cleared everything needed), maybe bring back some excluded/review words?
        // logic says: if (finalList.length === 0) finalList = sortByMastery([...excludedWords])
        if finalList.isEmpty {
            finalList = sortByMastery(excludedWords)
        }
        
        return Array(finalList.prefix(count))
    }
}
