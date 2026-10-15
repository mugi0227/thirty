import SwiftUI
import UIKit
import UserNotifications

/// The timer's notion of "now". Debug builds can run it faster
/// (-ThirtyTimeScale 90) so the preview video shows a whole session.
enum AppClock {
    #if DEBUG
    private static let scale = max(1, UserDefaults.standard.double(forKey: "ThirtyTimeScale"))
    private static let origin = Date()
    /// Screenshot runs pass -ThirtyJumpAfterStart 450 to land mid-session at a fixed time.
    private static var offset: TimeInterval = 0
    static func now() -> Date {
        let real = scale == 1 ? Date() : origin.addingTimeInterval(Date().timeIntervalSince(origin) * scale)
        return real.addingTimeInterval(offset)
    }
    static func didStart() {
        offset += UserDefaults.standard.double(forKey: "ThirtyJumpAfterStart")
    }
    /// How far the debug clock runs ahead, so the Live Activity can match the app.
    static var lead: TimeInterval { now().timeIntervalSince(Date()) }
    #else
    static func now() -> Date { Date() }
    static func didStart() {}
    static var lead: TimeInterval { 0 }
    #endif
}

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var countdown: Countdown
    @Published private(set) var now = AppClock.now()
    @Published var notificationNotice: String?
    @Published var isGuidedAccessActive = UIAccessibility.isGuidedAccessEnabled
    @Published var dimScreen: Bool {
        didSet { defaults.set(dimScreen, forKey: "dimScreen"); updateDisplay() }
    }
    @Published var keepScreenOn: Bool {
        didSet {
            defaults.set(keepScreenOn, forKey: "keepScreenOn")
            updateDisplay()
        }
    }
    /// Covering the proximity sensor (lying face down) turns the screen off.
    @Published var faceDownScreenOff: Bool {
        didSet { defaults.set(faceDownScreenOff, forKey: "faceDownScreenOff"); updateDisplay() }
    }
    @Published var startOnLaunch: Bool {
        didSet { defaults.set(startOnLaunch, forKey: "startOnLaunch") }
    }
    // Thirty+ settings. They are stored as chosen and only take effect with Thirty+.
    @Published var endSound: EndSound {
        didSet { defaults.set(endSound.rawValue, forKey: "endSound"); syncNotification(requestPermission: false) }
    }
    @Published var cycleEnabled: Bool {
        didSet { defaults.set(cycleEnabled, forKey: "cycleEnabled"); if !cycleEnabled { endBreak() } }
    }
    @Published var breakMinutes: Int {
        didSet { defaults.set(breakMinutes, forKey: "breakMinutes") }
    }
    @Published var slatCount: Int {
        didSet { defaults.set(slatCount, forKey: "slatCount") }
    }
    @Published var showSeconds: Bool {
        didSet { defaults.set(showSeconds, forKey: "showSeconds") }
    }
    @Published var liveActivityEnabled: Bool {
        didSet { defaults.set(liveActivityEnabled, forKey: "liveActivityEnabled"); syncActivity() }
    }
    @Published var hasPlus = false {
        didSet { if oldValue != hasPlus { syncNotification(requestPermission: false); syncActivity() } }
    }
    /// The break between rounds when the cycle is on.
    @Published private(set) var isBreak: Bool

    private let defaults: UserDefaults
    private let storageKey = "countdown.v1"
    private let notificationPrefix = "thirty.finished."
    private var ownPendingIDs = Set<String>()
    private var notificationTask: Task<Void, Never>?
    private var revision = 0
    private var isActive = false
    private let effects = TimerEffects()
    var soundEffects: TimerEffects { effects }
    private let activity = LiveActivityController()
    /// The focus duration to come back to after a break.
    private var workSeconds: Int

    /// Intents and quick actions reach the running timer through this instance.
    static let shared = TimerModel()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keepScreenOn = defaults.object(forKey: "keepScreenOn") as? Bool ?? true
        self.dimScreen = defaults.bool(forKey: "dimScreen")
        self.faceDownScreenOff = defaults.object(forKey: "faceDownScreenOff") as? Bool ?? true
        self.startOnLaunch = defaults.bool(forKey: "startOnLaunch")
        self.endSound = EndSound(rawValue: defaults.string(forKey: "endSound") ?? "") ?? .chime
        self.cycleEnabled = defaults.bool(forKey: "cycleEnabled")
        self.breakMinutes = defaults.object(forKey: "breakMinutes") as? Int ?? 5
        self.slatCount = defaults.integer(forKey: "slatCount") == 60 ? 60 : 30
        self.showSeconds = defaults.object(forKey: "showSeconds") as? Bool ?? true
        self.liveActivityEnabled = defaults.object(forKey: "liveActivityEnabled") as? Bool ?? true
        self.isBreak = defaults.bool(forKey: "isBreak")
        self.workSeconds = defaults.object(forKey: "workSeconds") as? Int ?? Countdown.defaultSeconds
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Countdown.self, from: data) {
            countdown = saved
        } else {
            countdown = Countdown()
        }
        #if DEBUG
        // UI tests pass -ThirtyDemoSeconds 3 to reach the finished screen quickly.
        let demoSeconds = defaults.integer(forKey: "ThirtyDemoSeconds")
        if demoSeconds > 0 { countdown.setSeconds(demoSeconds, at: now) }
        #endif
        countdown.refresh(at: now)
        persist()
        // Recover request IDs from a previous process so a reset can cancel them.
        Task { [weak self] in
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            guard let self else { return }
            self.ownPendingIDs.formUnion(requests.map(\.identifier).filter { $0.hasPrefix(self.notificationPrefix) })
            self.syncNotification(requestPermission: false)
        }
    }

    var seconds: Int { countdown.seconds(at: now) }
    var effectiveSlats: Int { hasPlus ? slatCount : Countdown.slats }
    var bars: Int { countdown.bars(at: now, slats: effectiveSlats) }
    /// Minutes only rounds up, so 29:59 still reads 30 and the last seconds read 1.
    var timeText: String {
        if !hasPlus || showSeconds { return String(format: "%02d:%02d", seconds / 60, seconds % 60) }
        return String(format: "%02d", Int(ceil(Double(seconds) / 60)))
    }
    var lastMinutes: Int { max(1, Int(ceil(Double(isBreak ? workSeconds : countdown.configuredSeconds) / 60))) }
    private var cycleActive: Bool { hasPlus && cycleEnabled }
    private var sound: EndSound { hasPlus ? endSound : .chime }
    var remainingLabel: String { String(localized: "残り\(seconds / 60)分\(seconds % 60)秒") }

    func tick(at date: Date = AppClock.now(), announceCompletion: Bool = true) {
        now = date
        let previous = countdown.phase
        countdown.refresh(at: date)
        if previous != countdown.phase {
            persist()
            updateDisplay()
            syncActivity()
            if isActive && announceCompletion {
                effects.playAlarm(sound)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // Rounds chain only while the app is open; a session that ended in
                // the background just shows as finished on return.
                if countdown.phase == .finished && cycleActive { nextRound() }
            }
        }
    }

    /// Focus → break → focus, until the stop button.
    private func nextRound() {
        if isBreak {
            setBreak(false)
            countdown.setSeconds(workSeconds, at: now)
        } else {
            workSeconds = countdown.configuredSeconds
            defaults.set(workSeconds, forKey: "workSeconds")
            setBreak(true)
            countdown.setSeconds(max(1, breakMinutes) * 60, at: now)
        }
        countdown.start(at: now)
        changed(requestPermission: false)
    }

    private func setBreak(_ value: Bool) {
        isBreak = value
        defaults.set(value, forKey: "isBreak")
    }

    private func endBreak() {
        guard isBreak else { return }
        setBreak(false)
        countdown.setSeconds(workSeconds, at: AppClock.now())
        countdown.reset()
        changed()
    }

    /// From an intent, quick action, widget or launch: start unless already timing.
    func startNow(minutes: Int? = nil) {
        tick(announceCompletion: false)
        guard countdown.phase != .running else { return }
        if let minutes { setSeconds(minutes * 60) }
        if countdown.configuredSeconds == 0 { setSeconds(Countdown.defaultSeconds) }
        start()
    }

    /// "One more" on the finished screen repeats the last focus duration.
    func again() {
        if isBreak { endBreak() }
        start()
    }

    func start() {
        guard countdown.configuredSeconds > 0 else { return }
        now = AppClock.now()
        effects.stopAlarm()
        countdown.start(at: now)
        AppClock.didStart()
        now = AppClock.now()
        notificationNotice = nil
        changed(requestPermission: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func pause() {
        now = AppClock.now()
        countdown.pause(at: now)
        changed()
    }

    func resume() {
        now = AppClock.now()
        countdown.resume(at: now)
        changed(requestPermission: true)
    }

    func reset() {
        effects.stopAlarm()
        if isBreak {
            setBreak(false)
            countdown.setSeconds(workSeconds, at: AppClock.now())
        }
        countdown.reset()
        now = AppClock.now()
        notificationNotice = nil
        changed()
    }

    func sceneChanged(_ phase: ScenePhase) {
        isActive = phase == .active
        if isActive {
            tick(announceCompletion: false)
            isGuidedAccessActive = UIAccessibility.isGuidedAccessEnabled
            syncNotification(requestPermission: false)
        }
        updateDisplay()
        if !isActive { effects.stopAlarm() }
    }

    func setSeconds(_ seconds: Int) {
        effects.stopAlarm()
        now = AppClock.now()
        countdown.setSeconds(seconds, at: now)
        changed()
    }
    func addMinutes(_ minutes: Int) {
        tick()
        guard countdown.phase != .running && countdown.phase != .paused else { return }
        let base = countdown.phase == .finished ? countdown.configuredSeconds : seconds
        if minutes < 0 {
            // Taking time off never ends the timer: it stops at one minute.
            guard base > 60 else { return }
            setSeconds(max(60, base + minutes * 60))
        } else {
            setSeconds(min(Countdown.maximumSeconds, base + minutes * 60))
        }
    }

    var canSubtract: Bool {
        (countdown.phase == .finished ? countdown.configuredSeconds : seconds) > 60
    }

    private func changed(requestPermission: Bool = false) {
        persist()
        updateDisplay()
        syncNotification(requestPermission: requestPermission)
        syncActivity()
    }

    private func syncActivity() {
        activity.sync(countdown: countdown, at: now, enabled: hasPlus && liveActivityEnabled,
                      skinID: defaults.string(forKey: "skin") ?? "classic", slats: effectiveSlats, isBreak: isBreak)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(countdown) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func updateDisplay() {
        UIApplication.shared.isIdleTimerDisabled = isActive && keepScreenOn && countdown.phase == .running
        UIDevice.current.isProximityMonitoringEnabled = isActive && faceDownScreenOff && countdown.phase == .running
        let timing = countdown.phase == .running || countdown.phase == .paused
        effects.setDimmed(isActive && dimScreen && timing)
    }

    /// Screenshot and video runs pass -ThirtyNoPrompt YES to keep the alert out of frame.
    private static var suppressPrompt: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "ThirtyNoPrompt")
        #else
        return false
        #endif
    }

    /// A version check also handles an old permission prompt completing after reset.
    private func syncNotification(requestPermission: Bool) {
        revision += 1
        let currentRevision = revision
        let snapshot = countdown
        notificationTask?.cancel()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Array(ownPendingIDs))
        ownPendingIDs.removeAll()
        guard snapshot.phase == .running, let deadline = snapshot.deadline else { return }

        notificationTask = Task { [weak self] in
            let settings = await center.notificationSettings()
            var allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined && requestPermission && !Self.suppressPrompt {
                allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            }
            guard let self, !Task.isCancelled, currentRevision == self.revision else { return }
            guard allowed else {
                self.notificationNotice = String(localized: "終了の通知はオフです。画面内では時間を確認できます。")
                return
            }
            self.notificationNotice = nil
            let interval = deadline.timeIntervalSinceNow
            guard interval > 0 else { self.tick(); return }
            let content = UNMutableNotificationContent()
            content.title = self.isBreak ? String(localized: "休憩おわり") : String(localized: "タイマー")
            content.body = String(localized: "時間になりました。")
            content.sound = self.sound.fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) }
            // Every revision has its own ID, including across process restarts.
            let requestID = self.notificationPrefix + UUID().uuidString
            self.ownPendingIDs.insert(requestID)
            let request = UNNotificationRequest(identifier: requestID, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false))
            do {
                try await center.add(request)
                if Task.isCancelled || currentRevision != self.revision {
                    // Remove only this obsolete request, never a newer session's.
                    center.removePendingNotificationRequests(withIdentifiers: [requestID])
                    self.ownPendingIDs.remove(requestID)
                }
            } catch {
                if currentRevision == self.revision {
                    self.notificationNotice = String(localized: "終了の通知を設定できませんでした。画面内で時間を確認してください。")
                }
            }
        }
    }
}
