import ActivityKit
import WidgetKit
import SwiftUI

struct M2SleepTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var title: String
        var subtitle: String
    }

    var timerID: String
}

struct M2SleepTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: M2SleepTimerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text("Sleep Timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(1)
                if !context.state.subtitle.isEmpty {
                    Text(context.state.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(14)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.yellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.zzz.fill")
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "moon.zzz.fill")
            }
            .widgetURL(URL(string: "m2://sleep-timer"))
            .keylineTint(.yellow)
        }
    }
}
