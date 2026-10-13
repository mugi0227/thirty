/// Shares an in-flight product lookup, while allowing a later attempt after
/// an empty response or an error. It never caches either failure as a result.
actor ProductRequest<Value: Sendable> {
    private let fetch: @Sendable () async throws -> Value?
    private var inFlight: Task<Value?, Error>?

    init(fetch: @escaping @Sendable () async throws -> Value?) {
        self.fetch = fetch
    }

    func value() async throws -> Value? {
        if let inFlight { return try await inFlight.value }
        let fetch = self.fetch
        let request = Task { try await fetch() }
        inFlight = request
        defer { inFlight = nil }
        return try await request.value
    }
}
