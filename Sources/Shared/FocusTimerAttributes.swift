import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

public struct FocusTimerAttributes {
    public struct ContentState: Codable, Hashable {
        public var targetTime: Date
        public var totalSeconds: Int
        public var pausedRemainingSeconds: Int?
        public var isPaused: Bool

        public init(targetTime: Date, totalSeconds: Int, pausedRemainingSeconds: Int? = nil, isPaused: Bool = false) {
            self.targetTime = targetTime
            self.totalSeconds = totalSeconds
            self.pausedRemainingSeconds = pausedRemainingSeconds
            self.isPaused = isPaused
        }
    }

    public var timerName: String

    public init(timerName: String) {
        self.timerName = timerName
    }
}

#if canImport(ActivityKit) && os(iOS)
extension FocusTimerAttributes: ActivityAttributes {}
#endif

public struct FocusTimerControlRequest: Codable, Hashable {
    public enum Action: String, Codable, Hashable {
        case togglePause
        case stop
    }

    public var action: Action
    public var requestedAt: Date

    public init(action: Action, requestedAt: Date = Date()) {
        self.action = action
        self.requestedAt = requestedAt
    }
}
