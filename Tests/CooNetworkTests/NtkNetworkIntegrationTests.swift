import Testing
import Foundation
@testable import CooNetwork

struct NtkNetworkIntegrationTests {

    // MARK: - request() 完整成功流程

    @Test
    func requestReturnsSuccessResponse() async throws {
        let network = makeNetwork(client: IntegMockClient(result: .success(())))
        let response = try await network.request()
        #expect(response.data == true)
        #expect(response.isCache == false)
    }

    // MARK: - request() 自定义拦截器被执行

    @Test
    func requestExecutesCustomInterceptor() async throws {
        let flag = IntegAtomicFlag()
        let interceptor = IntegFlagInterceptor(flag: flag)
        let network = makeNetwork(client: IntegMockClient(result: .success(())))
        network.addInterceptor(interceptor)
        _ = try await network.request()
        let wasExecuted = await flag.value()
        #expect(wasExecuted == true)
    }

    // MARK: - request() 客户端抛错透传

    @Test
    func requestPropagatesClientError() async throws {
        let network = NtkNetwork<Bool>.with(
            IntegMockClient(result: .failure(NtkError.requestTimeout)),
            request: IntegDummyRequest(path: "/integration/error-test"),
            dataParsingInterceptor: IntegMockParsingInterceptor(),
            validation: IntegDummyValidation()
        )
        do {
            _ = try await network.request()
            Issue.record("期望抛出错误")
        } catch {
            #expect(error is NtkError)
        }
    }

    // MARK: - requestWithCache() 无缓存只有网络结果

    @Test
    func requestWithCacheReturnsOnlyNetworkWhenNoCache() async throws {
        let cacheStorage = IntegMockCacheStorage(cacheData: nil)
        let network = makeNetwork(
            client: IntegMockClient(result: .success(())),
            cacheStorage: cacheStorage
        )
        var results: [NtkResponse<Bool>] = []
        for try await response in network.requestWithCache() {
            results.append(response)
        }
        #expect(results.count == 1)
        #expect(results[0].isCache == false)
    }

    // MARK: - requestWithCache() 缓存和网络都返回

    @Test
    func requestWithCacheReturnsBothCacheAndNetwork() async throws {
        let cacheStorage = IntegMockCacheStorage(cacheData: true)
        let network = makeNetwork(
            client: IntegMockClient(result: .success(()), delay: 0.1),
            cacheStorage: cacheStorage
        )
        var results: [NtkResponse<Bool>] = []
        for try await response in network.requestWithCache() {
            results.append(response)
        }
        // 缓存先返回，网络后返回
        #expect(results.count == 2)
        #expect(results[0].isCache == true)
        #expect(results[1].isCache == false)
    }

    // MARK: - cancel() 传播

    @Test
    func cancelSetsIsCancelledFlag() async throws {
        let network = makeNetwork(client: IntegMockClient(result: .success(())))
        #expect(network.isCancelled == false)
        await network.cancel()
        #expect(network.isCancelled == true)
    }

    // MARK: - 单次使用保护

    @Test
    func secondRequestThrows() async throws {
        let network = makeNetwork(client: IntegMockClient(result: .success(())))
        _ = try await network.request()
        do {
            _ = try await network.request()
            Issue.record("期望第二次 request 被阻止")
        } catch let error as NtkError {
            if case .requestCancelled = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }
}

// MARK: - Factory

private func makeNetwork(
    client: IntegMockClient,
    cacheStorage: IntegMockCacheStorage? = nil
) -> NtkNetwork<Bool> {
    NtkNetwork<Bool>.with(
        client,
        cacheStorage: cacheStorage,
        request: IntegDummyRequest(),
        dataParsingInterceptor: IntegMockParsingInterceptor(),
        validation: IntegDummyValidation()
    )
}

// MARK: - Test Doubles

private struct IntegDummyRequest: iNtkRequest {
    var path: String
    init(path: String = "/integration/test") {
        self.path = path
    }
}

private struct IntegDummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct IntegMockClient: iNtkClient {
    let result: Result<Void, Error>
    let delay: TimeInterval

    init(result: Result<Void, Error>, delay: TimeInterval = 0) {
        self.result = result
        self.delay = delay
    }

    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        switch result {
        case .success:
            return NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
        case .failure(let error):
            throw error
        }
    }
}

private struct IntegMockCacheStorage: iNtkCacheStorage {
    let cacheData: (any Sendable)?

    @NtkActor func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool { false }
    @NtkActor func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        guard let cacheData else { return nil }
        return NtkCacheMeta(
            appVersion: "1.0",
            creationDate: Date().timeIntervalSince1970,
            expirationDate: Date().timeIntervalSince1970 + 3600,
            data: cacheData
        )
    }
    @NtkActor func hasData(key: String, for request: NtkMutableRequest) async -> Bool { cacheData != nil }
}

@NtkActor
private struct IntegMockParsingInterceptor: iNtkInterceptor {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        if let typed = response as? NtkResponse<Bool> { return typed }
        return NtkResponse<Bool>(
            code: response.code,
            data: true,
            msg: response.msg,
            response: response.response,
            request: response.request,
            isCache: response.isCache
        )
    }
}

private actor IntegAtomicFlag {
    private var _value = false
    func set() { _value = true }
    func value() -> Bool { _value }
}

@NtkActor
private struct IntegFlagInterceptor: iNtkInterceptor {
    let flag: IntegAtomicFlag

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await flag.set()
        return try await next.handle(context: context)
    }
}
