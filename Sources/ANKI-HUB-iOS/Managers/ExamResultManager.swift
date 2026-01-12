import Foundation
import SwiftUI

struct ExamResult: Identifiable, Codable {
    var id: UUID = UUID()
    var year: Int
    var type: ExamType
    var subject: String  // 科目
    var university: String
    var faculty: String
    var score: Int
    var total: Int
    var percent: Int
    var date: Date
    var reflection: String  // 反省点

    enum ExamType: String, Codable, CaseIterable {
        case common = "common"
        case common_l = "common_l"
        case secondary = "secondary"
        case private_u = "private"
        case mock = "mock"  // 模試

        var label: String {
            switch self {
            case .common: return "共通テスト(R)"
            case .common_l: return "共通テスト(L)"
            case .secondary: return "二次試験"
            case .private_u: return "私大"
            case .mock: return "模試"
            }
        }
    }

    // Migration support for old data without subject/reflection
    init(
        id: UUID = UUID(), year: Int, type: ExamType, subject: String = "", university: String = "",
        faculty: String = "", score: Int, total: Int, percent: Int, date: Date, reflection: String = ""
    ) {
        self.id = id
        self.year = year
        self.type = type
        self.subject = subject
        self.university = university
        self.faculty = faculty
        self.score = score
        self.total = total
        self.percent = percent
        self.date = date
        self.reflection = reflection
    }
}

@MainActor
class ExamResultManager: ObservableObject {
    @Published var results: [ExamResult] = []

    private let key = "anki_hub_exam_scores_v2"
    private let oldKey = "anki_hub_exam_scores_v1"

    init() {
        loadResults()
    }

    func loadResults() {
        // Try new format first
        if let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([ExamResult].self, from: data)
        {
            results = decoded
            return
        }

        // Migrate from old format
        if let data = UserDefaults.standard.data(forKey: oldKey),
            let decoded = try? JSONDecoder().decode([OldExamResult].self, from: data)
        {
            results = decoded.map { old in
                ExamResult(
                    id: old.id,
                    year: old.year,
                    type: old.type,
                    subject: "",
                    university: "",
                    faculty: "",
                    score: old.score,
                    total: old.total,
                    percent: old.percent,
                    date: old.date,
                    reflection: ""
                )
            }
            saveResults()
        }
    }

    // Old format for migration
    private struct OldExamResult: Codable {
        var id: UUID
        var year: Int
        var type: ExamResult.ExamType
        var score: Int
        var total: Int
        var percent: Int
        var date: Date
    }

    func addResult(
        year: Int, type: ExamResult.ExamType, subject: String, university: String, faculty: String, score: Int,
        total: Int, reflection: String
    ) {
        let percent = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
        let newResult = ExamResult(
            year: year,
            type: type,
            subject: subject,
            university: university,
            faculty: faculty,
            score: score,
            total: total,
            percent: percent,
            date: Date(),
            reflection: reflection
        )
        results.append(newResult)
        saveResults()
    }

    // Legacy support
    func addResult(year: Int, type: ExamResult.ExamType, score: Int, total: Int) {
        addResult(
            year: year,
            type: type,
            subject: "",
            university: "",
            faculty: "",
            score: score,
            total: total,
            reflection: ""
        )
    }

    func updateReflection(id: UUID, reflection: String) {
        if let index = results.firstIndex(where: { $0.id == id }) {
            results[index].reflection = reflection
            saveResults()
        }
    }

    func deleteResult(id: UUID) {
        results.removeAll { $0.id == id }
        saveResults()
    }

    private func saveResults() {
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: key)
        }

        SyncManager.shared.requestAutoSync()
    }

    // Analytics
    func getAveragePercent() -> Int {
        guard !results.isEmpty else { return 0 }
        let sum = results.reduce(0) { $0 + $1.percent }
        return sum / results.count
    }

    func getResultsBySubject() -> [String: [ExamResult]] {
        Dictionary(grouping: results) { $0.subject.isEmpty ? "未分類" : $0.subject }
    }

    func getResultsByType() -> [ExamResult.ExamType: [ExamResult]] {
        Dictionary(grouping: results) { $0.type }
    }
}
