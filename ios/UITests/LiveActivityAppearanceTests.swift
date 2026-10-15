import XCTest

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

        for skin in ["classic", "paper", "mint", "amber", "night", "ruby"] {
            app.activate()
            // Reveal controls if the running timer has hidden them.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
            app.buttons["スキン"].tap()
            let choice = app.buttons["skin-choice-" + skin]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            XCTAssertEqual(choice.value as? String, "使用中")
            app.buttons["close-skins"].tap()
            shot("app-skin-" + skin)
            XCUIDevice.shared.press(.home)
            // ActivityKit renders the extension asynchronously.
            Thread.sleep(forTimeInterval: 2)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["許可", "Allow"] where springboard.buttons[label].exists {
                springboard.buttons[label].tap()
            }
            shot("island-skin-" + skin)
        }
    }
}
