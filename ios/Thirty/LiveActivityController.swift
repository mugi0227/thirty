import ActivityKit
import Foundation

/// Thirty+: mirrors the timer on the Lock Screen, in StandBy and the Dynamic
/// Island. The system counts down to the deadline, so updates happen only on
/// start, pause, resume, edits and the end.
@MainActor
final class LiveActivityController {
    private var current: Activity<TimerActivityAttributes>?

    init() {
        // A previous process may have left one behind.
        current = Activity<TimerActivityAttributes>.activities.first
    }

    func sync(countdown: Countdown, at now: Date, enabled: Bool, skinID: String, slats: Int, isBreak: Bool) {
        let timing = countdown.phase == .running || countdown.phase == .paused
        guard enabled, timing, ActivityAuthorizationInfo().areActivitiesEnabled else {
            end()
            return
        }
        let state = TimerActivityAttributes.ContentState(
            deadline: countdown.phase == .running ? countdown.deadline : nil,
            remaining: countdown.remaining(at: now),
            total: TimeInterval(countdown.configuredSeconds),
            isBreak: isBreak)
        let staleDate = countdown.phase == .running ? countdown.deadline?.addingTimeInterval(60) : nil
        let content = ActivityContent(state: state, staleDate: staleDate)
        if let current, current.attributes.skinID == skinID, current.attributes.slats == slats {
            Task { await current.update(content) }
        } else {
            end()
            current = try? Activity.request(attributes: TimerActivityAttributes(skinID: skinID, slats: slats), content: content)
        }
    }

    func end() {
        let ending = Activity<TimerActivityAttributes>.activities
        current = nil
        for activity in ending {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
