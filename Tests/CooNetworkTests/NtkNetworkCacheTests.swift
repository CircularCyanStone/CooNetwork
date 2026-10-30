import Foundation
import Testing
@testable import CooNetwork

struct NtkNetworkCacheTests {
    @Test
    func cache_can_be_constructed_and_shared_outside_an_actor() async {
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage())
        let request = NtkMutableRequest(NetworkCacheTestRequest())
        let requestIdentity = NtkRequestIdentity(value: "opaque-request-identity-sendable")

        async let firstResult = cache.hasData(for: request, requestIdentity: requestIdentity)
        async let secondResult = cache.hasData(for: request, requestIdentity: requestIdentity)

        let (first, second) = await (firstResult, secondResult)
        #expect(first)
        #expect(second)
        requireSendable(cache)
    }

    @Test
    func cacheUsesProvidedOpaqueRequestIdentityWithoutRecalculation() async {
        let capture = NetworkCacheKeyCapture()
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage(capture: capture))
        let request = NtkMutableRequest(NetworkCacheTestRequest())
        let requestIdentity = NtkRequestIdentity(value: "opaque-request-identity-explicit")

        _ = await cache.hasData(for: request, requestIdentity: requestIdentity)

        #expect(await capture.key() == requestIdentity.value)
        requireSendable(cache)
    }

    @Test
    func saveWritesRoundTrippableDataToStorage() async {
        let storage = NetworkCacheSaveSpyStorage()
        let cache = NtkNetworkCache(storage: storage)
        let request = NtkMutableRequest(NetworkCacheSavableRequest())
        let requestIdentity = NtkRequestIdentity(value: "opaque-request-identity-savable")

        let saved = await cache.save(
            data: ["code": 0, "module": NSNull()] as [String: Sendable],
            for: request,
            requestIdentity: requestIdentity
        )

        #expect(saved)
        #expect(await storage.saveCount() == 1)
    }

    @Test
    func saveSkipsStorageWhenDataCannotBeDecodedBack() async {
        let storage = NetworkCacheSaveSpyStorage()
        let cache = NtkNetworkCache(storage: storage)
        let request = NtkMutableRequest(NetworkCacheSavableRequest())
        let requestIdentity = NtkRequestIdentity(value: "opaque-request-identity-unsavable")

        // URL 能被归档编码，但不在解档白名单内；放行会留下「写成功、读不出」的脏缓存。
        let saved = await cache.save(
            data: ["u": URL(string: "https://example.com")!] as [String: Sendable],
            for: request,
            requestIdentity: requestIdentity
        )

        #expect(!saved)
        #expect(await storage.saveCount() == 0)
    }
}

private actor NetworkCacheSaveSpy {
    private var count = 0

    func record() {
        count += 1
    }

    func total() -> Int {
        count
    }
}

private struct NetworkCacheSaveSpyStorage: iNtkCacheStorage {
    private let spy = NetworkCacheSaveSpy()

    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        await spy.record()
        return true
    }

    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        nil
    }

    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }

    func saveCount() async -> Int {
        await spy.total()
    }
}

private struct NetworkCacheSavableRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://example.com") }
    var path: String { "/cache/savable" }
    var method: NtkHTTPMethod { .get }
    var timeout: TimeInterval { 30 }
    var cacheConfiguration: NtkCacheConfiguration? { .default() }
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
