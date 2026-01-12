import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let dailyReminderIdPrefix = "anki_hub_daily_study_reminder_v2_"
    private let legacyDailyReminderId = "anki_hub_daily_study_reminder_v1"

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduleDailyStudyReminder(hour: Int, minute: Int) async -> Bool {
        return await scheduleDailyStudyReminders(times: [Time(hour: hour, minute: minute)])
    }

    struct Time: Codable, Hashable {
        var hour: Int
        var minute: Int
    }

    func scheduleDailyStudyReminders(times: [Time]) async -> Bool {
        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return false }

        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix(dailyReminderIdPrefix) }
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }

        center.removePendingNotificationRequests(withIdentifiers: [legacyDailyReminderId])

        let content = UNMutableNotificationContent()
        content.title = "学習の時間です"
        content.body = "今日も少しだけ進めよう"
        content.sound = .default

        let normalized = times
            .map { Time(hour: max(0, min(23, $0.hour)), minute: max(0, min(59, $0.minute))) }
        let unique = Array(Set(normalized)).sorted { a, b in
            if a.hour != b.hour { return a.hour < b.hour }
            return a.minute < b.minute
        }

        guard !unique.isEmpty else { return true }

        do {
            for (idx, t) in unique.enumerated() {
                var comps = DateComponents()
                comps.hour = t.hour
                comps.minute = t.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(dailyReminderIdPrefix)\(idx)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }
            return true
        } catch {
            return false
        }
    }

    func cancelDailyStudyReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix(dailyReminderIdPrefix) }
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }

        center.removePendingNotificationRequests(withIdentifiers: [legacyDailyReminderId])
    }
}
