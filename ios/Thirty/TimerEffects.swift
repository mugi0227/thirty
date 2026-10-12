import AVFoundation
import UIKit

@MainActor
final class TimerEffects: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var previousBrightness: CGFloat?

    func playAlarm(_ sound: EndSound = .chime) {
        guard let name = sound.resourceName else {
            vibrate()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
        } catch { stopAlarm() }
    }
    /// Three firm taps for the silent choice.
    private func vibrate() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.35) { generator.impactOccurred() }
        }
    }

    func stopAlarm() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
        case .chime: return "チャイム"
        case .beep: return "ピピピ（キッチンタイマー）"
        case .bell: return "ベル"
        case .soft: return "やさしい音"
        case .vibrate: return "振動のみ"
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
        case .side: return "サイドボタン"
        case .top: return "トップボタン"
        case .home: return "ホームボタン"
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
