import Foundation

struct ExamGuideSubject: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let sections: [ExamGuideSection]
}

struct ExamGuideSection: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let youtubeLinks: [ExamGuideYouTubeLink]?
    let blocks: [ExamGuideBlock]
}

struct ExamGuideYouTubeLink: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let url: String
}

struct ExamGuideBlock: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let text: String?
    let items: [String]?
    let question: String?
    let answer: String?
    let explanation: String?
}

enum ExamGuideData {
    private static var cached: [ExamGuideSubject]?

    static func subjects() -> [ExamGuideSubject] {
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: "exam_guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ExamGuideSubject].self, from: data)
        else {
            return []
        }
        cached = decoded
        return decoded
    }

    static func subject(for id: String) -> ExamGuideSubject? {
        subjects().first { $0.id == id }
    }
}
