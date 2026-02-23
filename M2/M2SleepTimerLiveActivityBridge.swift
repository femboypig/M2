import Foundation
import ActivityKit

struct M2SleepTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var title: String
        var subtitle: String
    }

    var timerID: String
}

@objc(M2SleepLiveActivityBridge)
final class M2SleepLiveActivityBridge: NSObject {
    @objc static func syncSleepTimer(withRemaining remaining: TimeInterval,
                                     title: String,
                                     subtitle: String) {
        guard #available(iOS 16.1, *) else { return }
        guard remaining > 0 else {
            endSleepTimerActivity()
            return
        }

        Task {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

            let startDate = Date()
            let endDate = startDate.addingTimeInterval(remaining)
            let attributes = M2SleepTimerActivityAttributes(timerID: "m2.sleep.timer")
            let state = M2SleepTimerActivityAttributes.ContentState(
                startDate: startDate,
                endDate: endDate,
                title: title,
                subtitle: subtitle
            )

            if let activity = Activity<M2SleepTimerActivityAttributes>.activities.first {
                await activity.update(using: state)
            } else {
                _ = try? Activity<M2SleepTimerActivityAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
        }
    }

    @objc static func endSleepTimerActivity() {
        guard #available(iOS 16.1, *) else { return }

        Task {
            for activity in Activity<M2SleepTimerActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
