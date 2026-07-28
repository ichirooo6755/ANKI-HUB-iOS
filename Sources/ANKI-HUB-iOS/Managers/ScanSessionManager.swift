import Foundation

struct ScanVocabEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var term: String
    var meaning: String

    init(id: UUID = UUID(), term: String, meaning: String) {
        self.id = id
        self.term = term
        self.meaning = meaning
    }
}

struct ScanSessionItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var subjectRaw: String
    var vocabulary: [ScanVocabEntry]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subjectRaw: String,
        vocabulary: [ScanVocabEntry] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subjectRaw = subjectRaw
        self.vocabulary = vocabulary
        self.createdAt = createdAt
    }
}

/// スキャンで作成した問題集をチャプター単位で整理
@MainActor
final class ScanSessionManager: ObservableObject {
    static let shared = ScanSessionManager()
    static let chapterPrefix = "📷 "

    @Published private(set) var sessions: [ScanSessionItem] = []

    private let storageKey = "anki_hub_scan_sessions_v1"

    static func chapterTitle(for session: ScanSessionItem) -> String {
        "\(chapterPrefix)\(session.title)"
    }

    static func isScanChapter(_ title: String) -> Bool {
        title.hasPrefix(chapterPrefix)
    }

    func chapterTitles(for subject: Subject) -> [String] {
        sessions
            .filter { $0.subjectRaw == subject.rawValue }
            .map { Self.chapterTitle(for: $0) }
    }

    func session(matchingChapter title: String) -> ScanSessionItem? {
        guard Self.isScanChapter(title) else { return nil }
        let name = String(title.dropFirst(Self.chapterPrefix.count))
        return sessions.first { $0.title == name }
    }

    func vocabulary(forChapter title: String) -> [Vocabulary] {
        guard let session = session(matchingChapter: title) else { return [] }
        return session.vocabulary.map { entry in
            Vocabulary(
                id: "scan-\(session.id.uuidString)-\(entry.id.uuidString)",
                term: entry.term,
                meaning: entry.meaning
            )
        }
    }

    func sessions(for subject: Subject) -> [ScanSessionItem] {
        sessions.filter { $0.subjectRaw == subject.rawValue }
    }

    private init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScanSessionItem].self, from: data)
        else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func saveSession(title: String, subject: Subject, vocabulary: [ScanVocabEntry]) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !vocabulary.isEmpty else { return }

        let session = ScanSessionItem(
            title: trimmedTitle,
            subjectRaw: subject.rawValue,
            vocabulary: vocabulary
        )
        sessions.insert(session, at: 0)
        persist()
        addToWordbook(vocabulary, source: trimmedTitle)
    }

    func append(to sessionId: UUID, vocabulary: [ScanVocabEntry]) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        var session = sessions[index]
        for item in vocabulary {
            if !session.vocabulary.contains(where: { $0.term == item.term && $0.meaning == item.meaning }) {
                session.vocabulary.append(item)
            }
        }
        sessions[index] = session
        persist()
        addToWordbook(vocabulary, source: session.title)
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func addToWordbook(_ items: [ScanVocabEntry], source: String) {
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data)
        {
            words = decoded
        }

        for item in items {
            let entry = WordbookEntry(
                id: UUID().uuidString,
                term: item.term,
                meaning: item.meaning,
                hint: nil,
                source: source,
                mastery: .new
            )
            if !words.contains(where: { $0.term == entry.term && $0.source == source }) {
                words.append(entry)
            }
        }

        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }
        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
    }
}
