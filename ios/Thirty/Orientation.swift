import SwiftUI
import UIKit

/// Read by the app delegate, which UIKit asks before every rotation.
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
}

/// Video-player style rotation: the button forces an orientation, and turning
/// the phone to match it hands rotation back to the accelerometer.
@MainActor
final class OrientationController: ObservableObject {
    @Published private(set) var forced: UIInterfaceOrientationMask?
    private var observer: NSObjectProtocol?

    /// iPad windows can be resized, so rotation there stays with the system.
    var canForce: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.releaseIfMatched() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func toggle(isLandscape: Bool) {
        let mask: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscape
        forced = mask
        apply(mask, request: true)
        // Already holding the phone that way: no rotation event will come to release it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.releaseIfMatched() }
    }

    private func releaseIfMatched() {
        guard let forced else { return }
        let device = UIDevice.current.orientation
        let matched = forced == .portrait ? device == .portrait : device.isLandscape
        guard matched else { return }
        self.forced = nil
        apply(.allButUpsideDown, request: false)
    }

    private func apply(_ mask: UIInterfaceOrientationMask, request: Bool) {
        OrientationLock.mask = mask
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if request {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}
