import Foundation

#if canImport(ActivityKit)
import ActivityKit

public struct FocusTimerAttributes: ActivityAttributes {
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
#endif
