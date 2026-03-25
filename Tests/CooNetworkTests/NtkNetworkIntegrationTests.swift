import Testing
import Foundation
@testable import CooNetwork

struct NtkNetworkIntegrationTests {

    // MARK: - request() 完整成功流程

    @Test
    func requestReturnsSuccessResponse() async throws {
        let network = makeNetwork(client: IntegMockClient(result: .success(())), path: "/integration/success")
        let response = try await network.request()
        #expect(response.data == true)
        #expect(response.isCache == false)
    }

    @Test
    func requestWithRealParserReturnsDecodedBoolResponse() async throws {
        let client = IntegJSONClient(data: try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ]))

        let network = NtkNetwork<Bool>.with(
            client,
            request: IntegDummyRequest(path: "/integration/real-parser"),
            responseParser: NtkDataParsingInterceptor<Bool, IntegTestKeys>(validation: IntegDummyValidation())
        )

        let response = try await network.request()
        #expect(response.data == true)
    }

    @Test
    func requestWithRealParserAndThrowingHookReturnsDecodedBoolResponse() async throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ])
        let baselineNetwork = NtkNetwork<Bool>.with(
            IntegJSONClient(data: payload),
            request: IntegDummyRequest(path: "/integration/real-parser-baseline"),
            responseParser: NtkDataParsingInterceptor<Bool, IntegTestKeys>(validation: IntegDummyValidation())
        )
        let hook = IntegThrowingHook()
        let hookedNetwork = NtkNetwork<Bool>.with(
            IntegJSONClient(data: payload),
            request: IntegDummyRequest(path: "/integration/real-parser-hook"),
            responseParser: NtkDataParsingInterceptor<Bool, IntegTestKeys>(
                validation: IntegDummyValidation(),
                hooks: [hook]
            )
        )

        let baselineResponse = try await baselineNetwork.request()
        let hookedResponse = try await hookedNetwork.request()
        #expect(hookedResponse.data == baselineResponse.data)
        #expect(hookedResponse.code.intValue == baselineResponse.code.intValue)
        #expect(hookedResponse.code.stringValue == baselineResponse.code.stringValue)
        #expect(hookedResponse.msg == baselineResponse.msg)
        #expect(hookedResponse.isCache == baselineResponse.isCache)
        #expect(hookedResponse.msg == "ok")
        #expect(hook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    @Test
    func customParserWithoutValidationRequirementStillWorks() async throws {
        let network = NtkNetwork<Bool>.with(
            IntegJSONClient(data: try JSONSerialization.data(withJSONObject: [
                "retCode": 0,
                "data": true,
                "retMsg": "ok"
            ])),
            request: IntegDummyRequest(path: "/integration/custom-parser-no-validation"),
            responseParser: IntegNoValidationParsingInterceptor()
        )

        let response = try await network.request()
        #expect(response.data == true)
    }

    // MARK: - request() 自定义拦截器被执行

    @Test
    func requestExecutesCustomInterceptor() async throws {
        let flag = IntegAtomicFlag()
        let interceptor = IntegFlagInterceptor(flag: flag)
        let network = makeNetwork(client: IntegMockClient(result: .success(())), path: "/integration/custom-interceptor")
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
            responseParser: IntegMockParsingInterceptor()
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
            cacheStorage: cacheStorage,
            path: "/integration/cache-miss"
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
            cacheStorage: cacheStorage,
            path: "/integration/cache-hit"
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
        let network = makeNetwork(client: IntegMockClient(result: .success(())), path: "/integration/cancel")
        #expect(network.isCancelled == false)
        await network.cancel()
        #expect(network.isCancelled == true)
    }

    // MARK: - 单次使用保护

    @Test
    func networkInstanceShouldCompleteFirstRequest() async throws {
        let network = makeNetwork(client: IntegMockClient(result: .success(())), path: "/integration/single-use")
        let response = try await network.request()
        #expect(response.data == true)
    }
}

// MARK: - Factory

private func makeNetwork(
    client: IntegMockClient,
    cacheStorage: IntegMockCacheStorage? = nil,
    path: String = "/integration/test"
) -> NtkNetwork<Bool> {
    var interceptors: [iNtkInterceptor] = []
    if let cacheStorage {
        interceptors.append(NtkCacheInterceptor(storage: cacheStorage))
    }
    return NtkNetwork<Bool>.with(
        client,
        request: IntegDummyRequest(path: path),
        responseParser: IntegMockParsingInterceptor(),
        interceptors: interceptors
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

private struct IntegTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
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

private struct IntegJSONClient: iNtkClient {
    let data: Data

    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: data, msg: nil, response: data, request: request, isCache: false)
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

private final class IntegThrowingHook: iNtkParsingHooks, @unchecked Sendable {
    var events: [String] = []

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {
        events.append("didDecodeHeader")
        throw IntegHookObserverError.point("didDecodeHeader")
    }

    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("willValidate")
        throw IntegHookObserverError.point("willValidate")
    }

    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didComplete")
        throw IntegHookObserverError.point("didComplete")
    }
}

private enum IntegHookObserverError: Error, Equatable {
    case point(String)
}

@NtkActor
private struct IntegMockParsingInterceptor: iNtkResponseParser {
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

@NtkActor
private struct IntegNoValidationParsingInterceptor: iNtkResponseParser {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
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
