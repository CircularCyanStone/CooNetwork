# Ntk Request Modifying Interceptor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 引入显式的 `iNtkRequestModifyingInterceptor` 能力协议，使网络执行与缓存读取从同一初始快照独立构建请求，同时保证普通 interceptor 无法进入请求修改阶段。

**Architecture:** `NtkNetwork` 继续只保存一个 interceptor 注册列表并缓存一个 executor。executor 使用统一、稳定的排序器筛选请求修改拦截器，在创建只读 `NtkInterceptorContext` 前完成值式请求转换；`execute()`、`loadCache()`、`hasCacheData()` 各自持有局部请求，缓存路径不执行完整拦截链。

**Tech Stack:** Swift 6.1、Swift Package Manager、Swift Testing、`@NtkActor`

**Approved design:** `docs/ntk-request-modification-design.md`

**Working tree note:** 当前仓库已有相关中间改动和其他暂存内容。执行时必须保留这些改动，按任务列出的精确路径检查并提交，禁止使用 reset、checkout 或 clean 清理工作区。

---

## File map

- Create `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift`: 请求修改能力协议及默认 `intercept` 透传。
- Create `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorOrdering.swift`: priority 降序、同 priority 注册顺序稳定的统一排序。
- Modify `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift`: 基础协议只保留 priority 和普通拦截职责。
- Modify `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`: 只筛选能力子协议并使用统一稳定排序。
- Modify `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`: 文档明确 context 请求只读。
- Modify `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift`: 文档指向唯一修改协议。
- Modify `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`: 能力筛选、动作隔离、错误、缓存副作用和缓存身份测试。
- Modify `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`: 稳定排序契约测试。
- Modify `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`: `addInterceptor`、默认透传、`requestWithCache` 和非消费缓存操作测试。
- Modify `README.md`: 展示只读普通 interceptor 与请求修改 interceptor 的正确用法。
- Modify `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`, `docs/architecture.md`, `docs/design-decisions.md`, `docs/ntk-actor-audit.md`: 同步最终协议和生命周期术语。

`NtkNetwork.markRequestConsumed()`、`loadCache()` 和 `hasCacheData()` 的消费逻辑不在本计划中修改。

### Task 1: 建立显式请求修改能力

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift:128-176`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift:45-59`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 写入普通 interceptor 的能力隔离失败测试**

在 `NtkNetworkExecutorTests` 中加入：

```swift
@Test
@NtkActor
func executeDoesNotTreatOrdinaryInterceptorAsRequestModifier() async throws {
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/lookalike-modifier"))
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecLookalikeRequestInterceptor()
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    let response = try await executor.execute()

    #expect(response.request.headers?["X-Lookalike-Modifier"] == nil)
}
```

在测试替身区域加入一个“方法签名相同但未声明能力”的普通 interceptor：

```swift
private struct ExecLookalikeRequestInterceptor: iNtkInterceptor {
    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-Lookalike-Modifier", value: "unexpected")
        return request
    }

    @NtkActor
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}
```

- [ ] **Step 2: 运行测试确认当前基础协议会错误调用该方法**

Run:

```bash
swift test --filter NtkNetworkExecutorTests.executeDoesNotTreatOrdinaryInterceptorAsRequestModifier
```

Expected: FAIL；响应请求包含 `X-Lookalike-Modifier=unexpected`。

- [ ] **Step 3: 新增请求修改能力协议**

创建 `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift`：

```swift
//
//  iNtkRequestModifyingInterceptor.swift
//  CooNetwork
//

import Foundation

/// 明确参与请求构建阶段的拦截器。
///
/// `modifyRequest(_:)` 是改变请求结构的唯一入口。完成请求构建后，
/// 普通拦截阶段只能读取 `NtkInterceptorContext.request`。
public protocol iNtkRequestModifyingInterceptor: iNtkInterceptor {
    @NtkActor
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest
}

extension iNtkRequestModifyingInterceptor {
    /// 纯请求修改拦截器默认不处理响应链。
    @NtkActor
    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}
```

- [ ] **Step 4: 从基础 interceptor 协议删除请求修改职责**

把 `iNtkInterceptor` 的协议与扩展收敛为：

```swift
/// 网络拦截器协议。
///
/// 普通拦截阶段可以短路、重试、读取请求或处理响应，
/// 但不能修改 `NtkInterceptorContext.request`。
public protocol iNtkInterceptor: Sendable {
    var priority: NtkInterceptorPriority { get }

    @NtkActor
    func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse
}

extension iNtkInterceptor {
    public var priority: NtkInterceptorPriority {
        .medium
    }
}
```

不得在该扩展中保留默认 `modifyRequest`。

- [ ] **Step 5: executor 只调用显式能力子协议**

把 `NtkNetworkExecutor.makeRequest()` 改为：

```swift
/// 从初始请求快照构建本次动作的局部请求。
private func makeRequest() async throws -> NtkMutableRequest {
    var request = initialRequest
    let modifiers = sortInterceptors(config.interceptors).compactMap {
        $0 as? any iNtkRequestModifyingInterceptor
    }
    for modifier in modifiers {
        request = try await modifier.modifyRequest(request)
    }
    return request
}
```

- [ ] **Step 6: 迁移现有 executor 测试修改器并验证默认透传**

将以下三个测试替身的协议改为 `iNtkRequestModifyingInterceptor`，并删除它们显式的 `intercept` 方法：

```swift
private struct ExecIncrementingRequestInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        let previousValue = Int(request.headers?["X-Execution-Count"] ?? "") ?? 0
        request.addHeader(key: "X-Execution-Count", value: String(previousValue + 1))
        return request
    }
}

private struct ExecStableRequestInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-Stable-Parameter", value: "stable")
        return request
    }
}

private struct ExecAppendingRequestInterceptor: iNtkRequestModifyingInterceptor {
    let id: String
    let prio: NtkInterceptorPriority

    nonisolated var priority: NtkInterceptorPriority { prio }

    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        let existing = request.headers?["X-Modifier-Order"]
        let value = [existing, id].compactMap { $0 }.joined(separator: ",")
        request.addHeader(key: "X-Modifier-Order", value: value)
        return request
    }
}
```

再加入一个同时参与两个阶段的测试：

```swift
@Test
@NtkActor
func executeAllowsRequestModifierToAlsoInterceptResponse() async throws {
    let counter = ExecCallCounter()
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/combined-modifier"))
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecCombinedRequestInterceptor(counter: counter)
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    let response = try await executor.execute()

    #expect(response.request.headers?["X-Combined"] == "modified")
    #expect(await counter.log() == ["intercept"])
}
```

加入对应测试替身：

```swift
private struct ExecCombinedRequestInterceptor: iNtkRequestModifyingInterceptor {
    let counter: ExecCallCounter

    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-Combined", value: "modified")
        return request
    }

    @NtkActor
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        await counter.record("intercept")
        return response
    }
}
```

- [ ] **Step 7: 运行 executor 测试**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
```

Expected: PASS；普通 lookalike interceptor 不修改请求，显式修改器仍在 execute/loadCache/hasCacheData 中生效。

- [ ] **Step 8: 提交能力协议**

```bash
git add Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit --only -m "feat: add explicit request modifying interceptor" -- Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
```

### Task 2: 明确同 priority 的稳定注册顺序

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorOrdering.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift:43-96`
- Test: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift:122-163`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 添加统一排序器的失败测试**

在 `NtkInterceptorChainManagerTests` 中加入：

```swift
@Test
@NtkActor
func equalPriorityInterceptorsKeepRegistrationOrder() {
    let counter = ChainCallCounter()
    let first = ChainTieredInterceptor(id: "first", counter: counter, _priority: .medium)
    let second = ChainTieredInterceptor(id: "second", counter: counter, _priority: .medium)
    let third = ChainTieredInterceptor(id: "third", counter: counter, _priority: .medium)

    let sorted = NtkInterceptorOrdering.sorted([first, second, third])
    let ids = sorted.compactMap { ($0 as? ChainTieredInterceptor)?.id }

    #expect(ids == ["first", "second", "third"])
}
```

同时把 `tierIsolationEnsuresCoreOrderingIsPreserved()` 中的排序语句改为：

```swift
let unsorted: [any iNtkInterceptor] = [userInterceptor, innerInterceptor, outerInterceptor]
let sorted = NtkInterceptorOrdering.sorted(unsorted)
```

- [ ] **Step 2: 运行测试确认排序器尚不存在**

Run:

```bash
swift test --filter NtkInterceptorChainManagerTests
```

Expected: 编译失败，提示找不到 `NtkInterceptorOrdering`。

- [ ] **Step 3: 实现显式稳定排序**

创建 `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorOrdering.swift`：

```swift
//
//  NtkInterceptorOrdering.swift
//  CooNetwork
//

import Foundation

/// 统一定义 interceptor 的请求流顺序。
enum NtkInterceptorOrdering {
    static func sorted(
        _ interceptors: [iNtkInterceptor]
    ) -> [iNtkInterceptor] {
        interceptors.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority == rhs.element.priority {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.priority > rhs.element.priority
            }
            .map { $0.element }
    }
}
```

- [ ] **Step 4: executor 全部改用统一排序器**

删除 `NtkNetworkExecutor.sortInterceptors(_:)`，并将三个位置改为：

```swift
private func makeRequest() async throws -> NtkMutableRequest {
    var request = initialRequest
    let modifiers = NtkInterceptorOrdering.sorted(config.interceptors).compactMap {
        $0 as? any iNtkRequestModifyingInterceptor
    }
    for modifier in modifiers {
        request = try await modifier.modifyRequest(request)
    }
    return request
}
```

```swift
var interceptorsToRun = config.interceptors
interceptorsToRun.append(NtkDeduplicationInterceptor())
let allInterceptors = NtkInterceptorOrdering.sorted(interceptorsToRun)
```

```swift
let parserInterceptors = NtkInterceptorOrdering.sorted(config.interceptors)
    .filter { $0 is NtkResponseParserBox }
```

并把 `loadCache()` 创建 chain manager 时的参数从 `tmpInterceptors` 改成 `parserInterceptors`。

在 `NtkNetworkExecutorTests` 中加入请求修改器的直接顺序测试：

```swift
@Test
@NtkActor
func equalPriorityRequestModifiersKeepRegistrationOrder() async throws {
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/equal-modifier-order"))
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecAppendingRequestInterceptor(id: "first", prio: .medium),
            ExecAppendingRequestInterceptor(id: "second", prio: .medium),
            ExecAppendingRequestInterceptor(id: "third", prio: .medium)
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    let response = try await executor.execute()

    #expect(response.request.headers?["X-Modifier-Order"] == "first,second,third")
}
```

- [ ] **Step 5: 运行排序与 executor 测试**

Run:

```bash
swift test --filter 'NtkInterceptorChainManagerTests|NtkNetworkExecutorTests'
```

Expected: PASS；tier/value 降序与同 priority 注册顺序同时成立。

- [ ] **Step 6: 提交稳定排序**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorOrdering.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit --only -m "feat: preserve interceptor registration order" -- Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorOrdering.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
```

### Task 3: 固定错误传播和缓存副作用边界

**Files:**
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 添加三条动作路径的错误契约测试**

在 `NtkNetworkExecutorTests` 中加入：

```swift
@Test
@NtkActor
func executePropagatesRequestModificationError() async {
    let executor = makeExecutorWithModifier(
        modifier: ExecThrowingRequestInterceptor(),
        cacheStorage: nil
    )

    do {
        _ = try await executor.execute()
        Issue.record("期望请求修改错误")
    } catch let error as ExecRequestModificationError {
        #expect(error == .failed)
    } catch {
        Issue.record("错误类型不符: \(error)")
    }
}

@Test
@NtkActor
func loadCachePropagatesRequestModificationError() async {
    let executor = makeExecutorWithModifier(
        modifier: ExecThrowingRequestInterceptor(),
        cacheStorage: ExecMockCacheStorage(cacheData: true, hasCacheResult: true)
    )

    do {
        _ = try await executor.loadCache()
        Issue.record("期望请求修改错误")
    } catch let error as ExecRequestModificationError {
        #expect(error == .failed)
    } catch {
        Issue.record("错误类型不符: \(error)")
    }
}

@Test
@NtkActor
func hasCacheDataReturnsFalseWithoutTouchingStorageWhenModificationFails() async {
    let capture = ExecCacheRequestCapture()
    let storage = ExecCapturingCacheStorage(capture: capture)
    let executor = makeExecutorWithModifier(
        modifier: ExecThrowingRequestInterceptor(),
        cacheStorage: storage
    )

    let result = await executor.hasCacheData()

    #expect(result == false)
    #expect(await capture.hasDataCalls() == 0)
}

@Test
@NtkActor
func cacheOperationsWithoutProviderSkipRequestModification() async throws {
    let executor = makeExecutorWithModifier(
        modifier: ExecThrowingRequestInterceptor(),
        cacheStorage: nil
    )

    let cachedResponse = try await executor.loadCache()
    let hasCache = await executor.hasCacheData()

    #expect(cachedResponse == nil)
    #expect(hasCache == false)
}
```

加入工厂方法：

```swift
@NtkActor
private func makeExecutorWithModifier(
    modifier: any iNtkRequestModifyingInterceptor,
    cacheStorage: (any iNtkCacheStorage)?
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/modifier-error"))
    request.responseType = String(describing: Bool.self)
    var interceptors: [iNtkInterceptor] = [
        NtkResponseParserBox(ExecMockParsingInterceptor()),
        modifier
    ]
    if let cacheStorage {
        interceptors.append(NtkCacheInterceptor(storage: cacheStorage))
    }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}
```

加入错误和修改器：

```swift
private enum ExecRequestModificationError: Error, Equatable {
    case failed
}

private struct ExecThrowingRequestInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        throw ExecRequestModificationError.failed
    }
}
```

- [ ] **Step 2: 让 cache capture 同时记录 storage 调用次数**

用以下完整实现替换 `ExecCacheRequestCapture` 和 `ExecCapturingCacheStorage.hasData`：

```swift
private actor ExecCacheRequestCapture {
    private var headers: [String: String] = [:]
    private var hasDataCallCount = 0

    func record(_ request: NtkMutableRequest) {
        headers = request.headers ?? [:]
    }

    func recordHasData(_ request: NtkMutableRequest) {
        headers = request.headers ?? [:]
        hasDataCallCount += 1
    }

    func headerValue(for key: String) -> String? {
        headers[key]
    }

    func hasDataCalls() -> Int {
        hasDataCallCount
    }
}

private struct ExecCapturingCacheStorage: iNtkCacheStorage {
    let capture: ExecCacheRequestCapture

    @NtkActor
    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        false
    }

    @NtkActor
    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        await capture.record(request)
        return nil
    }

    @NtkActor
    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await capture.recordHasData(request)
        return true
    }
}
```

- [ ] **Step 3: 添加缓存路径不执行普通 interceptor 的测试**

```swift
@Test
@NtkActor
func loadCacheDoesNotExecuteOrdinaryInterceptors() async throws {
    let counter = ExecCallCounter()
    let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: true)
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/cache-side-effects"))
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            NtkCacheInterceptor(storage: storage),
            ExecPriorityRecordingInterceptor(id: "ordinary", prio: .high, counter: counter)
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    _ = try await executor.loadCache()

    #expect(await counter.log().isEmpty)
}
```

- [ ] **Step 4: 运行 executor 契约测试**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
```

Expected: PASS；execute/loadCache 传播修改错误，hasCacheData 返回 false 且不访问 storage，缓存读取不运行普通 interceptor。

- [ ] **Step 5: 提交错误与副作用测试**

```bash
git add Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit --only -m "test: cover request modification boundaries" -- Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
```

### Task 4: 验证公开生命周期和 `requestWithCache`

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 1: 迁移公开 API 修改器并依赖默认透传**

用以下实现替换 `IntegHeaderRequestInterceptor`：

```swift
private struct IntegHeaderRequestInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-Stable-Parameter", value: "stable")
        return request
    }
}
```

保留现有 `requestAppliesRegisteredInterceptorModification()`，它同时验证：

- `addInterceptor(_:)` 是唯一注册入口；
- 新协议可放入 `[iNtkInterceptor]`；
- 默认 `intercept` 透传不会阻断网络请求。

- [ ] **Step 2: 添加缓存操作不消费网络请求的测试**

```swift
@Test
func cacheOperationsDoNotConsumeNetworkRequest() async throws {
    let storage = IntegMockCacheStorage(cacheData: true)
    let network = makeNetwork(
        client: IntegMockClient(result: .success(())),
        cacheStorage: storage,
        path: "/integration/cache-does-not-consume"
    )

    #expect(await network.hasCacheData() == true)
    let cachedResponse = try await network.loadCache()
    #expect(cachedResponse != nil)

    let response = try await network.request()
    #expect(response.data == true)
    #expect(response.isCache == false)
}
```

- [ ] **Step 3: 添加同一 executor 两个分支独立构建请求的测试**

```swift
@Test
func requestWithCacheBuildsIndependentRequestsFromInitialSnapshot() async throws {
    let counter = IntegModifierCallCounter()
    let storage = IntegMockCacheStorage(cacheData: true)
    let network = makeNetwork(
        client: IntegMockClient(result: .success(()), delay: 0.1),
        cacheStorage: storage,
        path: "/integration/cache-independent-requests"
    )
    network.addInterceptor(IntegCountingRequestInterceptor(counter: counter))

    var headerValues: [String] = []
    for try await response in network.requestWithCache() {
        if let value = response.request.headers?["X-Execution-Count"] {
            headerValues.append(value)
        }
    }

    #expect(headerValues == ["1", "1"])
    #expect(await counter.value() == 2)
}
```

加入测试替身：

```swift
private actor IntegModifierCallCounter {
    private var count = 0

    func record() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private struct IntegCountingRequestInterceptor: iNtkRequestModifyingInterceptor {
    let counter: IntegModifierCallCounter

    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        await counter.record()
        var request = request
        let previousValue = Int(request.headers?["X-Execution-Count"] ?? "") ?? 0
        request.addHeader(key: "X-Execution-Count", value: String(previousValue + 1))
        return request
    }
}
```

- [ ] **Step 4: 运行公开生命周期测试**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS；`loadCache()`/`hasCacheData()` 后仍可调用一次 `request()`，`requestWithCache()` 两个响应的请求头均为 `1`，modifier 调用总数为 `2`。

- [ ] **Step 5: 提交公开生命周期测试**

```bash
git add Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift
git commit --only -m "test: verify cache request lifecycle" -- Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift
```

### Task 5: 验证稳定参数和动态参数的缓存身份

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 让 executor 测试请求支持缓存配置**

用以下完整定义替换 `ExecDummyRequest`：

```swift
private struct ExecDummyRequest: iNtkRequest {
    let path: String
    let requestConfiguration: NtkRequestConfiguration?

    init(
        path: String = "/executor/test",
        requestConfiguration: NtkRequestConfiguration? = nil
    ) {
        self.path = path
        self.requestConfiguration = requestConfiguration
    }
}
```

- [ ] **Step 2: 添加端到端缓存身份测试**

```swift
@Test
@NtkActor
func stableParametersParticipateAndDynamicParametersAreFilteredFromCacheIdentity() async throws {
    let cacheState = ExecInMemoryCacheState()
    let dynamicSource = ExecDynamicParameterSource()
    let requestConfiguration = NtkRequestConfiguration(
        cacheTime: 3600,
        filteredParameterNames: ["token"]
    )
    var request = NtkMutableRequest(
        ExecDummyRequest(
            path: "/executor/cache-identity",
            requestConfiguration: requestConfiguration
        )
    )
    request.responseType = String(describing: Bool.self)
    let baselineKey = NtkRequestIdentifierManager.shared.getCacheKey(
        request: request,
        cacheConfig: request.requestConfiguration
    )
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            NtkCacheInterceptor(storage: ExecInMemoryCacheStorage(state: cacheState)),
            ExecCacheIdentityRequestInterceptor(source: dynamicSource)
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    let networkResponse = try await executor.execute()
    let cacheResponse = try #require(await executor.loadCache())
    let savedKey = try #require(await cacheState.savedKey())
    let loadedKey = try #require(await cacheState.loadedKey())

    #expect(networkResponse.request.parameters?["tenant"] as? String == "coo")
    #expect(cacheResponse.request.parameters?["tenant"] as? String == "coo")
    #expect(networkResponse.request.parameters?["token"] as? String == "token-1")
    #expect(cacheResponse.request.parameters?["token"] as? String == "token-2")
    #expect(savedKey == loadedKey)
    #expect(savedKey != baselineKey)
}
```

该测试同时证明：

- `tenant` 是稳定参数，加入后 cache key 与初始请求不同；
- 两次动作产生不同 token；
- token 被配置过滤后，保存和读取仍使用同一个 key。

- [ ] **Step 3: 运行测试确认缓存身份替身尚不存在**

Run:

```bash
swift test --filter NtkNetworkExecutorTests.stableParametersParticipateAndDynamicParametersAreFilteredFromCacheIdentity
```

Expected: 编译失败，提示找不到 `ExecInMemoryCacheState`、`ExecDynamicParameterSource` 和 `ExecCacheIdentityRequestInterceptor`。

- [ ] **Step 4: 添加缓存身份测试替身**

```swift
private actor ExecDynamicParameterSource {
    private var value = 0

    func nextToken() -> String {
        value += 1
        return "token-\(value)"
    }
}

private struct ExecCacheIdentityRequestInterceptor: iNtkRequestModifyingInterceptor {
    let source: ExecDynamicParameterSource

    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addParameter(key: "tenant", value: "coo")
        request.addParameter(key: "token", value: await source.nextToken())
        return request
    }
}

private actor ExecInMemoryCacheState {
    private var entries: [String: NtkCacheMeta] = [:]
    private var lastSavedKey: String?
    private var lastLoadedKey: String?

    func set(_ metaData: NtkCacheMeta, for key: String) -> Bool {
        entries[key] = metaData
        lastSavedKey = key
        return true
    }

    func get(_ key: String) -> NtkCacheMeta? {
        lastLoadedKey = key
        return entries[key]
    }

    func contains(_ key: String) -> Bool {
        entries[key] != nil
    }

    func savedKey() -> String? {
        lastSavedKey
    }

    func loadedKey() -> String? {
        lastLoadedKey
    }
}

private struct ExecInMemoryCacheStorage: iNtkCacheStorage {
    let state: ExecInMemoryCacheState

    @NtkActor
    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await state.set(metaData, for: key)
    }

    @NtkActor
    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        await state.get(key)
    }

    @NtkActor
    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await state.contains(key)
    }
}
```

- [ ] **Step 5: 运行缓存身份测试**

Run:

```bash
swift test --filter NtkNetworkExecutorTests.stableParametersParticipateAndDynamicParametersAreFilteredFromCacheIdentity
```

Expected: PASS；网络请求使用 `token-1`，缓存读取使用 `token-2`，但保存 key 与读取 key 相同，并且不同于未加入 `tenant` 的基线 key。

- [ ] **Step 6: 提交缓存身份测试**

```bash
git add Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit --only -m "test: verify modified request cache identity" -- Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
```

### Task 6: 同步公开文档并完成总验证

**Files:**
- Modify: `README.md`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift:15-19`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift:10-11`
- Modify: `docs/architecture.md:50-55`
- Modify: `docs/design-decisions.md:5-10,39-43`
- Modify: `docs/ntk-actor-audit.md:94-102`

- [ ] **Step 1: 更新源码注释和模块索引**

把 `NtkInterceptorContext.request` 注释改为：

```swift
/// 当前拦截链使用的只读请求快照。
///
/// 请求结构只能由 `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 构建；
/// `intercept(context:next:)` 阶段只能读取该值。
public let request: NtkMutableRequest
```

把 `NtkMutableRequest` 类型注释改为：

```swift
/// 在 `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 中构建请求的值类型。
/// 进入 `NtkInterceptorContext` 后只能作为只读请求快照使用。
public struct NtkMutableRequest: iNtkRequest {
```

把 `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md` 的核心协议条目改为：

```markdown
- `iNtkInterceptor` - 普通拦截器接口；只能读取请求并控制请求/响应责任链
- `iNtkRequestModifyingInterceptor` - 明确参与请求构建阶段的 interceptor 能力协议
```

- [ ] **Step 2: 更新架构与设计决策**

`docs/architecture.md` 的执行器段落使用：

```markdown
单个 `NtkNetwork` 复用同一个 `NtkNetworkExecutor` 及其冻结配置。每次 `execute()`、`loadCache()`、`hasCacheData()` 都从初始请求快照创建局部请求；`requestWithCache()` 的网络和缓存分支共享 executor，但不共享本次动作的请求值。

缓存读取不会重跑完整拦截器链。只有显式遵循 `iNtkRequestModifyingInterceptor` 的 interceptor 才会在 context 创建前参与请求构建；普通 `intercept()` 只能读取最终请求。请求修改器按 priority 降序执行，同 priority 保持注册顺序。
```

`docs/design-decisions.md` 使用以下两条决策：

```markdown
- **NtkMutableRequest struct 作为请求快照传递** — `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 返回新的请求值；进入拦截器链后只能读取 `NtkInterceptorContext.request`
- **请求修改是显式 interceptor 能力** — 基础 `iNtkInterceptor` 不提供默认修改方法；只有 `iNtkRequestModifyingInterceptor` 参与 `execute()`、`loadCache()`、`hasCacheData()` 的请求构建阶段，同 priority 保持注册顺序
```

把 `docs/ntk-actor-audit.md` A08 的处理方式更新为：

```markdown
处理方式：`NtkNetworkExecutor` 只保留创建时冻结的初始请求快照。`execute()`、`loadCache()` 和 `hasCacheData()` 各自从该快照按稳定 interceptor 顺序调用 `iNtkRequestModifyingInterceptor.modifyRequest(_:)`，构建局部请求。进入 `intercept()` 链后 context 请求只读；缓存流程不运行 retry、loading、toast 等普通拦截行为。
```

- [ ] **Step 3: 更新 README 的 interceptor 示例**

将快速开始中的：

```swift
network.addInterceptor(TokenInterceptor())
```

替换为：

```swift
network.addInterceptor(CommonParameterInterceptor())
```

将“添加拦截器”和“自定义拦截器”章节中通过 `NtkInterceptorChain` 或 `chain.request` 修改请求的旧代码块，替换为下面两个完整示例。

普通日志 interceptor 使用只读 context：

```swift
struct LoggingInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority { .high }

    @NtkActor
    func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        print("📤 请求: \(context.request.method) \(context.request.path)")
        let response = try await next.handle(context: context)
        print("📥 响应: \(response.code)")
        return response
    }
}
```

稳定公共参数 interceptor 使用唯一修改入口：

```swift
struct CommonParameterInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-App-Channel", value: "iOS")
        return request
    }
}

let network = NtkAF<User>.withAF(request)
network.addInterceptor(LoggingInterceptor())
network.addInterceptor(CommonParameterInterceptor())
let user = try await network.request()
```

删除 README 中通过普通 `intercept` 修改 `chain.request` 的旧示例，并在请求修改示例后加入：

```markdown
`intercept(context:next:)` 中的请求是只读快照。请求头和参数只能在
`iNtkRequestModifyingInterceptor.modifyRequest(_:)` 中构建。token、timestamp
等动态字段还需要通过 `NtkRequestConfiguration.filterHeaders` 或
`filterParameters` 排除缓存身份。
```

- [ ] **Step 4: 扫描旧协议表述**

Run:

```bash
rg -n 'iNtkInterceptor\.modifyRequest|所有 interceptor 都提供默认|iNtkRequestModifier\b' Sources Tests README.md docs/architecture.md docs/design-decisions.md docs/ntk-actor-audit.md
```

Expected: 无输出。已批准设计文档中对否决方案的历史说明不在该扫描范围内。

- [ ] **Step 5: 运行格式与构建检查**

Run:

```bash
git diff --check
```

Expected: 无输出，退出码 0。

Run:

```bash
swift build
```

Expected: `Build complete!`，退出码 0。

- [ ] **Step 6: 运行聚焦测试**

Run:

```bash
swift test --filter 'NtkNetworkExecutorTests|NtkInterceptorChainManagerTests|NtkNetworkIntegrationTests'
```

Expected: 所有 executor、排序和公开生命周期测试通过。

- [ ] **Step 7: 运行完整测试**

Run:

```bash
swift test
```

Expected: 所有测试套件通过，退出码 0。

- [ ] **Step 8: 提交文档与注释**

```bash
git add README.md Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift docs/architecture.md docs/design-decisions.md docs/ntk-actor-audit.md
git commit --only -m "docs: document request modifying interceptors" -- README.md Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift docs/architecture.md docs/design-decisions.md docs/ntk-actor-audit.md
```

## Final review checklist

- [ ] `iNtkInterceptor` 不声明或默认实现 `modifyRequest`。
- [ ] `iNtkRequestModifyingInterceptor` 继承 `iNtkInterceptor` 并提供默认 `intercept` 透传。
- [ ] executor 在创建 context 前只调用显式请求修改拦截器。
- [ ] context 的请求属性保持 `public let request`。
- [ ] priority 高者先执行，同 priority 保持注册顺序。
- [ ] `requestWithCache()` 共用 executor，但缓存和网络响应的请求均从初始快照独立构建。
- [ ] `loadCache()`、`hasCacheData()` 未新增 `markRequestConsumed()`。
- [ ] `loadCache()` 不执行普通 interceptor。
- [ ] execute/loadCache 传播修改错误，hasCacheData 返回 false 且不访问 storage。
- [ ] 稳定公共参数进入缓存 key，动态参数由 `NtkRequestConfiguration` 过滤。
- [ ] README、架构文档、设计决策和源码注释使用同一协议名称。
- [ ] `swift build` 与 `swift test` 均通过。
