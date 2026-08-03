import Foundation
import Testing
@testable import CooNetwork

struct NtkNetworkCacheTests {
    @Test
    func cache_can_be_constructed_and_shared_outside_an_actor() async {
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage())
        let request = NtkMutableRequest(NetworkCacheTestRequest())
        let identity = NtkRequestIdentity(digest: "ntk-identity-v2-sendable")

        async let firstResult = cache.hasData(for: request, identity: identity)
        async let secondResult = cache.hasData(for: request, identity: identity)

        let (first, second) = await (firstResult, secondResult)
        #expect(first)
        #expect(second)
        requireSendable(cache)
    }

    @Test
    func cacheUsesProvidedOpaqueIdentityWithoutRecalculation() async {
        let capture = NetworkCacheKeyCapture()
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage(capture: capture))
        let request = NtkMutableRequest(NetworkCacheTestRequest())
        let identity = NtkRequestIdentity(digest: "ntk-identity-v2-explicit")

        _ = await cache.hasData(for: request, identity: identity)

        #expect(await capture.key() == identity.digest)
        requireSendable(cache)
    }
}

private struct NetworkCacheTestStorage: iNtkCacheStorage {
    let capture: NetworkCacheKeyCapture?

    init(capture: NetworkCacheKeyCapture? = nil) {
        self.capture = capture
    }

    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        await capture?.record(key)
        return true
    }

    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        await capture?.record(key)
        return nil
    }

    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        await capture?.record(key)
        return true
    }
}

private actor NetworkCacheKeyCapture {
    private var lastKey: String?

    func record(_ key: String) {
        lastKey = key
    }

    func key() -> String? {
        lastKey
    }
}

private struct NetworkCacheTestRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://example.com") }
    var path: String { "/cache/sendable" }
    var method: NtkHTTPMethod { .get }
    var timeout: TimeInterval { 30 }
}

private func requireSendable<T: Sendable>(_ value: T) {}
