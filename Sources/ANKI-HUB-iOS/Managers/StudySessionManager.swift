import Foundation
import Combine

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Manages active study sessions with pin markers for segment tracking
@MainActor
class StudySessionManager: ObservableObject {
    static let shared = StudySessionManager()
    
    // MARK: - Published Properties
    @Published var activeSession: ActiveStudySession?
    @Published var isSessionActive: Bool = false
    
    // MARK: - Private Properties
    private let appGroupId = "group.com.ankihub.ios"
    private let activeSessionKey = "anki_hub_active_study_session_v1"
    private let completedSessionsKey = "anki_hub_completed_study_sessions_v1"
    private var timer: Timer?
    
    // MARK: - Data Models
    struct ActiveStudySession: Codable {
        var id: UUID
        var startTime: Date
        var pins: [PinMarker]
        var currentSegmentStart: Date
        
        var elapsedSeconds: Int {
            Int(Date().timeIntervalSince(startTime))
        }
        
        var currentSegmentSeconds: Int {
            Int(Date().timeIntervalSince(currentSegmentStart))
        }
    }
    
    struct PinMarker: Codable, Identifiable {
        var id: UUID
        var timestamp: Date
        var subject: String
        var activity: String
        var notes: String
        var durationSeconds: Int
    }
    
    struct CompletedSession: Codable, Identifiable {
        var id: UUID
        var startTime: Date
        var endTime: Date
        var totalMinutes: Int
        var segments: [PinMarker]
    }
    
    // MARK: - Initialization
    private init() {
        loadActiveSession()
        if isSessionActive {
            startTimer()
        }
    }
    
    // MARK: - Session Management
    func startSession() {
        let now = Date()
        activeSession = ActiveStudySession(
            id: UUID(),
            startTime: now,
            pins: [],
            currentSegmentStart: now
        )
        isSessionActive = true
        saveActiveSession()
        startTimer()
        reloadWidgets()
    }
    
    func stopSession() {
        guard let session = activeSession else { return }
        
        // Save as completed session
        let totalMinutes = Int(ceil(Double(session.elapsedSeconds) / 60.0))
        let completed = CompletedSession(
            id: session.id,
            startTime: session.startTime,
            endTime: Date(),
            totalMinutes: totalMinutes,
            segments: session.pins
        )
        
        saveCompletedSession(completed)
        
        // Update learning stats
        updateLearningStats(from: completed)
        
        // Clear active session
        activeSession = nil
        isSessionActive = false
        clearActiveSession()
        stopTimer()
        reloadWidgets()
    }
    
    func addPin(subject: String, activity: String, notes: String) {
        guard var session = activeSession else { return }
        
        let now = Date()
        let durationSeconds = Int(now.timeIntervalSince(session.currentSegmentStart))
        
        let pin = PinMarker(
            id: UUID(),
            timestamp: now,
            subject: subject,
            activity: activity,
            notes: notes,
            durationSeconds: durationSeconds
        )
        
        session.pins.append(pin)
        session.currentSegmentStart = now
        activeSession = session
        
        saveActiveSession()
        reloadWidgets()
    }
    
    // MARK: - Persistence
    private func loadActiveSession() {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: activeSessionKey),
              let session = try? JSONDecoder().decode(ActiveStudySession.self, from: data) else {
            isSessionActive = false
            return
        }
        
        activeSession = session
        isSessionActive = true
    }
    
    private func saveActiveSession() {
        guard let session = activeSession,
              let data = try? JSONEncoder().encode(session),
              let defaults = UserDefaults(suiteName: appGroupId) else {
            return
        }
        
        defaults.set(data, forKey: activeSessionKey)
    }
    
    private func clearActiveSession() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.removeObject(forKey: activeSessionKey)
    }
    
    private func saveCompletedSession(_ session: CompletedSession) {
        var sessions = loadCompletedSessions()
        sessions.append(session)
        
        // Keep only last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }
        
        guard let data = try? JSONEncoder().encode(sessions),
              let defaults = UserDefaults(suiteName: appGroupId) else {
            return
        }
        
        defaults.set(data, forKey: completedSessionsKey)
    }
    
    func loadCompletedSessions() -> [CompletedSession] {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: completedSessionsKey),
              let sessions = try? JSONDecoder().decode([CompletedSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    // MARK: - Learning Stats Integration
    private func updateLearningStats(from session: CompletedSession) {
        // Update daily history with segment details
        let dateKey = dateKey(from: session.startTime)
        
        var dailyEntry = LearningStats.shared.dailyHistory[dateKey] ?? LearningStats.DailyEntry(
            words: 0,
            minutes: 0,
            subjects: [:]
        )
        
        // Add total minutes
        dailyEntry.minutes += session.totalMinutes
        
        // Add subject breakdown from segments
        for segment in session.segments {
            let segmentMinutes = Int(ceil(Double(segment.durationSeconds) / 60.0))
            dailyEntry.subjects[segment.subject, default: 0] += segmentMinutes
        }
        
        LearningStats.shared.dailyHistory[dateKey] = dailyEntry
        LearningStats.shared.saveStats()
    }
    
    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Widget Integration
    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "StudyWidget")
        #endif
    }
    
    // MARK: - Formatted Time
    func formattedElapsedTime() -> String {
        guard let session = activeSession else { return "00:00:00" }
        return formatSeconds(session.elapsedSeconds)
    }
    
    func formattedCurrentSegmentTime() -> String {
        guard let session = activeSession else { return "00:00:00" }
        return formatSeconds(session.currentSegmentSeconds)
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
