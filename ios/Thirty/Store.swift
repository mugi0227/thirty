import Combine
import Foundation
import OSLog
import StoreKit

private let purchaseLog = Logger(subsystem: "jp.mugilab.thirty", category: "PurchaseDiagnostics")

/// Thirty+ is a single non-consumable purchase. The timer itself stays free
/// and ad-free; Thirty+ unlocks the extra skins.
@MainActor
final class Store: ObservableObject {
    static let plusID = "jp.mugilab.thirty.plus"
    private static let cacheKey = "hasPlus.cache"

    @Published private(set) var product: Product?
    @Published private(set) var hasPlus: Bool
    @Published private(set) var isBusy = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isDiagnosingProducts = false
    @Published private(set) var productLoadFailure: String?
    @Published private(set) var diagnosticMessage: String?
    @Published var message: String?
    private var updates: Task<Void, Never>?
    private let productRequest: ProductRequest<Product>

    init() {
        let productID = Self.plusID
        productRequest = ProductRequest {
            purchaseLog.info("Requesting product \(productID, privacy: .public)")
            let products = try await Product.products(for: [productID])
            purchaseLog.info("Product response count=\(products.count, privacy: .public)")
            return products.first
        }
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
        await reloadProduct()
        await refreshEntitlements()
    }

    @discardableResult
    func reloadProduct() async -> Bool {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        message = nil
        if !isDiagnosingProducts { diagnosticMessage = nil }
        let started = Date()
        do {
            product = try await productRequest.value()
            if product == nil {
                productLoadFailure = "Thirty+の商品情報が見つかりませんでした。時間をおいて、商品情報を読み直してください。"
                diagnosticMessage = await lookupDetails("App Storeから商品が返りませんでした。\n商品ID: \(Self.plusID)\n取得件数: 0", started: started)
            } else {
                productLoadFailure = nil
                diagnosticMessage = nil
            }
        } catch {
            product = nil
            productLoadFailure = "商品情報を読み込めませんでした。通信を確認して、もう一度お試しください。"
            diagnosticMessage = await lookupDetails(details(error), started: started)
        }
        return product != nil
    }

    /// Invoked explicitly from the error details. Compares the catalog response
    /// without attempting a purchase or changing the entitlement cache.
    func diagnoseProducts() async {
        guard !isBusy, !isLoadingProducts, !isDiagnosingProducts else { return }
        isDiagnosingProducts = true
        defer { isDiagnosingProducts = false }
        let loaded = await reloadProduct()
        guard !loaded else { return }
        let details = diagnosticMessage ?? ""
        let probe = CatalogProbe()
        let comparison = await probe.inspect(productID: Self.plusID)
        diagnosticMessage = details + "\n\n" + comparison
    }

    private func lookupDetails(_ result: String, started: Date) async -> String {
        let elapsed = String(format: "%.2f", Date().timeIntervalSince(started))
        let storefront = await Storefront.current
        let country = storefront?.countryCode ?? "不明"
        let id = storefront?.id ?? "不明"
        let bundle = Bundle.main.bundleIdentifier ?? "不明"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "不明"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "不明"
        purchaseLog.info("Lookup context country=\(country, privacy: .public) storefront=\(id, privacy: .public) build=\(build, privacy: .public)")
        return result + "\n取得時間: \(elapsed)秒\n実際の販売地域: \(country) / \(id)\nアプリ: \(bundle)\nバージョン: \(version) (\(build))"
    }

    func purchase() async {
        guard !isBusy, !isDiagnosingProducts else { return }
        isBusy = true
        defer { isBusy = false }
        if product == nil { await reloadProduct() }
        guard let product else { return }
        diagnosticMessage = nil
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
            diagnosticMessage = details(error)
        }
    }

    func restore() async {
        guard !isBusy, !isDiagnosingProducts else { return }
        isBusy = true
        defer { isBusy = false }
        diagnosticMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = hasPlus ? nil : "復元できる購入は見つかりませんでした。"
        } catch {
            message = "購入を復元できませんでした。通信を確認して、もう一度お試しください。"
            diagnosticMessage = details(error)
        }
    }

    private func details(_ error: Error) -> String {
        let error = error as NSError
        return "\(error.domain) / \(error.code)\n\(error.localizedDescription)"
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
