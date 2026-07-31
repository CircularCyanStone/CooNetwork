import Foundation
import Testing
@testable import CooNetwork

struct NtkNetworkCacheTests {
    @Test
    func cache_can_be_constructed_and_shared_outside_an_actor() async {
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage())
        let request = NtkMutableRequest(NetworkCacheTestRequest())

        async let firstResult = cache.hasData(for: request)
        async let secondResult = cache.hasData(for: request)

        let (first, second) = await (firstResult, secondResult)
        #expect(first)
        #expect(second)
        requireSendable(cache)
    }
}

private struct NetworkCacheTestStorage: iNtkCacheStorage {
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        true
    }

    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        nil
    }

    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        true
    }
}

private struct NetworkCacheTestRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://example.com") }
    var path: String { "/cache/sendable" }
    var method: NtkHTTPMethod { .get }
    var timeout: TimeInterval { 30 }
}

private func requireSendable<T: Sendable>(_ value: T) {}
