import AVFoundation
import Combine
import UIKit

@MainActor
final class TimerEffects: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var previewedSound: EndSound?
    @Published private(set) var isPlayingAlarm = false
    private var player: AVAudioPlayer?
    private var previewTimeout: Task<Void, Never>?
    private var vibrationTask: Task<Void, Never>?
    private var audioSessionActive = false
    private var previousBrightness: CGFloat?

    func playAlarm(_ sound: EndSound = .chime) {
        stopAlarm()
        isPlayingAlarm = true
        play(sound)
    }

    /// A preview shares the alarm's player so it cannot cover up a timer ending.
    func preview(_ sound: EndSound) {
        guard !isPlayingAlarm else { return }
        if previewedSound == sound { stopPreview(); return }
        stopPreview()
        previewedSound = sound
        play(sound)
        guard previewedSound != nil else { return }
        previewTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
            self?.stopPreview()
        }
    }

    func stopPreview() {
        guard previewedSound != nil else { return }
        stopAlarm()
    }

    private func play(_ sound: EndSound) {
        guard let name = sound.resourceName else {
            vibrate()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            stopAlarm()
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            audioSessionActive = true
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            if player?.play() != true { stopAlarm() }
        } catch { stopAlarm() }
    }
    /// Three firm taps for the silent choice.
    private func vibrate() {
        vibrationTask = Task { @MainActor [weak self] in
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            for _ in 0..<3 {
                guard !Task.isCancelled else { return }
                generator.impactOccurred()
                do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            }
            self?.stopAlarm()
        }
    }

    func stopAlarm() {
        previewTimeout?.cancel()
        previewTimeout = nil
        vibrationTask?.cancel()
        vibrationTask = nil
        player?.stop()
        player = nil
        previewedSound = nil
        isPlayingAlarm = false
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stopAlarm()
        }
    }
    func setDimmed(_ dimmed: Bool) {
        if dimmed {
            if previousBrightness == nil { previousBrightness = UIScreen.main.brightness }
            UIScreen.main.brightness = min(previousBrightness ?? 0.12, 0.12)
        } else if let previousBrightness {
            UIScreen.main.brightness = previousBrightness
            self.previousBrightness = nil
        }
    }
}

/// End-of-timer sounds. The chime is free; the rest come with Thirty+.
enum EndSound: String, CaseIterable, Identifiable {
    case chime = "alarm", beep, bell, soft, vibrate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chime: return String(localized: "チャイム")
        case .beep: return String(localized: "ピピピ（キッチンタイマー）")
        case .bell: return String(localized: "ベル")
        case .soft: return String(localized: "やさしい音")
        case .vibrate: return String(localized: "振動のみ")
        }
    }
    var isFree: Bool { self == .chime }
    var resourceName: String? { self == .vibrate ? nil : rawValue }
    var fileName: String? { resourceName.map { "\($0).wav" } }
}

enum HardwareButton: String {
    case side, top, home
    var title: String {
        switch self {
        case .side: return String(localized: "サイドボタン")
        case .top: return String(localized: "トップボタン")
        case .home: return String(localized: "ホームボタン")
        }
    }
    // Safe-area inference avoids a model-ID list, including future devices.
    static func current(hasHomeIndicator: Bool) -> HardwareButton {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return hasHomeIndicator ? .top : .home
        }
        return hasHomeIndicator ? .side : .home
    }
}

extension Notification.Name {
    static let thirtyNotificationArrived = Notification.Name("Thirty.notificationArrived")
}
