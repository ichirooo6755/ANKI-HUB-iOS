import Foundation
import SwiftUI

public struct StudyTimelineEntry: Identifiable, Codable {
    public enum EntryType: String, Codable {
        case studyLog
        case mastered
        case note
    }

    public var id: UUID = UUID()
    public var createdAt: Date
    public var type: EntryType
    public var title: String
    public var summary: String
    public var detail: String
    public var subject: String?
    public var sourceId: String?
    
    public init(id: UUID = UUID(), createdAt: Date, type: EntryType, title: String, summary: String, detail: String, subject: String? = nil, sourceId: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.title = title
        self.summary = summary
        self.detail = detail
        self.subject = subject
        self.sourceId = sourceId
    }
}

@MainActor
public final class TimelineManager: ObservableObject {
    public static let shared = TimelineManager()

    @Published public private(set) var entries: [StudyTimelineEntry] = []

    private let storageKey = "anki_hub_timeline_entries_v1"
    private let appGroupId = "group.com.ankihub.ios"
    private let maxEntries = 300

    private init() {
        loadEntries()
    }

    public func loadEntries() {
        let defaults = UserDefaults.standard
        let groupDefaults = UserDefaults(suiteName: appGroupId)
        let data = defaults.data(forKey: storageKey) ?? groupDefaults?.data(forKey: storageKey)
        guard let data,
            let decoded = try? JSONDecoder().decode([StudyTimelineEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    public func addEntry(_ entry: StudyTimelineEntry) {
        entries.insert(entry, at: 0)
        trimEntriesIfNeeded()
        persistEntries()
    }

    public func deleteEntry(_ entry: StudyTimelineEntry) {
        entries.removeAll { $0.id == entry.id }
        persistEntries()
    }

    public func addStudyLogEntry(_ log: TimerStudyLog) {
        let durationMinutes = max(1, Int(log.endedAt.timeIntervalSince(log.startedAt) / 60))
        let content = log.studyContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = content.isEmpty ? "学習ログを記録しました" : content
        let entry = StudyTimelineEntry(
            createdAt: log.endedAt,
            type: .studyLog,
            title: "学習ログ",
            summary: "\(log.mode)・\(durationMinutes)分",
            detail: detail,
            subject: nil,
            sourceId: log.id.uuidString
        )
        addEntry(entry)
    }

    func addMasteredEntry(subject: Subject, wordId: String, term: String, meaning: String, date: Date) {
        let detail = meaning.isEmpty ? term : "\(term)｜\(meaning)"
        let entry = StudyTimelineEntry(
            createdAt: date,
            type: .mastered,
            title: "覚えた単語",
            summary: "\(subject.displayName)・1語",
            detail: detail,
            subject: subject.rawValue,
            sourceId: wordId
        )
        addEntry(entry)
    }

    public func addNoteEntry(title: String, detail: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = StudyTimelineEntry(
            createdAt: Date(),
            type: .note,
            title: trimmedTitle.isEmpty ? "メモ" : trimmedTitle,
            summary: "フリーポスト",
            detail: trimmedDetail.isEmpty ? "" : trimmedDetail,
            subject: nil,
            sourceId: nil
        )
        addEntry(entry)
    }

    private func trimEntriesIfNeeded() {
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        if let groupDefaults = UserDefaults(suiteName: appGroupId) {
            groupDefaults.set(data, forKey: storageKey)
        }
        SyncManager.shared.requestAutoSync()
    }
}
