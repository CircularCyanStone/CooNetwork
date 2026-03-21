# 设计文档：删除 iNtkCacheableClient 协议

## 背景

架构评审（I-1）将缓存方法从 `iNtkClient` 分离到 `iNtkCacheableClient` 协议，遵循接口隔离原则。但分析发现该协议的三个方法（`loadCache`、`saveCache`、`hasCacheData`）全部使用默认实现，唯一的 conformer `AFCacheClient` 是零逻辑的壳。真正的抽象边界是 `iNtkCacheStorage`，不需要中间协议层。

## 目标

- 删除 `iNtkCacheableClient` 协议和 `AFCacheClient` 类型
- `iNtkCacheStorage?` 直接传递到 executor，桥接逻辑下沉为 executor 私有方法
- `NtkCacheSaveInterceptor` 自己持有 `storage`，不依赖 context
- `NtkInterceptorContext` 删除 `cacheableClient` 属性
- 外部 API `Ntk.withAF(storage:)` 签名不变，用户无感

## 变更清单

### 删除

| 类型 | 位置 |
|------|------|
| `iNtkCacheableClient` 协议 + 默认实现 extension | `iNtkClient.swift` |
| `AFCacheClient` 结构体 | `AFClient.swift` |

### 修改

| 文件 | 变更 |
|------|------|
| `NtkNetworkExecutor.swift` | `Configuration.cacheableClient` → `cacheStorage: (any iNtkCacheStorage)?`；`loadCache()` 和 `hasCacheData()` 内部直接用 `NtkNetworkCache(storage:)` |
| `NtkNetwork.swift` | `cacheableClient` 属性 → `cacheStorage: (any iNtkCacheStorage)?`；init/with 签名同步更新 |
| `Ntk.swift` | `cacheableClient` 参数 → `cacheStorage`；`NtkCacheSaveInterceptor(storage:)` 创建时注入 storage |
| `Ntk+AF.swift` | 两个 `withAF` 重载均删除 `AFCacheClient` 创建逻辑，直接传 `storage` |
| `NtkInterceptorContext.swift` | 删除 `cacheableClient` 属性（保留 `@NtkActor` 标注） |
| `NtkCacheSaveInterceptor.swift` | 新增 `storage: any iNtkCacheStorage` 属性，init 注入；`intercept` 中直接用 `NtkNetworkCache(storage:).save(...)` |
| `NtkNetworkExecutorTests.swift` | 更新 mock 类型：`ExecMockCacheableClient` → 改为提供 `iNtkCacheStorage` mock；Configuration 构造更新 |
| `NtkNetworkIntegrationTests.swift` | 更新 mock 类型：`IntegMockCacheableClient` → 改为提供 `iNtkCacheStorage` mock |

### 不变

| 类型 | 原因 |
|------|------|
| `iNtkCacheStorage` 协议 | 真正的抽象边界，不动 |
| `NtkNetworkCache` | 内部工具类，不动 |
| `Ntk.withAF(storage:)` 外部签名 | 参数名和类型不变，用户无感 |

## 详细设计

### NtkNetworkExecutor.Configuration

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

### NtkNetworkExecutor 桥接方法

`loadCache()` 和 `hasCacheData()` 的链末端闭包直接调用 `NtkNetworkCache`：

```swift
// loadCache() 链末端
guard let storage = config.cacheStorage else { return nil }
let cache = NtkNetworkCache(storage: storage)
guard let data = try await cache.loadData(for: context.mutableRequest) else {
    throw NtkError.Cache.noCache
}
return NtkClientResponse(data: data, msg: nil, response: data, request: context.mutableRequest, isCache: true)

// hasCacheData() 链末端
guard let storage = config.cacheStorage else { return false }
let cache = NtkNetworkCache(storage: storage)
let result = await cache.hasData(for: context.mutableRequest)
return NtkResponse(code: .init(200), data: result, msg: nil, response: result, request: context.mutableRequest, isCache: true)
```

### NtkCacheSaveInterceptor

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

### NtkInterceptorContext

删除 `cacheableClient` 属性，init 签名简化（保留 `@NtkActor` 标注）：

```swift
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

### Ntk.with()

```swift
public static func with(
    _ client: any iNtkClient,
    request: iNtkRequest,
    dataParsingInterceptor: iNtkInterceptor,
    validation: iNtkResponseValidation,
    cacheStorage: (any iNtkCacheStorage)? = nil
) -> NtkNetwork<ResponseData> {
    // ...
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

### Ntk+AF.swift

两个 `withAF` 重载均删除 `AFCacheClient` 创建，直接传 `storage`：

```swift
// 重载 1：默认 AFResponseMapKeys
static func withAF(
    _ request: iAFRequest,
    dataParsingInterceptor: iNtkInterceptor = ...,
    validation: iNtkResponseValidation = ...,
    storage: iNtkCacheStorage? = nil
) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
    let client = AFClient()
    let net = with(client, request: request, dataParsingInterceptor: dataParsingInterceptor,
                   validation: validation, cacheStorage: storage)
    if request is iAFUploadRequest {
        net.disableDeduplication()
    }
    return net
}

// 重载 2：自定义 Keys 映射
static func withAF<Keys: iNtkResponseMapKeys>(
    _ request: iAFRequest,
    keys: Keys.Type,
    dataParsingInterceptor: iNtkInterceptor = ...,
    validation: iNtkResponseValidation = ...,
    storage: iNtkCacheStorage? = nil
) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
    let client = AFClient()
    let net = with(client, request: request, dataParsingInterceptor: dataParsingInterceptor,
                   validation: validation, cacheStorage: storage)
    if request is iAFUploadRequest {
        net.disableDeduplication()
    }
    return net
}
```

### NtkNetworkExecutor.execute()

`execute()` 方法中构造 `NtkInterceptorContext` 时删除 `cacheableClient` 参数：

```swift
let context = NtkInterceptorContext(
    mutableRequest: mutableRequest,
    validation: config.validation,
    client: config.client
)
```

## 行为变更说明

`NtkCacheSaveInterceptor` 的创建条件从 `request.requestConfiguration != nil` 变为 `cacheStorage != nil && request.requestConfiguration != nil`。这是一个微小的行为优化：当没有提供 storage 时，不再创建一个会在 `intercept()` 中立即 early-return 的空拦截器。功能等价，减少了无意义的拦截器链节点。

## 验证标准

- `swift build` 编译通过
- `swift test` 全部测试通过
- 无 `iNtkCacheableClient` 或 `AFCacheClient` 的引用残留
