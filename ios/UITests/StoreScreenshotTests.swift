import XCTest

/// Raw captures for the App Store. CI runs this per device class, then
/// scripts/make_store_screenshots.py adds the captions.
final class StoreScreenshotTests: XCTestCase {
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let base = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-ThirtyResetState", "YES", "-ThirtyNoPrompt", "YES", "-ThirtyNoBlink", "YES"]

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = base + arguments
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    private func closeHint(_ app: XCUIApplication) {
        let close = app.buttons["ボタンの案内を閉じる"]
        if close.waitForExistence(timeout: 2) { close.tap() }
    }

    private func startRunning(_ app: XCUIApplication, closingHint: Bool = true) {
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        app.buttons["開始"].tap()
        if closingHint { closeHint(app) }
    }

    func test1Running() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyJumpAfterStart", "450"])
        startRunning(app)
        sleep(5) // controls step aside, about 22 minutes left
        shot("01-running")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        shot("02-landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
    }

    func test2Guide() {
        let app = launch([])
        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 10))
        app.buttons["次へ"].tap()
        sleep(3)
        shot("03-guided-access")
    }

    func test3Finished() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyTimeScale", "900"])
        startRunning(app, closingHint: false) // the hint leaves by itself at the end
        XCTAssertTrue(app.buttons["おしまい"].waitForExistence(timeout: 15))
        sleep(1)
        shot("04-finished")
    }

    func test4Skin() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES", "-skin", "night", "-ThirtyJumpAfterStart", "1080"])
        startRunning(app)
        sleep(6)
        shot("05-skin-night")
    }

    func test5PlusFeature() {
        if isPad {
            let app = launch(["-onboardingSeen.v3", "YES"])
            XCTAssertTrue(app.buttons["スキン"].waitForExistence(timeout: 10))
            app.buttons["スキン"].tap()
            sleep(2)
            app.buttons["アンバー"].tap()
            sleep(2)
            shot("06-skins")
        } else {
            let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES", "-skin", "amber", "-ThirtyJumpAfterStart", "300"])
            startRunning(app)
            sleep(2)
            XCUIDevice.shared.press(.home)
            sleep(3)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).press(forDuration: 1.2)
            sleep(2)
            shot("06-dynamic-island")
            // Answer the one-time "Allow Live Activities" prompt if it shows.
            for label in ["許可", "Allow"] where springboard.buttons[label].waitForExistence(timeout: 1) {
                springboard.buttons[label].tap()
            }
            // The Lock Screen shows the Live Activity without any home screen icons.
            let device = XCUIDevice.shared
            let lock = NSSelectorFromString("pressLockButton")
            if device.responds(to: lock) {
                device.perform(lock)
                sleep(2)
                device.perform(lock)
                sleep(3)
                // The Allow prompt is drawn on the Lock Screen itself.
                for label in ["許可", "Allow"] where springboard.buttons[label].waitForExistence(timeout: 2) {
                    springboard.buttons[label].tap()
                    sleep(2)
                }
                shot("06-lock-screen")
            }
        }
    }

    /// About 25 seconds, recorded by CI with `simctl io recordVideo`:
    /// ready → start (fill-up) → controls step aside while draining → finish.
    /// The test and the recorder hand over through files in SCREENSHOT_DIR so
    /// the recording starts on the ready screen and stops on the finish screen.
    func testPreviewVideo() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["SCREENSHOT_DIR"])
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyTimeScale", "100", "-ThirtyNoBlink", "NO"])
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        FileManager.default.createFile(atPath: directory + "/app-ready", contents: nil)
        let deadline = Date().addingTimeInterval(90)
        while !FileManager.default.fileExists(atPath: directory + "/recording-ready") && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        sleep(2)
        app.buttons["開始"].tap()
        closeHint(app)
        XCTAssertTrue(app.buttons["おしまい"].waitForExistence(timeout: 40))
        sleep(4)
        FileManager.default.createFile(atPath: directory + "/done", contents: nil)
        sleep(3)
    }
}
