import Foundation
import SwiftUI

@MainActor
public final class StudyMaterialManager: ObservableObject {
    public static let shared = StudyMaterialManager()

    @Published public private(set) var materials: [StudyMaterial] = []
    @Published public private(set) var records: [StudyMaterialRecord] = []

    private let materialsKey = "anki_hub_study_materials_v1"
    private let recordsKey = "anki_hub_study_material_records_v1"
    private let appGroupId = "group.com.ankihub.ios"

    private init() {
        load()
    }

    public func load() {
        let defaults = UserDefaults.standard
        let groupDefaults = UserDefaults(suiteName: appGroupId)

        if let data = defaults.data(forKey: materialsKey)
            ?? groupDefaults?.data(forKey: materialsKey),
            let decoded = try? JSONDecoder().decode([StudyMaterial].self, from: data)
        {
            materials = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            materials = []
        }

        if let data = defaults.data(forKey: recordsKey)
            ?? groupDefaults?.data(forKey: recordsKey),
            let decoded = try? JSONDecoder().decode([StudyMaterialRecord].self, from: data)
        {
            records = decoded.sorted { $0.endedAt > $1.endedAt }
        } else {
            records = []
        }
    }

    public func addMaterial(_ material: StudyMaterial) {
        materials.insert(material, at: 0)
        persistMaterials()
    }

    public func updateMaterial(_ material: StudyMaterial) {
        guard let index = materials.firstIndex(where: { $0.id == material.id }) else { return }
        materials[index] = material
        persistMaterials()
    }

    public func deleteMaterial(_ material: StudyMaterial) {
        if let filename = material.imageFilename {
            deleteImageFile(filename)
        }
        materials.removeAll { $0.id == material.id }
        records.removeAll { $0.materialId == material.id }
        persistMaterials()
        persistRecords()
    }

    public func records(for materialId: UUID) -> [StudyMaterialRecord] {
        records.filter { $0.materialId == materialId }
            .sorted { $0.endedAt > $1.endedAt }
    }

    public func addRecord(
        materialId: UUID,
        minutes: Int,
        note: String,
        startedAt: Date,
        endedAt: Date,
        source: StudyMaterialRecord.Source
    ) {
        guard let index = materials.firstIndex(where: { $0.id == materialId }) else { return }
        let material = materials[index]
        let record = StudyMaterialRecord(
            materialId: materialId,
            materialTitle: material.title,
            minutes: minutes,
            note: note,
            startedAt: startedAt,
            endedAt: endedAt,
            source: source
        )
        records.insert(record, at: 0)

        var updated = material
        updated.totalMinutes += minutes
        updated.lastStudiedAt = endedAt
        materials[index] = updated

        persistRecords()
        persistMaterials()
    }

    public func recordTimerStudy(_ log: TimerStudyLog) {
        guard let materialId = log.materialId else { return }
        let minutes = max(1, Int(ceil(timerSeconds(from: log) / 60.0)))
        addRecord(
            materialId: materialId,
            minutes: minutes,
            note: log.studyContent,
            startedAt: log.startedAt,
            endedAt: log.endedAt,
            source: .timer
        )
    }

    private func timerSeconds(from log: TimerStudyLog) -> TimeInterval {
        if let segments = log.segments, !segments.isEmpty {
            return segments.reduce(0) { total, segment in
                guard segment.endTime > segment.startTime else { return total }
                return total + segment.endTime.timeIntervalSince(segment.startTime)
            }
        }
        return max(0, log.endedAt.timeIntervalSince(log.startedAt))
    }

    private func persistMaterials() {
        guard let data = try? JSONEncoder().encode(materials) else { return }
        UserDefaults.standard.set(data, forKey: materialsKey)
        UserDefaults(suiteName: appGroupId)?.set(data, forKey: materialsKey)
        SyncManager.shared.requestAutoSync()
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
        UserDefaults(suiteName: appGroupId)?.set(data, forKey: recordsKey)
        SyncManager.shared.requestAutoSync()
    }

    private func deleteImageFile(_ filename: String) {
        guard !filename.isEmpty else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
