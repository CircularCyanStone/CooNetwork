import Testing
import Foundation
@testable import CooNetwork

struct NtkRetryInterceptorTests {
    @Test
    @NtkActor
    func zeroRetryShouldThrowTypedErrorInsteadOfCrash() async {
        let interceptor = NtkRetryInterceptor(retryPolicy: ZeroRetryPolicy())
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            client: DummyClient()
        )
        
        do {
            _ = try await interceptor.intercept(context: context, next: AlwaysFailHandler())
            Issue.record("期望抛出错误，但实际未抛出")
        } catch let error as NtkError {
            if case NtkError.requestTimeout = error {
                #expect(Bool(true))
            } else {
                Issue.record("抛出了错误类型，但不是 requestTimeout: \(error)")
            }
        } catch {
            Issue.record("抛出了未知错误类型: \(error)")
        }
    }
    /// maxRetryCount=3 时应重试 3 次（总共执行 4 次）
    @Test
    @NtkActor
    func retryCountMatchesMaxRetryCount() async throws {
        let counter = RetryExecutionCounter()
        let interceptor = NtkRetryInterceptor(
            retryPolicy: CountingRetryPolicy(maxRetryCount: 3))
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            client: DummyClient()
        )

        do {
            _ = try await interceptor.intercept(
                context: context,
                next: CountingFailHandler(counter: counter))
            Issue.record("期望抛出错误")
        } catch {
            let count = await counter.value()
            // 首次执行 1 + 重试 3 = 总共 4 次
            #expect(count == 4)
        }
    }

    /// maxRetryCount=1 时应重试 1 次（总共执行 2 次）
    @Test
    @NtkActor
    func singleRetryShouldExecuteTwice() async throws {
        let counter = RetryExecutionCounter()
        let interceptor = NtkRetryInterceptor(
            retryPolicy: CountingRetryPolicy(maxRetryCount: 1))
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            client: DummyClient()
        )

        do {
            _ = try await interceptor.intercept(
                context: context,
                next: CountingFailHandler(counter: counter))
            Issue.record("期望抛出错误")
        } catch {
            let count = await counter.value()
            #expect(count == 2)
        }
    }

    /// 首次成功时不应重试
    @Test
    @NtkActor
    func firstSuccessShouldNotRetry() async throws {
        let counter = RetryExecutionCounter()
        let interceptor = NtkRetryInterceptor(
            retryPolicy: CountingRetryPolicy(maxRetryCount: 3))
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            client: DummyClient()
        )

        let response = try await interceptor.intercept(
            context: context,
            next: CountingSuccessHandler(counter: counter, request: DummyRequest()))

        let count = await counter.value()
        #expect(count == 1)
        #expect(response is NtkResponse<Bool>)
    }

    /// 第 2 次重试成功时应停止
    @Test
    @NtkActor
    func retrySuccessOnSecondRetryShouldStop() async throws {
        let counter = RetryExecutionCounter()
        let interceptor = NtkRetryInterceptor(
            retryPolicy: CountingRetryPolicy(maxRetryCount: 5))
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            client: DummyClient()
        )

        // 前 2 次失败（首次 + 第 1 次重试），第 3 次成功（第 2 次重试）
        let response = try await interceptor.intercept(
            context: context,
            next: FailNTimesThenSucceedHandler(
                failCount: 2, counter: counter, request: DummyRequest()))

        let count = await counter.value()
        #expect(count == 3)
        #expect(response is NtkResponse<Bool>)
    }
}

// MARK: - Test Helpers

private actor RetryExecutionCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
}

/// 始终允许重试的策略（无延迟），用于计数验证
private struct CountingRetryPolicy: iNtkRetryPolicy {
    let maxRetryCount: Int

    func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval? {
        0
    }

    func shouldRetry(attemptCount: Int, error: Error) -> Bool {
        attemptCount <= maxRetryCount
    }
}

@NtkActor
private struct CountingFailHandler: iNtkRequestHandler {
    let counter: RetryExecutionCounter
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        await counter.increment()
        throw NtkError.requestTimeout
    }
}

@NtkActor
private struct CountingSuccessHandler: iNtkRequestHandler {
    let counter: RetryExecutionCounter
    let request: iNtkRequest
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        await counter.increment()
        return NtkResponse(code: NtkReturnCode(200), data: true, msg: nil, response: true, request: request, isCache: false)
    }
}

@NtkActor
private struct FailNTimesThenSucceedHandler: iNtkRequestHandler {
    let failCount: Int
    let counter: RetryExecutionCounter
    let request: iNtkRequest
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        await counter.increment()
        let current = await counter.value()
        if current <= failCount {
            throw NtkError.requestTimeout
        }
        return NtkResponse(code: NtkReturnCode(200), data: true, msg: nil, response: true, request: request, isCache: false)
    }
}

private struct ZeroRetryPolicy: iNtkRetryPolicy {
    let maxRetryCount: Int = 0
    
    func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval? {
        nil
    }
    
    func shouldRetry(attemptCount: Int, error: Error) -> Bool {
        false
    }
}

private struct DummyRequest: iNtkRequest {
    var path: String { "/retry/test" }
}

private struct DummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        true
    }
}

private struct DummyKeys: iNtkResponseMapKeys {
    static let code: String = "code"
    static let data: String = "data"
    static let msg: String = "msg"
}

private struct DummyClient: iNtkClient {
    typealias Keys = DummyKeys

    var storage: any iNtkCacheStorage {
        DummyCacheStorage()
    }

    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        throw NtkError.requestTimeout
    }
    
    @NtkActor
    func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse? {
        nil
    }
    
    @NtkActor
    func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool {
        false
    }
    
    @NtkActor
    func hasCacheData(_ request: NtkMutableRequest) async -> NtkResponse<Bool> {
        NtkResponse(
            code: NtkReturnCode(200),
            data: false,
            msg: nil,
            response: false,
            request: request,
            isCache: true
        )
    }
}

private struct DummyCacheStorage: iNtkCacheStorage {
    @NtkActor
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }
    
    @NtkActor
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        nil
    }
    
    @NtkActor
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }
}

@NtkActor
private struct AlwaysFailHandler: iNtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.requestTimeout
    }
}
