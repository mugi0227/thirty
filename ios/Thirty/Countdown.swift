import Foundation

/// Persist the deadline, rather than counting timer callbacks: iOS can suspend us.
struct Countdown: Codable, Equatable {
    enum Phase: String, Codable { case ready, running, paused, finished }

    static let defaultSeconds = 1800
    static let maximumSeconds = 999 * 60 + 59
    static let slats = 30
    var phase: Phase = .ready
    var configuredSeconds = defaultSeconds
    var deadline: Date?
    var pausedRemaining: TimeInterval = TimeInterval(defaultSeconds)
    var sessionID: UUID = UUID()

    init() { }
    private enum CodingKeys: String, CodingKey {
        case phase, configuredSeconds, deadline, pausedRemaining, sessionID
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        phase = try values.decode(Phase.self, forKey: .phase)
        configuredSeconds = max(0, min(Self.maximumSeconds,
            try values.decodeIfPresent(Int.self, forKey: .configuredSeconds) ?? Self.defaultSeconds))
        deadline = try values.decodeIfPresent(Date.self, forKey: .deadline)
        pausedRemaining = try values.decodeIfPresent(TimeInterval.self, forKey: .pausedRemaining)
            ?? TimeInterval(configuredSeconds)
        sessionID = try values.decodeIfPresent(UUID.self, forKey: .sessionID) ?? UUID()
        if !pausedRemaining.isFinite { pausedRemaining = TimeInterval(configuredSeconds) }
    }

    func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .ready: return TimeInterval(configuredSeconds)
        case .running: return max(0, min(TimeInterval(configuredSeconds), deadline?.timeIntervalSince(now) ?? 0))
        case .paused: return max(0, min(TimeInterval(configuredSeconds), pausedRemaining))
        case .finished: return 0
        }
    }

    func seconds(at now: Date) -> Int { Int(ceil(remaining(at: now))) }
    func bars(at now: Date, slats: Int = Countdown.slats) -> Int {
        guard configuredSeconds > 0 else { return 0 }
        return Int(ceil(remaining(at: now) / Double(configuredSeconds) * Double(slats)))
    }

    mutating func start(at now: Date) {
        guard configuredSeconds > 0 else { return }
        sessionID = UUID()
        phase = .running
        deadline = now.addingTimeInterval(TimeInterval(configuredSeconds))
        pausedRemaining = TimeInterval(configuredSeconds)
    }

    mutating func refresh(at now: Date) {
        if phase == .running && remaining(at: now) <= 0 {
            phase = .finished
            deadline = nil
        }
    }

    mutating func pause(at now: Date) {
        refresh(at: now)
        guard phase == .running else { return }
        pausedRemaining = remaining(at: now)
        deadline = nil
        phase = .paused
    }

    mutating func resume(at now: Date) {
        guard phase == .paused else { return }
        deadline = now.addingTimeInterval(remaining(at: now))
        phase = .running
        refresh(at: now)
    }

    /// Editing changes the remaining time when confirmed, without pausing a run.
    mutating func setSeconds(_ seconds: Int, at now: Date) {
        configuredSeconds = max(0, min(Self.maximumSeconds, seconds))
        pausedRemaining = TimeInterval(configuredSeconds)
        if configuredSeconds == 0 || phase == .finished {
            phase = .ready
            deadline = nil
        } else if phase == .running {
            deadline = now.addingTimeInterval(TimeInterval(configuredSeconds))
        }
    }
    mutating func reset() {
        phase = .ready
        deadline = nil
        pausedRemaining = TimeInterval(configuredSeconds)
        sessionID = UUID()
    }
}
