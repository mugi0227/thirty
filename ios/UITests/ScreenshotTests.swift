import XCTest

/// Walks the main screens on the Simulator and saves screenshots for review.
/// CI sets SCREENSHOT_DIR (via TEST_RUNNER_SCREENSHOT_DIR) to collect them.
final class ScreenshotTests: XCTestCase {
    private var prefix: String { ProcessInfo.processInfo.environment["SCREENSHOT_PREFIX"] ?? "" }

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            for label in ["許可", "Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-ThirtyResetState", "YES"] + arguments
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = prefix + name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(prefix)\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }

    /// Taps the bar area, which only reveals hidden controls.
    private func touchBars(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
    }

    func testOnboarding() {
        let app = launch()
        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 10))
        sleep(2)
        shot("01-onboarding-welcome")
        for name in ["02-onboarding-enable", "03-onboarding-biometry", "04-onboarding-triple"] {
            app.buttons["次へ"].tap()
            sleep(2)
            shot(name)
        }
        app.buttons["タイマーへ"].tap()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 5))
    }

    func testTimerScreens() {
        let app = launch(["-onboardingSeen.v3", "YES"])
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        shot("05-ready")

        app.buttons["開始"].tap()
        sleep(1)
        touchBars(app) // lets the interruption monitor answer the notification prompt
        sleep(2)
        shot("06-running")
        sleep(6)
        shot("07-running-idle")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        touchBars(app)
        sleep(1)
        shot("08-landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)

        touchBars(app)
        if app.buttons["横向きにする"].waitForExistence(timeout: 3) {
            app.buttons["横向きにする"].tap()
            sleep(2)
            shot("09-forced-landscape")
            app.buttons["縦向きに戻す"].tap()
            sleep(2)
        } else {
            XCTFail("Rotate button missing")
        }

        touchBars(app)
        app.buttons["一時停止"].tap()
        sleep(1)
        shot("10-paused")

        app.buttons["時間を変更"].tap()
        sleep(2)
        shot("11-time-picker")
    }

    func testSkins() {
        let app = launch(["-onboardingSeen.v3", "YES"])
        XCTAssertTrue(app.buttons["スキン"].waitForExistence(timeout: 10))
        app.buttons["スキン"].tap()
        sleep(3)
        shot("12-skins-locked")
        app.buttons["アンバー"].tap()
        sleep(1)
        shot("13-skins-try-on")
        app.terminate()

        for skin in ["amber", "night", "paper", "ruby"] {
            let paid = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES", "-skin", skin])
            XCTAssertTrue(paid.buttons["開始"].waitForExistence(timeout: 10))
            paid.buttons["開始"].tap()
            sleep(1)
            paid.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
            sleep(2)
            shot("14-skin-\(skin)")
            paid.terminate()
        }
    }

    func testFinishAndSettings() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyDemoSeconds", "3"])
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        app.buttons["開始"].tap()
        sleep(1)
        touchBars(app)
        XCTAssertTrue(app.buttons["おしまい"].waitForExistence(timeout: 10))
        sleep(1)
        shot("15-finished")
        app.buttons["おしまい"].tap()

        app.buttons["設定"].tap()
        sleep(2)
        shot("16-settings")
        if app.buttons["Thirty+ でできること"].waitForExistence(timeout: 3) {
            app.buttons["Thirty+ でできること"].tap()
            sleep(2)
            shot("17-thirty-plus")
        }
    }

    func testLiveActivity() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES", "-skin", "amber"])
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        app.buttons["開始"].tap()
        sleep(1)
        touchBars(app)
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(3)
        shot("18-dynamic-island")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).press(forDuration: 1.2)
        sleep(2)
        shot("19-dynamic-island-expanded")
    }
}
