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
#endif
