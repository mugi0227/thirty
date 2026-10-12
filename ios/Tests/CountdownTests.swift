import XCTest
@testable import ThirtyCore

final class CountdownTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000_000)

    func testBackgroundTimeDoesNotDependOnCallbacks() {
        var timer = Countdown()
        timer.start(at: start)
        XCTAssertEqual(timer.seconds(at: start.addingTimeInterval(154)), 1646)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(154)), 28)
        timer.refresh(at: start.addingTimeInterval(1801))
        XCTAssertEqual(timer.phase, .finished)
        XCTAssertEqual(timer.seconds(at: start.addingTimeInterval(1801)), 0)
    }

    func testPauseResumePreservesFractionalTime() {
        var timer = Countdown()
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(15.5))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1000)), 1784.5)
        timer.resume(at: start.addingTimeInterval(1000))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1010)), 1774.5)
    }

    func testRelaunchRestoresDeadlineThenCompletes() throws {
        var timer = Countdown()
        timer.start(at: start)
        let data = try JSONEncoder().encode(timer)
        var restored = try JSONDecoder().decode(Countdown.self, from: data)
        XCTAssertEqual(restored.seconds(at: start.addingTimeInterval(90)), 1710)
        restored.refresh(at: start.addingTimeInterval(2000))
        XCTAssertEqual(restored.phase, .finished)
    }

    func testPauseAtDeadlineDoesNotReviveExpiredSession() {
        var timer = Countdown()
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(1800))
        timer.resume(at: start.addingTimeInterval(1900))
        XCTAssertEqual(timer.phase, .finished)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(1900)), 0)
    }

    func testMinuteBoundariesAndReset() {
        var timer = Countdown()
        timer.start(at: start)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(59.99)), 30)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(60)), 29)
        timer.reset()
        XCTAssertEqual(timer.phase, .ready)
        XCTAssertEqual(timer.seconds(at: start), 1800)
        XCTAssertEqual(timer.bars(at: start), 30)
    }

    func testZeroAndMaximumDuration() {
        var timer = Countdown()
        timer.setSeconds(0, at: start)
        timer.start(at: start)
        XCTAssertEqual(timer.phase, .ready)
        XCTAssertEqual(timer.bars(at: start), 0)
        timer.setSeconds(100_000, at: start)
        XCTAssertEqual(timer.configuredSeconds, 59_999)
        timer.start(at: start)
        XCTAssertEqual(timer.seconds(at: start), 59_999)
        timer.refresh(at: start.addingTimeInterval(59_999))
        XCTAssertEqual(timer.phase, .finished)
    }

    func testDurationsBeyondNinetyNineMinutes() {
        var timer = Countdown()
        timer.setSeconds(120 * 60, at: start)
        timer.start(at: start)
        XCTAssertEqual(timer.seconds(at: start.addingTimeInterval(60 * 60)), 3600)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(60 * 60)), 15)
    }

    func testCustomBarsAndStopKeepChosenDuration() {
        var timer = Countdown()
        timer.setSeconds(120, at: start)
        timer.start(at: start)
        XCTAssertEqual(timer.bars(at: start.addingTimeInterval(60)), 15)
        timer.reset()
        XCTAssertEqual(timer.seconds(at: start), 120)
        XCTAssertEqual(timer.phase, .ready)
    }

    func testEditingRunningTimerReplacesItsDeadline() {
        var timer = Countdown()
        timer.setSeconds(60, at: start)
        timer.start(at: start)
        timer.setSeconds(120, at: start.addingTimeInterval(50))
        timer.refresh(at: start.addingTimeInterval(61))
        XCTAssertEqual(timer.phase, .running)
        XCTAssertEqual(timer.seconds(at: start.addingTimeInterval(61)), 109)
        timer.setSeconds(0, at: start.addingTimeInterval(61))
        XCTAssertEqual(timer.phase, .ready)
        XCTAssertNil(timer.deadline)
    }

    func testLegacySessionWithoutDurationStillRestores() throws {
        var timer = Countdown()
        timer.start(at: start)
        var values = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(timer)) as? [String: Any])
        values.removeValue(forKey: "configuredSeconds")
        let restored = try JSONDecoder().decode(Countdown.self, from: JSONSerialization.data(withJSONObject: values))
        XCTAssertEqual(restored.seconds(at: start.addingTimeInterval(90)), 1710)
        XCTAssertEqual(restored.configuredSeconds, 1800)
    }
}
