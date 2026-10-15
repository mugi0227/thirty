import XCTest
@testable import ThirtyCore

final class PlusProductsTests: XCTestCase {
    func testCurrentPurchaseUnlocksPlus() {
        XCTAssertTrue(PlusProducts.hasAccess([
            PlusEntitlement(productID: "jp.mugilab.thirty.diagnostic", isRevoked: false)
        ]))
    }

    func testLegacyPurchaseStillRestoresPlus() {
        XCTAssertTrue(PlusProducts.hasAccess([
            PlusEntitlement(productID: "jp.mugilab.thirty.plus", isRevoked: false)
        ]))
    }

    func testRefundOfOneProductKeepsAccessFromTheOtherInEitherOrder() {
        let current = PlusEntitlement(productID: "jp.mugilab.thirty.diagnostic", isRevoked: false)
        let refundedLegacy = PlusEntitlement(productID: "jp.mugilab.thirty.plus", isRevoked: true)
        XCTAssertTrue(PlusProducts.hasAccess([current, refundedLegacy]))
        XCTAssertTrue(PlusProducts.hasAccess([refundedLegacy, current]))
        let legacy = PlusEntitlement(productID: "jp.mugilab.thirty.plus", isRevoked: false)
        let refundedCurrent = PlusEntitlement(productID: "jp.mugilab.thirty.diagnostic", isRevoked: true)
        XCTAssertTrue(PlusProducts.hasAccess([legacy, refundedCurrent]))
        XCTAssertTrue(PlusProducts.hasAccess([refundedCurrent, legacy]))
    }

    func testOnlyRevokedPurchasesDoNotUnlockPlus() {
        XCTAssertFalse(PlusProducts.hasAccess([
            PlusEntitlement(productID: "jp.mugilab.thirty.plus", isRevoked: true),
            PlusEntitlement(productID: "jp.mugilab.thirty.diagnostic", isRevoked: true)
        ]))
    }

    func testUnrelatedPurchasesAndEmptyHistoryDoNotUnlockPlus() {
        XCTAssertFalse(PlusProducts.hasAccess([
            PlusEntitlement(productID: "unrelated.product", isRevoked: false)
        ]))
        XCTAssertFalse(PlusProducts.hasAccess([]))
    }
}
