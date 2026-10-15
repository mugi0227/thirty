import XCTest
import UIKit

final class LiveActivityAppearanceTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
        }
    }

    private func islandHasColor(_ hex: UInt32) -> Bool {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { return false }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        return bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            let pixels = buffer.bindMemory(to: UInt8.self)
            let target = [Int((hex >> 16) & 255), Int((hex >> 8) & 255), Int(hex & 255)]
            var count = 0
            for topY in Int(Double(height) * 0.015)..<Int(Double(height) * 0.085) {
                // Accommodate either bitmap row orientation when normalizing a screenshot.
                for y in [topY, height - 1 - topY] {
                    for x in Int(Double(width) * 0.22)..<Int(Double(width) * 0.82) {
                        let offset = (y * width + x) * 4
                        guard (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - target[$0]) < 20 }) else { continue }
                        // Require black next to the color so wallpaper and status icons do not count.
                        let nearBlack = [-8, 8].contains { dx in
                            let adjacent = (y * width + x + dx) * 4
                            return (0..<3).allSatisfy { pixels[adjacent + $0] < 12 }
                        }
                        if nearBlack { count += 1 }
                        if count >= 50 { return true }
                    }
                }
            }
            return false
        }
    }

    func testChangeSkinWhileTimerKeepsRunning() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "Dynamic Island is an iPhone feature")
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-ThirtyResetState", "YES",
                               "-ThirtyNoPrompt", "YES", "-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 15))
        app.buttons["開始"].tap()
        if app.buttons["ボタンの案内を閉じる"].waitForExistence(timeout: 2) {
            app.buttons["ボタンの案内を閉じる"].tap()
        }

        let colors: [String: UInt32] = ["classic": 0xB8C1AA, "paper": 0xECEBE6, "mint": 0xD3EBDD,
                                       "amber": 0xFFB33C, "night": 0x7CC4FF, "ruby": 0xFF4B3E]
        // Widget registration is asynchronous on a freshly installed Simulator.
        // Warm it up before checking all six skins during the same running timer.
        for (index, skin) in (["amber", "night", "ruby"] + ["classic", "paper", "mint", "amber", "night", "ruby"]).enumerated() {
            app.activate()
            // Reveal controls if the running timer has hidden them.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
            app.buttons["スキン"].tap()
            let choice = app.buttons["skin-choice-" + skin]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            XCTAssertEqual(choice.value as? String, "使用中")
            app.buttons["close-skins"].tap()
            if index >= 3 { shot("app-skin-" + skin) }
            XCUIDevice.shared.press(.home)
            // ActivityKit renders the extension asynchronously.
            Thread.sleep(forTimeInterval: 2)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["許可", "Allow"] where springboard.buttons[label].exists {
                springboard.buttons[label].tap()
            }
            if index >= 3 {
                let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    self.islandHasColor(colors[skin]!)
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 60), .completed, "Island did not render \(skin)")
                shot("island-skin-" + skin)
            }
        }
    }
}
