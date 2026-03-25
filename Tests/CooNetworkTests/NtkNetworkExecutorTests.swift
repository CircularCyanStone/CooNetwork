import Testing
import Foundation
@testable import CooNetwork

struct NtkNetworkExecutorTests {

    // MARK: - execute() 成功

    @Test
    @NtkActor
    func executeReturnsResponseOnSuccess() async throws {
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.execute()
        #expect(response.data == true)
        #expect(response.isCache == false)
    }

    // MARK: - execute() 客户端抛错透传

    @Test
    @NtkActor
    func executePropagatesclientError() async throws {
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/error-test"))
        request.responseType = String(describing: Bool.self)
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .failure(NtkError.requestTimeout)),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)
        do {
            _ = try await executor.execute()
            Issue.record("期望抛出错误")
        } catch {
            #expect(error is NtkError)
        }
    }

    // MARK: - execute() 拦截器按优先级排序

    @Test
    @NtkActor
    func executeSortsAllInterceptorsByPriority() async throws {
        let counter = ExecCallCounter()
        let lowPriority = ExecPriorityRecordingInterceptor(id: "low", prio: .low, counter: counter)
        let highPriority = ExecPriorityRecordingInterceptor(id: "high", prio: .high, counter: counter)

        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/priority-order"))
        request.responseType = String(describing: Bool.self)
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor()), lowPriority, highPriority]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)
        _ = try await executor.execute()
        let log = await counter.log()
        // high 优先级先执行
        #expect(log.first == "high")
    }

    // MARK: - loadCache() 有缓存

    @Test
    @NtkActor
    func loadCacheReturnsCachedResponse() async throws {
        let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: false)
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response != nil)
        #expect(response?.isCache == true)
    }

    @Test
    @NtkActor
    func loadCacheWithRealParserStillReturnsTypedCachedResponse() async throws {
        let storage = ExecMockCacheStorage(
            cacheData: try JSONSerialization.data(withJSONObject: [
                "retCode": 0,
                "data": true,
                "retMsg": "ok"
            ]),
            hasCacheResult: false
        )

        var request = NtkMutableRequest(ExecDummyRequest())
        request.responseType = String(describing: Bool.self)

        let parser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(validation: ExecDummyValidation())
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(parser), NtkCacheInterceptor(storage: storage)]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.loadCache()
        #expect(response?.data == true)
        #expect(response?.isCache == true)
    }

    @Test
    @NtkActor
    func loadCacheWithRealParserAndThrowingHookStillReturnsTypedCachedResponse() async throws {
        let cachePayload = try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ])
        let baselineStorage = ExecMockCacheStorage(cacheData: cachePayload, hasCacheResult: false)
        let hookedStorage = ExecMockCacheStorage(cacheData: cachePayload, hasCacheResult: false)
        let hook = ExecThrowingHook()

        var baselineRequest = NtkMutableRequest(ExecDummyRequest(path: "/executor/cache-baseline"))
        baselineRequest.responseType = String(describing: Bool.self)
        let baselineParser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(validation: ExecDummyValidation())
        let baselineConfig = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: baselineRequest,
            interceptors: [NtkResponseParserBox(baselineParser), NtkCacheInterceptor(storage: baselineStorage)]
        )
        let baselineExecutor = NtkNetworkExecutor<Bool>(config: baselineConfig)

        var hookedRequest = NtkMutableRequest(ExecDummyRequest(path: "/executor/cache-hook"))
        hookedRequest.responseType = String(describing: Bool.self)
        let hookedParser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(
            validation: ExecDummyValidation(),
            hooks: [hook]
        )
        let hookedConfig = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: hookedRequest,
            interceptors: [NtkResponseParserBox(hookedParser), NtkCacheInterceptor(storage: hookedStorage)]
        )
        let hookedExecutor = NtkNetworkExecutor<Bool>(config: hookedConfig)

        let baselineResponse = try #require(await baselineExecutor.loadCache())
        let hookedResponse = try #require(await hookedExecutor.loadCache())
        #expect(hookedResponse.data == baselineResponse.data)
        #expect(hookedResponse.code.intValue == baselineResponse.code.intValue)
        #expect(hookedResponse.code.stringValue == baselineResponse.code.stringValue)
        #expect(hookedResponse.msg == baselineResponse.msg)
        #expect(hookedResponse.isCache == baselineResponse.isCache)
        #expect(hookedResponse.msg == "ok")
        #expect(hook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    // MARK: - loadCache() 无缓存返回 nil

    @Test
    @NtkActor
    func loadCacheReturnsNilWhenNoCache() async throws {
        let storage = ExecMockCacheStorage(cacheData: nil, hasCacheResult: false)
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response == nil)
    }

    // MARK: - loadCache() 无 cacheStorage 返回 nil

    @Test
    @NtkActor
    func loadCacheReturnsNilWithoutCacheStorage() async throws {
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response == nil)
    }

    // MARK: - hasCacheData()

    @Test
    @NtkActor
    func hasCacheDataReturnsTrueWhenCacheExists() async throws {
        let storage = ExecMockCacheStorage(cacheData: nil, hasCacheResult: true)
        let executor = makeBoolExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage)
        )
        let result = await executor.hasCacheData()
        #expect(result == true)
    }

    @Test
    @NtkActor
    func hasCacheDataReturnsFalseWithoutCacheStorage() async throws {
        let executor = makeBoolExecutor(
            client: ExecMockClient(result: .success(()))
        )
        let result = await executor.hasCacheData()
        #expect(result == false)
    }
}

// MARK: - Factory Helpers

@NtkActor
private func makeExecutor(
    client: ExecMockClient,
    cacheInterceptor: NtkCacheInterceptor? = nil,
    parsingInterceptor: any iNtkResponseParser
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)
    var interceptors: [iNtkInterceptor] = [NtkResponseParserBox(parsingInterceptor)]
    if let cacheInterceptor { interceptors.append(cacheInterceptor) }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

@NtkActor
private func makeBoolExecutor(
    client: ExecMockClient,
    cacheInterceptor: NtkCacheInterceptor? = nil
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)
    var interceptors: [iNtkInterceptor] = [NtkResponseParserBox(ExecMockParsingInterceptor())]
    if let cacheInterceptor { interceptors.append(cacheInterceptor) }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

@NtkActor
private func makeCacheClientResponse() -> NtkClientResponse {
    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)
    return NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: true)
}

// MARK: - Test Doubles

private struct ExecDummyRequest: iNtkRequest {
    var path: String
    init(path: String = "/executor/test") {
        self.path = path
    }
}

private struct ExecDummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct ExecTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
}

private struct ExecMockClient: iNtkClient {
    let result: Result<Void, Error>

    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        switch result {
        case .success:
            return NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
        case .failure(let error):
            throw error
        }
    }
}

private struct ExecMockCacheStorage: iNtkCacheStorage {
    let cacheData: (any Sendable)?
    let hasCacheResult: Bool

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
    @NtkActor func hasData(key: String, for request: NtkMutableRequest) async -> Bool { hasCacheResult }
}

private final class ExecThrowingHook: iNtkParsingHooks, @unchecked Sendable {
    var events: [String] = []

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {
        events.append("didDecodeHeader")
        throw ExecHookObserverError.point("didDecodeHeader")
    }

    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("willValidate")
        throw ExecHookObserverError.point("willValidate")
    }

    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didComplete")
        throw ExecHookObserverError.point("didComplete")
    }
}

private enum ExecHookObserverError: Error, Equatable {
    case point(String)
}

/// 将 NtkClientResponse 转为 NtkResponse<Bool> 的 mock 解析拦截器
@NtkActor
private struct ExecMockParsingInterceptor: iNtkResponseParser {
    let validation: iNtkResponseValidation = ExecDummyValidation()

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

/// 记录执行顺序的拦截器
private struct ExecPriorityRecordingInterceptor: iNtkInterceptor {
    let id: String
    let prio: NtkInterceptorPriority
    let counter: ExecCallCounter

    nonisolated var priority: NtkInterceptorPriority { prio }

    @NtkActor
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record(id)
        return try await next.handle(context: context)
    }
}

private actor ExecCallCounter {
    private var entries: [String] = []
    func record(_ id: String) { entries.append(id) }
    func log() -> [String] { entries }
}
