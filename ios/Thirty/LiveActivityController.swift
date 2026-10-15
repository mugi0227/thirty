import ActivityKit
import Foundation

/// Thirty+: mirrors the timer on the Lock Screen, in StandBy and the Dynamic
/// Island. The system counts down to the deadline, so updates happen only on
/// start, pause, resume, edits and the end.
@MainActor
final class LiveActivityController {
    private var current: Activity<TimerActivityAttributes>?
    private var updateTask: Task<Void, Never>?

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
            // The system counts against the real clock; AppClock.lead is 0 outside debug captures.
            deadline: countdown.phase == .running ? countdown.deadline?.addingTimeInterval(-AppClock.lead) : nil,
            remaining: countdown.remaining(at: now),
            total: TimeInterval(countdown.configuredSeconds),
            isBreak: isBreak, skinID: skinID, slats: slats)
        let staleDate = countdown.phase == .running ? countdown.deadline?.addingTimeInterval(60) : nil
        let content = ActivityContent(state: state, staleDate: staleDate)
        if let current {
            // Keep one activity when its appearance changes. Serialize updates
            // so a rapid sequence of skin choices ends with the latest choice.
            let previous = updateTask
            previous?.cancel()
            updateTask = Task {
                await previous?.value
                guard !Task.isCancelled else { return }
                await current.update(content)
            }
        } else {
            end()
            current = try? Activity.request(attributes: TimerActivityAttributes(skinID: skinID, slats: slats), content: content)
        }
    }

    func end() {
        updateTask?.cancel()
        updateTask = nil
        let ending = Activity<TimerActivityAttributes>.activities
        current = nil
        for activity in ending {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
