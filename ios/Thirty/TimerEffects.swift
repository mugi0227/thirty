import AVFoundation
import UIKit

@MainActor
final class TimerEffects: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var previousBrightness: CGFloat?

    func playAlarm() {
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else { return }
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
