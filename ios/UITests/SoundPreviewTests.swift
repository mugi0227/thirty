import XCTest

final class SoundPreviewTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func open(language: String, plus: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "ja_JP",
                               "-ThirtyResetState", "YES", "-ThirtyNoPrompt", "YES", "-onboardingSeen.v3", "YES",
                               "-ThirtyPlusUnlocked", plus ? "YES" : "NO"]
        app.launch()
        let settings = app.buttons[language == "en" ? "Settings" : "設定"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        app.buttons["end-sound-settings"].tap()
        XCTAssertTrue(app.buttons["end-sound-preview-beep"].waitForExistence(timeout: 5))
        return app
    }

    private func expect(_ button: XCUIElement, label: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
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

    func testJapanesePreviewWithoutPurchase() {
        let app = open(language: "ja", plus: false)
        let beep = app.buttons["end-sound-preview-beep"]
        let bell = app.buttons["end-sound-preview-bell"]
        XCTAssertTrue(app.buttons["end-sound-select-alarm"].isSelected)
        shot("ja-free-sounds")

        // Trying a paid sound must not change the selection or open the paywall.
        beep.tap()
        expect(beep, label: "プレビューを停止")
        XCTAssertFalse(app.buttons["close-plus"].exists)
        XCTAssertTrue(app.buttons["end-sound-select-alarm"].isSelected)
        bell.tap()
        expect(bell, label: "プレビューを停止")
        expect(beep, label: "試聴")
        bell.tap()
        expect(bell, label: "試聴")

        // Previews end automatically, and a selection remains a separate action.
        beep.tap()
        expect(beep, label: "プレビューを停止")
        expect(beep, label: "試聴")
        app.buttons["end-sound-select-bell"].tap()
        XCTAssertTrue(app.buttons["close-plus"].waitForExistence(timeout: 5))
        app.buttons["close-plus"].tap()
        XCTAssertTrue(app.buttons["end-sound-select-alarm"].isSelected)

        beep.tap()
        expect(beep, label: "プレビューを停止")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["end-sound-settings"].tap()
        expect(beep, label: "試聴")
    }

    func testEnglishPlusSelectionAndVibration() {
        let app = open(language: "en", plus: true)
        shot("en-plus-sounds")
        let bell = app.buttons["end-sound-preview-bell"]
        app.buttons["end-sound-select-bell"].tap()
        XCTAssertTrue(app.buttons["end-sound-select-bell"].isSelected)
        expect(bell, label: "Preview")
        XCTAssertFalse(app.buttons["close-plus"].exists)

        let vibration = app.buttons["end-sound-preview-vibrate"]
        vibration.tap()
        expect(vibration, label: "Stop preview")
        expect(vibration, label: "Try vibration")
        XCTAssertTrue(app.buttons["end-sound-select-bell"].isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Bell"].exists)
        app.buttons["end-sound-settings"].tap()
        XCTAssertTrue(app.buttons["end-sound-select-bell"].isSelected)
    }
}
