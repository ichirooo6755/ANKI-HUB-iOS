import Foundation

#if canImport(ActivityKit)
import ActivityKit

public struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var targetTime: Date

        public init(targetTime: Date) {
            self.targetTime = targetTime
        }
    }

    public var timerName: String

    public init(timerName: String) {
        self.timerName = timerName
    }
}
#endif
