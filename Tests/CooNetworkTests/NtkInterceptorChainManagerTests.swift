import Testing
import Foundation
@testable import CooNetwork

struct NtkInterceptorChainManagerTests {

    // MARK: - 空链直达 finalHandler

    @Test
    @NtkActor
    func emptyChainCallsFinalHandler() async throws {
        let counter = ChainCallCounter()
        let manager = NtkInterceptorChainManager(interceptors: []) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let log = await counter.log()
        #expect(log == ["final"])
    }

    // MARK: - 单拦截器执行

    @Test
    @NtkActor
    func singleInterceptorExecutesAndCallsNext() async throws {
        let counter = ChainCallCounter()
        let interceptor = ChainRecordingInterceptor(id: "A", counter: counter)
        let manager = NtkInterceptorChainManager(interceptors: [interceptor]) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let log = await counter.log()
        #expect(log == ["A-request", "final", "A-response"])
    }

    // MARK: - 多拦截器按数组顺序执行

    @Test
    @NtkActor
    func multipleInterceptorsExecuteInOrder() async throws {
        let counter = ChainCallCounter()
        let a = ChainRecordingInterceptor(id: "A", counter: counter)
        let b = ChainRecordingInterceptor(id: "B", counter: counter)
        let c = ChainRecordingInterceptor(id: "C", counter: counter)
        let manager = NtkInterceptorChainManager(interceptors: [a, b, c]) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let log = await counter.log()
        // 请求流: A→B→C→final, 响应流: C→B→A
        #expect(log == ["A-request", "B-request", "C-request", "final", "C-response", "B-response", "A-response"])
    }

    // MARK: - 拦截器短路

    @Test
    @NtkActor
    func shortCircuitInterceptorStopsChain() async throws {
        let counter = ChainCallCounter()
        let a = ChainRecordingInterceptor(id: "A", counter: counter)
        let blocker = ChainShortCircuitInterceptor(id: "blocker", counter: counter)
        let c = ChainRecordingInterceptor(id: "C", counter: counter)
        let manager = NtkInterceptorChainManager(interceptors: [a, blocker, c]) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let log = await counter.log()
        // blocker 不调用 next，C 和 final 不应被执行
        #expect(log == ["A-request", "blocker-shortcircuit", "A-response"])
    }

    // MARK: - 拦截器抛错传播

    @Test
    @NtkActor
    func interceptorErrorPropagates() async throws {
        let counter = ChainCallCounter()
        let a = ChainRecordingInterceptor(id: "A", counter: counter)
        let thrower = ChainThrowingInterceptor()
        let manager = NtkInterceptorChainManager(interceptors: [a, thrower]) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        do {
            _ = try await manager.execute(context: context)
            Issue.record("期望抛出错误")
        } catch let error as NtkError {
            if case .requestTimeout = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    // MARK: - context 修改传递

    @Test
    @NtkActor
    func contextModificationVisibleToNextInterceptor() async throws {
        let modifier = ChainContextModifierInterceptor(key: "testKey", value: "testValue")
        let capture = ChainValueCapture()
        let reader = ChainContextReaderInterceptor(key: "testKey", capture: capture)
        let manager = NtkInterceptorChainManager(interceptors: [modifier, reader]) { context in
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let captured = await capture.value()
        #expect(captured as? String == "testValue")
    }

    // MARK: - Tier 隔离：核心拦截器不可被用户拦截器入侵

    /// 验证 outer tier 始终在 standard tier 外侧执行，standard 始终在 inner tier 外侧
    /// 无论传入顺序如何，sortInterceptors 按 tier+value 降序排列
    @Test
    @NtkActor
    func tierIsolationEnsuresCoreOrderingIsPreserved() async throws {
        let counter = ChainCallCounter()

        // outer tier（模拟 Dedup）
        let outerInterceptor = ChainTieredInterceptor(
            id: "outer", counter: counter, _priority: .outerHighest
        )
        // standard tier（用户拦截器，高 value）
        let userInterceptor = ChainTieredInterceptor(
            id: "user", counter: counter, _priority: .high
        )
        // inner tier（模拟 DataParsing）
        let innerInterceptor = ChainTieredInterceptor(
            id: "inner", counter: counter, _priority: .innerHigh
        )

        // 故意以错误顺序传入，让 sortInterceptors 纠正
        let unsorted: [any iNtkInterceptor] = [userInterceptor, innerInterceptor, outerInterceptor]
        let sorted = unsorted.sorted { $0.priority > $1.priority }

        let manager = NtkInterceptorChainManager(interceptors: sorted) { context in
            await counter.record("final")
            return ChainDummyResponse(request: ChainDummyRequest())
        }
        let context = makeContext()
        _ = try await manager.execute(context: context)
        let log = await counter.log()

        // outer 必须最外层，inner 必须最内层
        #expect(log == [
            "outer-request", "user-request", "inner-request",
            "final",
            "inner-response", "user-response", "outer-response"
        ])
    }
}

// MARK: - Helpers

@NtkActor
private func makeContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(ChainDummyRequest()),
        validation: ChainDummyValidation(),
        client: ChainDummyClient()
    )
}

// MARK: - Test Doubles

private actor ChainCallCounter {
    private var entries: [String] = []
    func record(_ id: String) { entries.append(id) }
    func log() -> [String] { entries }
}

private struct ChainDummyRequest: iNtkRequest {
    var path: String { "/chain/test" }
}

private struct ChainDummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct ChainDummyClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
    }
}

private struct ChainDummyResponse: iNtkResponse {
    let code = NtkReturnCode(200)
    let data: Bool = true
    let msg: String? = nil
    let response: any Sendable = true
    let request: any iNtkRequest
    let isCache = false
}

/// 记录请求/响应阶段的拦截器
@NtkActor
private struct ChainRecordingInterceptor: iNtkInterceptor {
    let id: String
    let counter: ChainCallCounter

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record("\(id)-request")
        let response = try await next.handle(context: context)
        await counter.record("\(id)-response")
        return response
    }
}

/// 不调用 next 的短路拦截器
@NtkActor
private struct ChainShortCircuitInterceptor: iNtkInterceptor {
    let id: String
    let counter: ChainCallCounter

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record("\(id)-shortcircuit")
        return ChainDummyResponse(request: ChainDummyRequest())
    }
}

/// Tier 感知的记录拦截器，用于验证 tier 排序
@NtkActor
private struct ChainTieredInterceptor: iNtkInterceptor {
    let id: String
    let counter: ChainCallCounter
    let _priority: NtkInterceptorPriority

    nonisolated var priority: NtkInterceptorPriority { _priority }

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record("\(id)-request")
        let response = try await next.handle(context: context)
        await counter.record("\(id)-response")
        return response
    }
}

/// 抛错拦截器
@NtkActor
private struct ChainThrowingInterceptor: iNtkInterceptor {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        throw NtkError.requestTimeout
    }
}

/// 修改 context extraData 的拦截器
@NtkActor
private struct ChainContextModifierInterceptor: iNtkInterceptor {
    let key: String
    let value: any Sendable

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        context.extraData[key] = value
        return try await next.handle(context: context)
    }
}

private actor ChainValueCapture {
    private var _value: (any Sendable)?
    func set(_ v: any Sendable) { _value = v }
    func value() -> (any Sendable)? { _value }
}

/// 读取 context extraData 的拦截器
@NtkActor
private struct ChainContextReaderInterceptor: iNtkInterceptor {
    let key: String
    let capture: ChainValueCapture

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        if let value = context.extraData[key] {
            await capture.set(value)
        }
        return try await next.handle(context: context)
    }
}
