import Foundation
import StoreKit

/// Read-only comparison with the older product catalog API. It never creates
/// a payment or grants an entitlement. Kept on the diagnostic build branch.
@MainActor
final class CatalogProbe: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var continuation: CheckedContinuation<String, Never>?
    private var timeout: Task<Void, Never>?

    func inspect(productID: String) async -> String {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = SKProductsRequest(productIdentifiers: [productID])
            self.request = request
            request.delegate = self
            timeout = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 12_000_000_000)
                    self?.finish("比較用の商品取得: 12秒で応答なし")
                } catch { /* Completed before the timeout. */ }
            }
            request.start()
        }
    }

    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let ids = response.products.map(\.productIdentifier).sorted()
        let invalid = response.invalidProductIdentifiers.sorted()
        let text = "比較用の商品取得: \(ids.count)件\n取得した商品ID: \(ids.isEmpty ? "なし" : ids.joined(separator: ", "))\nAppleが認識しない商品ID: \(invalid.isEmpty ? "なし" : invalid.joined(separator: ", "))"
        Task { @MainActor in self.finish(text) }
    }

    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        let error = error as NSError
        let text = "比較用の商品取得: \(error.domain) / \(error.code)\n\(error.localizedDescription)"
        Task { @MainActor in self.finish(text) }
    }

    private func finish(_ text: String) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        request?.delegate = nil
        request?.cancel()
        request = nil
        continuation.resume(returning: text)
    }
}
