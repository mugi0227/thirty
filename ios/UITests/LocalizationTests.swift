import XCTest

/// Exercises the compiled app in both supported languages, including strings
/// passed through ordinary String properties and the purchase error controls.
final class LocalizationTests: XCTestCase {
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

    private func walk(language: String) {
        let english = language == "en"
        let next = english ? "Next" : "次へ"
        let close = english ? "Close" : "閉じる"
        let settings = english ? "Settings" : "設定"
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", english ? "en_US" : "ja_JP",
                               "-ThirtyResetState", "YES", "-ThirtyNoPrompt", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons[next].waitForExistence(timeout: 15))
        shot(language + "-01-welcome")
        app.buttons[next].tap()
        XCTAssertTrue(app.buttons[english ? "Open Settings" : "設定を開く"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", english ? "Guided Access" : "アクセスガイド")).firstMatch.exists)
        shot(language + "-02-guided-access")
        app.buttons[next].tap()
        shot(language + "-03-biometry")
        app.buttons[next].tap()
        shot(language + "-04-buttons")
        app.buttons[english ? "Open timer" : "タイマーへ"].tap()
        let guideClosed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons[english ? "Open timer" : "タイマーへ"])
        XCTAssertEqual(XCTWaiter.wait(for: [guideClosed], timeout: 10), .completed)
        XCTAssertTrue(app.buttons[english ? "Start" : "開始"].waitForExistence(timeout: 5))
        shot(language + "-05-timer")
        app.buttons[english ? "Change time" : "時間を変更"].tap()
        let cancel = app.buttons[english ? "Cancel" : "キャンセル"]
        let pickerOpened = cancel.waitForExistence(timeout: 15)
        shot(language + "-06-time-picker")
        if !pickerOpened { print(app.debugDescription) }
        XCTAssertTrue(pickerOpened)
        XCTAssertTrue(app.buttons[english ? "Set time" : "時間を決定"].exists)
        cancel.tap()
        app.buttons[settings].tap()
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches[english ? "Start when opened" : "開いたらすぐスタート"].exists)
        shot(language + "-07-settings")
        app.buttons[english ? "Explore Thirty+" : "Thirty+ でできること"].tap()
        XCTAssertTrue(app.buttons["close-plus"].waitForExistence(timeout: 5))
        shot(language + "-08-plus-top")
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons[english ? "Restore purchases" : "購入を復元"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[english ? "One-time purchase. No subscription." : "買い切りです。定期購入ではありません。"].exists)
        shot(language + "-09-plus-purchase")
        app.buttons["close-plus"].tap()
        app.swipeUp()
        app.swipeUp()
        let privacy = app.descendants(matching: .any).matching(identifier: "privacy-policy-link").firstMatch
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        XCTAssertEqual(privacy.label, english ? "Privacy policy" : "プライバシーポリシー")
        shot(language + "-10-settings-links")
        app.buttons["close-settings"].tap()
        app.buttons[english ? "Skins" : "スキン"].tap()
        XCTAssertTrue(app.navigationBars[english ? "Skins" : "スキン"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[english ? "Classic" : "クラシック"].firstMatch.exists)
        shot(language + "-11-skins")
        app.buttons[close].firstMatch.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        shot(language + "-12-landscape")
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    func testEnglish() { walk(language: "en") }
    func testJapanese() { walk(language: "ja") }
}
