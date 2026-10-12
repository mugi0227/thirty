import Combine
import Foundation
import StoreKit

/// Thirty+ is a single non-consumable purchase. The timer itself stays free
/// and ad-free; Thirty+ unlocks the extra skins.
@MainActor
final class Store: ObservableObject {
    static let plusID = "jp.mugilab.thirty.plus"
    private static let cacheKey = "hasPlus.cache"

    @Published private(set) var product: Product?
    @Published private(set) var hasPlus: Bool
    @Published private(set) var isBusy = false
    @Published var message: String?
    private var updates: Task<Void, Never>?

    init() {
        // The cache only avoids a flash of locked skins at launch; StoreKit decides.
        hasPlus = UserDefaults.standard.bool(forKey: Self.cacheKey) || Self.debugUnlocked
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await load() }
    }

    deinit { updates?.cancel() }

    var priceText: String { product?.displayPrice ?? "—" }

    func load() async {
        do {
            product = try await Product.products(for: [Self.plusID]).first
        } catch {
            product = nil
        }
        await refreshEntitlements()
    }

    func purchase() async {
        guard let product else {
            message = "App Storeに接続できませんでした。時間をおいてお試しください。"
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setPlus(true)
                    message = nil
                } else {
                    message = "購入を確認できませんでした。"
                }
            case .pending:
                message = "購入の承認待ちです。承認されると自動で使えるようになります。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "購入できませんでした。"
        }
    }

    func restore() async {
        isBusy = true
        defer { isBusy = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        message = hasPlus ? nil : "復元できる購入は見つかりませんでした。"
    }

    private func refreshEntitlements() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.plusID, transaction.revocationDate == nil {
                owned = true
            }
        }
        setPlus(owned)
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        if transaction.productID == Self.plusID { setPlus(transaction.revocationDate == nil) }
    }

    private func setPlus(_ owned: Bool) {
        hasPlus = owned || Self.debugUnlocked
        UserDefaults.standard.set(owned, forKey: Self.cacheKey)
    }

    /// UI tests pass -ThirtyPlusUnlocked YES to photograph paid skins.
    private static var debugUnlocked: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "ThirtyPlusUnlocked")
        #else
        return false
        #endif
    }
}
