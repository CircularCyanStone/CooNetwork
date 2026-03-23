# 拦截器三层 Tier 优先级设计

## 背景

当前 `NtkNetworkExecutor` 维护 `interceptors`（用户级）和 `coreInterceptors`（核心级）两个数组，但在执行时合并排序（`sortInterceptors(config.interceptors + executionCoreInterceptors)`），两个数组的区分完全失效。核心拦截器（如 `NtkDeduplicationInterceptor`、`dataParsingInterceptor`）的执行顺序容易被用户拦截器入侵。

## 目标

- 核心拦截器的执行顺序不可被用户拦截器影响
- 用户 API 零破坏性变更
- 移除无意义的双数组设计，统一为单数组 + Tier 隔离

## 链式执行模型

`NtkInterceptorChainManager` 按数组顺序递归构建洋葱模型：

```
请求流（外→内）: interceptors[0] → interceptors[1] → ... → finalHandler
响应流（内→外）: finalHandler → ... → interceptors[1] → interceptors[0]
```

排序规则：`priority` 降序，高优先级 = 外层。

## 正确的执行顺序

```
请求流: Dedup → Retry → Toast → Loading → [用户自定义] → DataParsing → Cache → 网络请求
响应流: 网络响应 → Cache(存原始数据) → DataParsing(解析+校验) → [用户自定义] → Loading → Toast → Retry → Dedup
```

### 各拦截器定位分析

| 拦截器 | 定位 | 理由 |
|--------|------|------|
| Dedup | 最外层 | 请求流第一个判断去重；响应流最后分发给等待者 |
| Retry | 用户层外侧 | 在 Dedup 内侧，失败时重试内层整条链 |
| Toast/Loading | 用户层中间 | Loading 不随重试重复；Toast 在所有重试失败后才提示 |
| DataParsing | 用户层内侧 | 抛出的 `NtkError.validation` 需向外冒泡被 Toast 捕获、被 Retry 重试；必须在 Cache 外侧 |
| Cache | 最内层 | 存储原始 `NtkClientResponse` 数据，与 `loadCache()` 重新解析逻辑一致 |

## 设计方案：三层 Tier

### NtkInterceptorPriority 改造

```swift
public struct NtkInterceptorPriority: Comparable, Sendable {

    /// 优先级层级（internal，不暴露给用户）
    /// outer > standard > inner，不同层级之间不可跨越
    enum Tier: Int, Comparable, Sendable {
        /// 最靠近网络调用的框架拦截器（DataParsing, Cache）
        case inner = 0
        /// 用户级别拦截器（默认）
        case standard = 1
        /// 最外层的框架拦截器（Dedup）
        case outer = 2
    }

    /// 层级（internal，用户无法直接设置）
    let tier: Tier
    /// 层级内的优先级数值
    public let value: Int

    // ── 用户级别常量（standard tier）──
    public static let low    = Self(tier: .standard, value: 250)
    public static let medium = Self(tier: .standard, value: 750)
    public static let high   = Self(tier: .standard, value: 1000)

    // ── 框架内部常量 ──
    /// Dedup 使用：最外层
    static let outerHighest = Self(tier: .outer, value: 1000)
    /// DataParsing 使用：内层高位
    static let innerHigh    = Self(tier: .inner, value: 750)
    /// Cache 使用：内层低位
    static let innerLow     = Self(tier: .inner, value: 250)

    /// 默认初始化：standard tier，value 750（与原行为一致）
    public init() {
        self.tier = .standard
        self.value = 750
    }

    // ── 公开工厂方法（只能创建 standard tier）──
    public static func priority(_ value: Int) -> Self {
        .init(tier: .standard, value: max(min(value, 1000), 0))
    }

    // ── 比较：先比 tier，再比 value ──
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
        return lhs.value < rhs.value
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tier == rhs.tier && lhs.value == rhs.value
    }
}
```

### 算术运算符调整

```swift
extension NtkInterceptorPriority {
    public static func + (lhs: Self, rhs: Int) -> Self {
        .init(tier: lhs.tier, value: min(lhs.value + rhs, 1000))
    }

    public static func - (lhs: Self, rhs: Int) -> Self {
        .init(tier: lhs.tier, value: max(lhs.value - rhs, 0))
    }
}
```

运算结果保持原 tier 不变，value 限制在 `[0, 1000]`。

### init 访问控制

| 初始化方法 | 访问级别 | 说明 |
|-----------|---------|------|
| `init(tier:value:)` | `internal` | 框架内部使用 |
| `init()` | `public` | 默认 `.standard` tier, value 750 |
| `init(value:)` | **移除** | 用 `priority(_:)` 替代，防止绕过 tier |
| `priority(_:)` | `public` | 唯一的用户自定义入口，强制 `.standard` tier |

### 拦截器优先级分配

| 拦截器 | Tier | Value | 链位置 |
|--------|------|-------|--------|
| NtkDeduplicationInterceptor | `.outer` | 1000 (outerHighest) | 最外层 |
| NtkRetryInterceptor | `.standard` | 1000 (.high) | 用户最外 |
| AFToastInterceptor | `.standard` | 750 (.medium) | 用户中间 |
| NtkLoadingInterceptor | `.standard` | 750 (.medium) | 用户中间 |
| DataParsing (NtkDataParsingInterceptor 等) | `.inner` | 750 (innerHigh) | 内层外侧 |
| NtkCacheInterceptor | `.inner` | 250 (innerLow) | 最内层 |

## NtkNetworkExecutor 改造

### 移除双数组

`Configuration` 中移除 `coreInterceptors` 字段，统一为 `interceptors`。

```swift
struct Configuration {
    let client: any iNtkClient
    let request: NtkMutableRequest
    let interceptors: [iNtkInterceptor]       // 所有拦截器（含核心）
    let validation: iNtkResponseValidation
    let dataParsingInterceptor: iNtkInterceptor
}
```

### execute() 简化

```swift
func execute() async throws -> NtkResponse<ResponseData> {
    let context = NtkInterceptorContext(...)

    // 动态添加核心拦截器（它们自带正确的 tier + value）
    var allInterceptors = config.interceptors
    allInterceptors.append(NtkDeduplicationInterceptor())
    allInterceptors.append(config.dataParsingInterceptor)

    let sorted = sortInterceptors(allInterceptors)
    let chainManager = NtkInterceptorChainManager(interceptors: sorted) { ... }
    // ...
}
```

### loadCache() 简化

`loadCache()` 从原始缓存数据重新解析响应，需要且仅需要 `dataParsingInterceptor`。

```swift
func loadCache() async throws -> NtkResponse<ResponseData>? {
    guard let cacheProvider else { return nil }
    let context = NtkInterceptorContext(...)

    // 仅使用 dataParsingInterceptor，不含 Dedup/Retry/Cache
    let chainManager = NtkInterceptorChainManager(
        interceptors: [config.dataParsingInterceptor]
    ) { _ in
        // finalHandler: 从缓存加载原始数据并包装为 iNtkResponse
        ...
    }
    return try await chainManager.execute(context: context)
}
```

### hasCacheData() 处理

`hasCacheData()` 仅判断缓存是否存在，不需要经过拦截器链。直接调用 `cacheProvider.hasCacheData(for:)` 即可：

```swift
func hasCacheData() async -> Bool {
    guard let cacheProvider else { return false }
    return await cacheProvider.hasCacheData(for: mutableRequest)
}
```

这与当前实现等价（当前实现也是调用 `cacheProvider` 方法），仅移除了不必要的拦截器链。

## NtkNetwork 改造

### 移除 _coreInterceptors

- 删除 `_coreInterceptors` 属性
- 删除 `addCoreInterceptor(_:)` 方法（当前 `fileprivate` 且无调用点）
- `getOrCreateExecutor()` 中 Configuration 不再传 `coreInterceptors`

### NtkCacheInterceptor 改造

`priority` 参数移除，固定为 `.innerLow`，Cache 拦截器必须是最内层，允许用户调整其优先级没有合理的使用场景：

```swift
public init(storage: any iNtkCacheStorage) {
    self.storage = storage
    self.priority = .innerLow
}
```

## DataParsing 拦截器改造

`NtkDataParsingInterceptor` 和 `AFJsonObjectParsingInterceptor` 需要添加 `priority` 属性：

```swift
public struct NtkDataParsingInterceptor<...>: iNtkInterceptor {
    public var priority: NtkInterceptorPriority { .dataParsing }
    // ...
}
```

由于 `.innerHigh` 是 `internal`，而 `NtkDataParsingInterceptor` 在 `AlamofireClient` 模块中，使用 `package` 访问级别暴露专用常量（Swift 5.9+，本项目已使用 swift-tools-version 6.1）。`AlamofireClient` 和 `CooNetwork` 在同一 package 内，`package` 级别对双方可见，但对外部消费者不可见，彻底避免用户复用 inner tier 常量：

```swift
/// 数据解析拦截器专用优先级
/// 确保在用户拦截器内侧、缓存拦截器外侧执行
package static let dataParsing = Self(tier: .inner, value: 750)
```

## 影响范围

### 需要修改的文件

| 文件 | 变更 |
|------|------|
| `iNtkInterceptor.swift` | NtkInterceptorPriority 重构（Tier、init 访问控制、运算符） |
| `NtkNetworkExecutor.swift` | 移除 coreInterceptors，简化 execute/loadCache |
| `NtkNetwork.swift` | 移除 _coreInterceptors、addCoreInterceptor |
| `NtkDeduplicationInterceptor.swift` | 添加 `priority: .outerHighest` |
| `NtkCacheInterceptor.swift` | 移除 `priority` 参数，固定为 `.innerLow` |
| `NtkDataParsingInterceptor.swift` | 添加 `priority: .dataParsing` |
| `AFJsonObjectParsingInterceptor.swift` | 添加 `priority: .dataParsing` |

### 不需要修改的文件

- `NtkRetryInterceptor.swift` — 已有 `.high`，属于 standard tier，无需改动
- `NtkLoadingInterceptor.swift` — 默认 `.medium`，无需改动
- `AFToastInterceptor.swift` — 默认 `.medium`，无需改动
- `Ntk+AF.swift` — 无需改动
- `Ntk.swift` — 无需改动

### 用户侧兼容性

- `NtkInterceptorPriority.low / .medium / .high` 不变
- `priority(_:)` 工厂方法不变
- `init()` 不变（默认 medium）
- `init(value:)` 移除 — 如果有用户直接使用，需迁移到 `priority(_:)`
- 算术运算符行为不变（保持 tier，clamp value）

## 测试要点

1. 验证 tier 比较：`outer > standard > inner`，同 tier 内按 value 比较
2. 验证 `priority(_:)` 只能创建 standard tier
3. 验证运算符保持原 tier
4. 验证 execute() 中拦截器排序：Dedup 最外、DataParsing 在用户拦截器内侧、Cache 最内
5. 验证 loadCache() 只使用 dataParsing 拦截器
6. 验证用户拦截器无法入侵 outer/inner tier
