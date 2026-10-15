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

    override func tearDown() {
        // Return the app to the foreground after Island/Lock Screen captures so
        // the next launch does not have to terminate a suspended process.
        let app = XCUIApplication()
        if (testRun?.failureCount ?? 0) > 0 {
            shot("failure-" + name.replacingOccurrences(of: "/", with: "-"))
            print(app.debugDescription)
        }
        if app.state != .notRunning {
            app.activate()
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// The Simulator posts its own notices (such as Apple Intelligence setup) on
    /// the Lock Screen. Swipe them away so the capture keeps the full screen.
    private func clearNotifications(_ springboard: XCUIApplication) {
        for _ in 0..<3 {
            let notice = springboard.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Apple Intelligence", "通知"))
                .element(boundBy: 0)
            guard notice.exists, notice.isHittable else { return }
            notice.swipeLeft()
            for label in ["消去", "Clear"] where springboard.buttons[label].waitForExistence(timeout: 1) {
                springboard.buttons[label].tap()
            }
            sleep(1)
        }
    }

    private func closeHint(_ app: XCUIApplication) {
        let close = app.buttons["ボタンの案内を閉じる"]
        // A tap during the start animation can be missed, so check again.
        guard close.waitForExistence(timeout: 2) else { return }
        for _ in 0..<3 where close.exists {
            close.tap()
            sleep(1)
        }
    }

    private func startRunning(_ app: XCUIApplication, closingHint: Bool = true) {
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 10))
        for _ in 0..<2 {
            app.buttons["開始"].tap()
            let started = NSPredicate { _, _ in
                app.buttons["残り時間"].exists || app.buttons["おしまい"].exists
            }
            if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: started, object: nil)], timeout: 5) == .completed {
                if closingHint { closeHint(app) }
                return
            }
        }
        XCTFail("The timer did not start after tapping Play")
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
        // Jump straight to the deadline; no accelerated clock or CPU race.
        // Keep 30 minutes as the configured duration for the "one more" label.
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyJumpAfterStart", "1800"])
        startRunning(app, closingHint: false) // the hint leaves by itself at the end
        XCTAssertTrue(app.buttons["おしまい"].waitForExistence(timeout: 30))
        sleep(1)
        shot("04-finished")
    }

    func test6BreakAndSavedSets() {
        let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES",
                          "-ThirtyDemoSeconds", "1500", "-ThirtyJumpAfterStart", "1500",
                          "-breakLength", "5", "-repeatEnabled", "YES"])
        XCTAssertTrue(app.buttons["時間を変更"].waitForExistence(timeout: 15))
        app.buttons["時間を変更"].tap()
        XCTAssertTrue(app.buttons["save-set"].waitForExistence(timeout: 10))
        app.buttons["save-set"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "25分", "くり返し")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        sleep(1)
        shot("09-saved-sets")
        app.buttons["時間を決定"].tap()
        startRunning(app)
        XCTAssertTrue(app.staticTexts["休憩"].waitForExistence(timeout: 15))
        closeHint(app)
        sleep(5)
        shot("08-break")
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
            let app = launch(["-onboardingSeen.v3", "YES", "-ThirtyPlusUnlocked", "YES", "-skin", "amber", "-ThirtyJumpAfterStart", "450"])
            startRunning(app)
            sleep(2)
            XCUIDevice.shared.press(.home)
            sleep(3)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            // Answer the one-time "Allow Live Activities" prompt if it shows.
            for label in ["許可", "Allow"] where springboard.buttons[label].waitForExistence(timeout: 1) {
                springboard.buttons[label].tap()
            }
            // The island over another app, at its real place and size, with
            // no home screen icons in the picture.
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            settings.activate()
            sleep(3)
            shot("07-dynamic-island") // compact, as it normally sits
            XCUIDevice.shared.press(.home)
            sleep(2)
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
                clearNotifications(springboard)
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
        startRunning(app)
        XCTAssertTrue(app.buttons["おしまい"].waitForExistence(timeout: 40))
        sleep(4)
        FileManager.default.createFile(atPath: directory + "/done", contents: nil)
        sleep(3)
    }
}
