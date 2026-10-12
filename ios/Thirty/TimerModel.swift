import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var countdown: Countdown
    @Published private(set) var now = Date()
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

    private let defaults: UserDefaults
    private let storageKey = "countdown.v1"
    private let notificationPrefix = "thirty.finished."
    private var ownPendingIDs = Set<String>()
    private var notificationTask: Task<Void, Never>?
    private var revision = 0
    private var isActive = false
    private let effects = TimerEffects()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keepScreenOn = defaults.object(forKey: "keepScreenOn") as? Bool ?? true
        self.dimScreen = defaults.bool(forKey: "dimScreen")
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Countdown.self, from: data) {
            countdown = saved
        } else {
            countdown = Countdown()
        }
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
    var bars: Int { countdown.bars(at: now) }
    var timeText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    var remainingLabel: String { "残り\(seconds / 60)分\(seconds % 60)秒" }

    func tick(at date: Date = Date(), announceCompletion: Bool = true) {
        now = date
        let previous = countdown.phase
        countdown.refresh(at: date)
        if previous != countdown.phase {
            persist()
            updateDisplay()
            if isActive && announceCompletion {
                effects.playAlarm()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func start() {
        guard countdown.configuredSeconds > 0 else { return }
        now = Date()
        effects.stopAlarm()
        countdown.start(at: now)
        notificationNotice = nil
        changed(requestPermission: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func pause() {
        now = Date()
        countdown.pause(at: now)
        changed()
    }

    func resume() {
        now = Date()
        countdown.resume(at: now)
        changed(requestPermission: true)
    }

    func reset() {
        effects.stopAlarm()
        countdown.reset()
        now = Date()
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
        now = Date()
        countdown.setSeconds(seconds, at: now)
        changed()
    }
    func addMinutes(_ minutes: Int) {
        tick()
        let base = countdown.phase == .finished ? countdown.configuredSeconds : seconds
        setSeconds(min(Countdown.maximumSeconds, base + minutes * 60))
    }

    private func changed(requestPermission: Bool = false) {
        persist()
        updateDisplay()
        syncNotification(requestPermission: requestPermission)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(countdown) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func updateDisplay() {
        UIApplication.shared.isIdleTimerDisabled = isActive && keepScreenOn && countdown.phase == .running
        let timing = countdown.phase == .running || countdown.phase == .paused
        effects.setDimmed(isActive && dimScreen && timing)
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
            if settings.authorizationStatus == .notDetermined && requestPermission {
                allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            }
            guard let self, !Task.isCancelled, currentRevision == self.revision else { return }
            guard allowed else {
                self.notificationNotice = "終了の通知はオフです。画面内では時間を確認できます。"
                return
            }
            self.notificationNotice = nil
            let interval = deadline.timeIntervalSinceNow
            guard interval > 0 else { self.tick(); return }
            let content = UNMutableNotificationContent()
            content.title = "タイマー"
            content.body = "終了"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
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
                    self.notificationNotice = "終了の通知を設定できませんでした。画面内で時間を確認してください。"
                }
            }
        }
    }
}
