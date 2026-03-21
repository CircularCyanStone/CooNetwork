# 删除 iNtkCacheableClient 协议 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 `iNtkCacheableClient` 协议和 `AFCacheClient`，将 `iNtkCacheStorage?` 直接传递到 executor，桥接逻辑下沉为 executor 内部实现。

**Architecture:** `iNtkCacheStorage` 是真正的缓存抽象边界。删除中间的 `iNtkCacheableClient` 协议层后，`NtkNetworkExecutor` 直接持有 `cacheStorage: (any iNtkCacheStorage)?`，内部用 `NtkNetworkCache(storage:)` 完成缓存操作。`NtkCacheSaveInterceptor` 自己持有 `storage`，不再依赖 `NtkInterceptorContext`。

**Tech Stack:** Swift 6, Swift Testing, CooNetwork

**Spec:** `docs/superpowers/specs/2026-03-21-remove-iNtkCacheableClient-design.md`

---

### Task 1: 修改 NtkInterceptorContext — 删除 cacheableClient 属性

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`

- [ ] **Step 1: 删除 cacheableClient 属性和 init 参数**

```swift
// 删除这两行:
//     public let cacheableClient: (any iNtkCacheableClient)?
// init 参数中删除 cacheableClient，以及 self.cacheableClient = cacheableClient

// 修改后的完整文件:
@NtkActor
public final class NtkInterceptorContext: Sendable {
    public var mutableRequest: NtkMutableRequest
    public let validation: iNtkResponseValidation
    public let client: any iNtkClient
    public var extraData: [String: Sendable] = [:]

    init(mutableRequest: NtkMutableRequest, validation: iNtkResponseValidation, client: any iNtkClient) {
        self.mutableRequest = mutableRequest
        self.validation = validation
        self.client = client
    }
}
```

---

### Task 2: 修改 NtkCacheSaveInterceptor — 自己持有 storage

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheSaveInterceptor.swift`

- [ ] **Step 1: 添加 storage 属性，修改 init，修改 intercept**

```swift
public struct NtkCacheSaveInterceptor: iNtkInterceptor {
    public var priority: NtkInterceptorPriority
    private let storage: any iNtkCacheStorage
    private let responseExtractor: ResponseExtractor

    public init(storage: any iNtkCacheStorage, priority: NtkInterceptorPriority = .priority(0)) {
        self.storage = storage
        self.priority = priority
        self.responseExtractor = Self.defaultResponseExtractor
    }

    public init(storage: any iNtkCacheStorage, priority: NtkInterceptorPriority = .priority(0), responseExtractor: @escaping ResponseExtractor) {
        self.storage = storage
        self.priority = priority
        self.responseExtractor = responseExtractor
    }

    private static let defaultResponseExtractor: ResponseExtractor = { response in
        response.response
    }

    public func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        guard let requestPolicy = context.mutableRequest.requestConfiguration else { return response }
        if requestPolicy.cacheTime > 0 && requestPolicy.shouldCache(response) {
            if let extractedResponse = responseExtractor(response) {
                let cache = NtkNetworkCache(storage: storage)
                let result = await cache.save(data: extractedResponse, for: context.mutableRequest)
                logger.debug("NTK请求缓存\(result ? "成功" : "失败")")
            }
        }
        return response
    }
}
```

---

### Task 3: 修改 NtkNetworkExecutor — cacheableClient → cacheStorage

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`

- [ ] **Step 1: Configuration 中 cacheableClient → cacheStorage**

```swift
struct Configuration {
    let client: any iNtkClient
    let cacheStorage: (any iNtkCacheStorage)?  // 替代 cacheableClient
    let request: NtkMutableRequest
    let interceptors: [iNtkInterceptor]
    var coreInterceptors: [iNtkInterceptor]
    let validation: iNtkResponseValidation
    let dataParsingInterceptor: iNtkInterceptor
}
```

- [ ] **Step 2: execute() 中删除 cacheableClient 传参**

```swift
// 修改前:
let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client, cacheableClient: config.cacheableClient)

// 修改后:
let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)
```

- [ ] **Step 3: loadCache() 改用 NtkNetworkCache 直接操作**

```swift
func loadCache() async throws -> NtkResponse<ResponseData>? {
    guard let storage = config.cacheStorage else {
        return nil
    }
    let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

    var executionCoreInterceptors = config.coreInterceptors
    executionCoreInterceptors.append(config.dataParsingInterceptor)
    let tmpInterceptors = sortInterceptors(executionCoreInterceptors)

    let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { [weak self] context in
        self?.mutableRequest = context.mutableRequest
        let cache = NtkNetworkCache(storage: storage)
        guard let data = try await cache.loadData(for: context.mutableRequest) else {
            throw NtkError.Cache.noCache
        }
        return NtkClientResponse(data: data, msg: nil, response: data, request: context.mutableRequest, isCache: true)
    }

    do {
        let response = try await realChainManager.execute(context: context)
        if let response = response as? NtkResponse<ResponseData> {
            return response
        } else {
            throw NtkError.serviceDataTypeInvalid
        }
    } catch NtkError.Cache.noCache {
        return nil
    }
}
```

- [ ] **Step 4: hasCacheData() 改用 NtkNetworkCache 直接操作**

```swift
func hasCacheData() async -> Bool where ResponseData == Bool {
    guard let storage = config.cacheStorage else {
        return false
    }
    let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

    let sortedInterceptors = sortInterceptors(config.interceptors)

    let realChainManager = NtkInterceptorChainManager(interceptors: sortedInterceptors) { [weak self] context in
        self?.mutableRequest = context.mutableRequest
        let cache = NtkNetworkCache(storage: storage)
        let result = await cache.hasData(for: context.mutableRequest)
        let response = NtkResponse(code: .init(200), data: result, msg: nil, response: result, request: context.mutableRequest, isCache: true)
        return response
    }

    do {
        let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
        return response?.data ?? false
    } catch {
        return false
    }
}
```

---

### Task 4: 修改 NtkNetwork — cacheableClient → cacheStorage

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`

- [ ] **Step 1: 属性、init、with 签名全部替换 cacheableClient → cacheStorage**

需要修改的点：
1. `private var cacheableClient: (any iNtkCacheableClient)?` → `private var cacheStorage: (any iNtkCacheStorage)?`
2. `init` 参数 `cacheableClient: (any iNtkCacheableClient)? = nil` → `cacheStorage: (any iNtkCacheStorage)? = nil`
3. `self.cacheableClient = cacheableClient` → `self.cacheStorage = cacheStorage`
4. `public class func with` 参数同上
5. `getOrCreateExecutor()` 中 `cacheableClient: cacheableClient` → `cacheStorage: cacheStorage`

---

### Task 5: 修改 Ntk.swift — cacheableClient → cacheStorage，NtkCacheSaveInterceptor 注入 storage

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/Ntk.swift`

- [ ] **Step 1: 参数替换 + 条件创建拦截器**

```swift
public static func with(
    _ client: any iNtkClient,
    request: iNtkRequest,
    dataParsingInterceptor: iNtkInterceptor,
    validation: iNtkResponseValidation,
    cacheStorage: (any iNtkCacheStorage)? = nil
) -> NtkNetwork<ResponseData> {
    var _validation: iNtkResponseValidation
    if let requestValidation = request as? iNtkResponseValidation {
        _validation = requestValidation
    } else {
        _validation = validation
    }

    var interceptors: [iNtkInterceptor] = []
    if let storage = cacheStorage, request.requestConfiguration != nil {
        interceptors.append(NtkCacheSaveInterceptor(storage: storage))
    }

    let net = NtkNetwork<ResponseData>.with(
        client, cacheStorage: cacheStorage, request: request,
        dataParsingInterceptor: dataParsingInterceptor,
        validation: _validation, interceptors: interceptors
    )
    return net
}
```

---

### Task 6: 修改 Ntk+AF.swift — 删除 AFCacheClient 创建，直传 storage

**Files:**
- Modify: `Sources/AlamofireClient/Ntk+AF.swift`

- [ ] **Step 1: 两个 withAF 重载均删除 AFCacheClient 创建**

重载 1（默认 Keys）:
```swift
// 删除:
//     let cacheableClient: AFCacheClient? = storage.map { AFCacheClient(storage: $0) }
//     let net = with(client, request: request, ..., cacheableClient: cacheableClient)
// 替换为:
let net = with(client, request: request, dataParsingInterceptor: dataParsingInterceptor,
               validation: validation, cacheStorage: storage)
```

重载 2（自定义 Keys）同理。

---

### Task 7: 删除 iNtkCacheableClient 协议和 AFCacheClient

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkClient.swift` — 删除 `iNtkCacheableClient` 协议及其 extension（第 32-89 行）
- Modify: `Sources/AlamofireClient/Client/AFClient.swift` — 删除 `AFCacheClient` 结构体（第 180-190 行）

- [ ] **Step 1: 从 iNtkClient.swift 删除 iNtkCacheableClient 协议和默认实现 extension**

删除第 32-89 行（从 `// MARK: - 缓存能力协议` 到文件末尾）。

- [ ] **Step 2: 从 AFClient.swift 删除 AFCacheClient**

删除第 180-190 行（从 `// MARK: - AF 缓存客户端` 到文件末尾）。

- [ ] **Step 3: 编译验证**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove iNtkCacheableClient protocol, move cacheStorage to executor"
```

---

### Task 8: 更新测试 — ExecMockCacheableClient → iNtkCacheStorage mock

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 删除 ExecMockCacheableClient，更新 mock 为 iNtkCacheStorage**

将 `ExecMockCacheableClient` 替换为直接使用 `ExecMockCacheStorage`（已存在），但需要让它支持返回缓存数据和 hasData 结果。

新的 `ExecMockCacheStorage`:
```swift
private struct ExecMockCacheStorage: iNtkCacheStorage {
    let cachedMeta: NtkCacheMeta?
    let hasCacheResult: Bool

    init(cachedMeta: NtkCacheMeta? = nil, hasCacheResult: Bool = false) {
        self.cachedMeta = cachedMeta
        self.hasCacheResult = hasCacheResult
    }

    @NtkActor func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool { false }
    @NtkActor func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? { cachedMeta }
    @NtkActor func hasData(key: String, for request: NtkMutableRequest) async -> Bool { hasCacheResult }
}
```

- [ ] **Step 2: 更新 factory helpers**

```swift
@NtkActor
private func makeExecutor(
    client: ExecMockClient,
    cacheStorage: (any iNtkCacheStorage)? = nil,
    parsingInterceptor: iNtkInterceptor
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        cacheStorage: cacheStorage,
        request: request,
        interceptors: [],
        coreInterceptors: [],
        validation: ExecDummyValidation(),
        dataParsingInterceptor: parsingInterceptor
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

@NtkActor
private func makeBoolExecutor(
    client: ExecMockClient,
    cacheStorage: (any iNtkCacheStorage)? = nil
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        cacheStorage: cacheStorage,
        request: request,
        interceptors: [],
        coreInterceptors: [],
        validation: ExecDummyValidation(),
        dataParsingInterceptor: ExecMockParsingInterceptor()
    )
    return NtkNetworkExecutor<Bool>(config: config)
}
```

- [ ] **Step 3: 更新测试用例调用**

`loadCacheReturnsCachedResponse`:
```swift
let meta = NtkCacheMeta(appVersion: "1.0", creationDate: Date().timeIntervalSince1970,
                        expirationDate: Date().timeIntervalSince1970 + 3600, data: true)
let storage = ExecMockCacheStorage(cachedMeta: meta)
let executor = makeExecutor(client: ExecMockClient(result: .success(())),
                            cacheStorage: storage,
                            parsingInterceptor: ExecMockParsingInterceptor())
```

`loadCacheReturnsNilWhenNoCache`: 传 `ExecMockCacheStorage(cachedMeta: nil)` 作为 `cacheStorage`。

`loadCacheReturnsNilWithoutCacheableClient`: 传 `cacheStorage: nil`（不变）。

`hasCacheDataReturnsTrueWhenCacheExists`: 传 `ExecMockCacheStorage(hasCacheResult: true)` 作为 `cacheStorage`。

`hasCacheDataReturnsFalseWithoutCacheableClient`: 传 `cacheStorage: nil`（不变）。

`executePropagatesclientError` 和 `executeSortsAllInterceptorsByPriority`: `cacheableClient: nil` → `cacheStorage: nil`。

- [ ] **Step 4: 删除旧的 ExecMockCacheableClient 和 makeCacheClientResponse**

---

### Task 9: 更新测试 — IntegMockCacheableClient → iNtkCacheStorage mock

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 1: 删除 IntegMockCacheableClient，更新 mock 为 iNtkCacheStorage**

新的 `IntegMockCacheStorage`:
```swift
private struct IntegMockCacheStorage: iNtkCacheStorage {
    let cachedMeta: NtkCacheMeta?

    init(cachedMeta: NtkCacheMeta? = nil) {
        self.cachedMeta = cachedMeta
    }

    @NtkActor func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool { false }
    @NtkActor func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? { cachedMeta }
    @NtkActor func hasData(key: String, for request: NtkMutableRequest) async -> Bool { cachedMeta != nil }
}
```

- [ ] **Step 2: 更新 factory helper**

```swift
private func makeNetwork(
    client: IntegMockClient,
    cacheStorage: (any iNtkCacheStorage)? = nil
) -> NtkNetwork<Bool> {
    NtkNetwork<Bool>.with(
        client,
        cacheStorage: cacheStorage,
        request: IntegDummyRequest(),
        dataParsingInterceptor: IntegMockParsingInterceptor(),
        validation: IntegDummyValidation()
    )
}
```

- [ ] **Step 3: 更新测试用例调用**

`requestWithCacheReturnsOnlyNetworkWhenNoCache`: 传 `IntegMockCacheStorage(cachedMeta: nil)` 作为 `cacheStorage`。

`requestWithCacheReturnsBothCacheAndNetwork`:
```swift
let meta = NtkCacheMeta(appVersion: "1.0", creationDate: Date().timeIntervalSince1970,
                        expirationDate: Date().timeIntervalSince1970 + 3600, data: true)
let storage = IntegMockCacheStorage(cachedMeta: meta)
let network = makeNetwork(client: IntegMockClient(result: .success(()), delay: 0.1),
                          cacheStorage: storage)
```

- [ ] **Step 4: 删除旧的 IntegMockCacheableClient**

- [ ] **Step 5: 运行全部测试**

Run: `swift test`
Expected: All tests passed

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "test: update executor and integration tests for cacheStorage refactoring"
```

---

### Task 10: 最终验证 — 无残留引用

- [ ] **Step 1: 搜索残留引用**

Run: `grep -r "iNtkCacheableClient\|AFCacheClient\|cacheableClient" Sources/ Tests/`
Expected: 无匹配结果

- [ ] **Step 2: 完整构建**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 完整测试**

Run: `swift test`
Expected: All tests passed
