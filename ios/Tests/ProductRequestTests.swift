import XCTest
@testable import ThirtyCore

private actor LookupFixture {
    enum Failure: Error { case unavailable }
    var calls = 0
    private let firstEmpty: Bool
    private let firstFailure: Bool
    private let delay: UInt64

    init(firstEmpty: Bool = false, firstFailure: Bool = false, delay: UInt64 = 0) {
        self.firstEmpty = firstEmpty
        self.firstFailure = firstFailure
        self.delay = delay
    }

    func fetch() async throws -> String? {
        calls += 1
        let attempt = calls
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        if attempt == 1 && firstFailure { throw Failure.unavailable }
        if attempt == 1 && firstEmpty { return nil }
        return "Thirty+"
    }
}

final class ProductRequestTests: XCTestCase {
    func testEmptyStartupResponseCanBeRetried() async throws {
        let fixture = LookupFixture(firstEmpty: true)
        let request = ProductRequest { try await fixture.fetch() }
        let initial = try await request.value()
        XCTAssertNil(initial)
        let retry = try await request.value()
        XCTAssertEqual(retry, "Thirty+")
        let count = await fixture.calls
        XCTAssertEqual(count, 2)
    }

    func testConnectionFailureDoesNotPoisonFutureAttempts() async throws {
        let fixture = LookupFixture(firstFailure: true)
        let request = ProductRequest { try await fixture.fetch() }
        do {
            _ = try await request.value()
            XCTFail("Expected the connection failure")
        } catch LookupFixture.Failure.unavailable {
        }
        let retry = try await request.value()
        XCTAssertEqual(retry, "Thirty+")
        let count = await fixture.calls
        XCTAssertEqual(count, 2)
    }

    func testConcurrentStartupAndPaywallLookupShareTheRequest() async throws {
        let fixture = LookupFixture(delay: 100_000_000)
        let request = ProductRequest { try await fixture.fetch() }
        async let startup = request.value()
        async let paywall = request.value()
        async let retry = request.value()
        let values = try await [startup, paywall, retry]
        XCTAssertEqual(values, ["Thirty+", "Thirty+", "Thirty+"])
        let count = await fixture.calls
        XCTAssertEqual(count, 1)
    }
}
