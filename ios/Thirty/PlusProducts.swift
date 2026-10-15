/// StoreKit verification happens in Store before these entitlement facts are used.
struct PlusEntitlement {
    let productID: String
    let isRevoked: Bool
}

enum PlusProducts {
    // This existing catalog record was verified on the user's device. Its ID is
    // permanent; the customer-facing name is Thirty+.
    static let purchaseID = "jp.mugilab.thirty.diagnostic"
    static let legacyID = "jp.mugilab.thirty.plus"

    static func recognizes(_ productID: String) -> Bool {
        productID == purchaseID || productID == legacyID
    }

    static func hasAccess(_ entitlements: [PlusEntitlement]) -> Bool {
        entitlements.contains { recognizes($0.productID) && !$0.isRevoked }
    }
}
