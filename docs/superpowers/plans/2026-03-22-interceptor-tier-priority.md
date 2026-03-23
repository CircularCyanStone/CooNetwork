# Interceptor Three-Tier Priority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a three-tier (`outer` / `standard` / `inner`) priority system to `NtkInterceptorPriority` so that core interceptors (Dedup, DataParsing, Cache) can never be displaced by user interceptors.

**Architecture:** Add an internal `Tier` enum to `NtkInterceptorPriority`; comparison uses tier first, value second. All interceptors carry the right tier by default, so `NtkNetworkExecutor` can safely merge all interceptors into one sorted array. The dual-array (`_interceptors` + `_coreInterceptors`) is removed.

**Tech Stack:** Swift 6.1 / SPM, `@NtkActor`, Swift Testing framework (`import Testing`)

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift` | Rewrite `NtkInterceptorPriority`: add `Tier` enum, adjust `init`, operators, access control |
| `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift` | Add `priority: .outerHighest` |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift` | Remove `priority` param from `init`, fix to `.innerLow` |
| `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift` | Remove `coreInterceptors` from `Configuration`; simplify `execute()`, `loadCache()`, `hasCacheData()` |
| `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift` | Remove `_coreInterceptors` and `addCoreInterceptor(_:)` |
| `Sources/AlamofireClient/Client/NtkDataParsingInterceptor.swift` | Add `priority: .dataParsing` |
| `Sources/AlamofireClient/Client/AFJsonObjectParsingInterceptor.swift` | Add `priority: .dataParsing` |
| `Tests/CooNetworkTests/NtkInterceptorPriorityTests.swift` | New file: unit tests for tier comparison, operators, factory methods |
| `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift` | Add tier-ordering integration test |

---

## Task 1: Rewrite NtkInterceptorPriority with Tier

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift`
- Create: `Tests/CooNetworkTests/NtkInterceptorPriorityTests.swift`

- [ ] **Step 1.1: Write failing tests**

Create `Tests/CooNetworkTests/NtkInterceptorPriorityTests.swift`:

```swift
import Testing
import Foundation
@testable import CooNetwork

struct NtkInterceptorPriorityTests {

    // MARK: - Tier 比较

    @Test
    func outerTierGreaterThanStandard() {
        let outer = NtkInterceptorPriority.outerHighest
        let standard = NtkInterceptorPriority.high
        #expect(outer > standard)
    }

    @Test
    func standardTierGreaterThanInner() {
        let standard = NtkInterceptorPriority.low
        let inner = NtkInterceptorPriority.innerLow
        #expect(standard > inner)
    }

    @Test
    func outerTierGreaterThanInner() {
        let outer = NtkInterceptorPriority.outerHighest
        let inner = NtkInterceptorPriority.innerHigh
        #expect(outer > inner)
    }

    @Test
    func sameTierComparesValue() {
        let high = NtkInterceptorPriority.high       // standard, 1000
        let low  = NtkInterceptorPriority.low        // standard, 250
        #expect(high > low)
    }

    @Test
    func innerTierHighValueStillBelowStandardLow() {
        let innerHigh = NtkInterceptorPriority.innerHigh  // inner, 750
        let standardLow = NtkInterceptorPriority.low          // standard, 250
        #expect(standardLow > innerHigh)
    }

    // MARK: - Factory 只能创建 standard tier

    @Test
    func priorityFactoryCreatesStandardTier() {
        let p = NtkInterceptorPriority.priority(500)
        #expect(p.tier == .standard)
        #expect(p.value == 500)
    }

    @Test
    func priorityFactoryClampsToMax() {
        let p = NtkInterceptorPriority.priority(9999)
        #expect(p.value == 1000)
    }

    @Test
    func priorityFactoryClampsToMin() {
        let p = NtkInterceptorPriority.priority(-1)
        #expect(p.value == 0)
    }

    @Test
    func defaultInitIsStandardMedium() {
        let p = NtkInterceptorPriority()
        #expect(p.tier == .standard)
        #expect(p.value == 750)
    }

    // MARK: - 算术运算符保持 tier

    @Test
    func additionPreservesTier() {
        let base = NtkInterceptorPriority.medium  // standard, 750
        let result = base + 100
        #expect(result.tier == .standard)
        #expect(result.value == 850)
    }

    @Test
    func subtractionPreservesTier() {
        let base = NtkInterceptorPriority.medium  // standard, 750
        let result = base - 100
        #expect(result.tier == .standard)
        #expect(result.value == 650)
    }

    @Test
    func additionClampsToMax() {
        let base = NtkInterceptorPriority.high    // standard, 1000
        let result = base + 500
        #expect(result.value == 1000)
    }

    @Test
    func subtractionClampsToZero() {
        let base = NtkInterceptorPriority.low     // standard, 250
        let result = base - 9999
        #expect(result.value == 0)
    }
}
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
swift test --filter NtkInterceptorPriorityTests 2>&1 | tail -20
```

Expected: compile error — `outerHighest`, `innerHigh`, `innerLow`, `.tier` do not exist yet.

- [ ] **Step 1.3: Rewrite NtkInterceptorPriority**

Replace the entire `NtkInterceptorPriority` struct and its extension in `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift`.

Replace from `public struct NtkInterceptorPriority` through the closing `}` of `extension NtkInterceptorPriority` with:

```swift
/// 拦截器优先级
/// 用于管理和比较拦截器的执行优先级，支持自定义优先级数值
/// - Note: 对于请求流：值越大执行越早
///         对于响应流：值越小执行越早
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
    /// 低优先级（250）
    public static let low    = Self(tier: .standard, value: 250)
    /// 中等优先级（750）
    public static let medium = Self(tier: .standard, value: 750)
    /// 高优先级（1000）
    public static let high   = Self(tier: .standard, value: 1000)

    // ── 框架内部常量 ──
    /// Dedup 使用：最外层
    static let outerHighest = Self(tier: .outer, value: 1000)
    /// DataParsing 使用：内层高位（通过 package-level `.dataParsing` 暴露给 AlamofireClient）
    static let innerHigh    = Self(tier: .inner, value: 750)
    /// Cache 使用：内层低位
    static let innerLow     = Self(tier: .inner, value: 250)

    /// 数据解析拦截器专用优先级（package 级别，供 AlamofireClient 使用）
    package static let dataParsing = Self(tier: .inner, value: 750)

    /// 默认初始化：standard tier，value 750（与原行为一致）
    public init() {
        self.tier = .standard
        self.value = 750
    }

    /// 框架内部初始化
    init(tier: Tier, value: Int) {
        self.tier = tier
        self.value = value
    }

    /// 自定义优先级（强制 standard tier，限制在 [0, 1000]）
    /// - Parameter value: 优先级数值
    /// - Returns: 新的 standard tier 优先级实例
    public static func priority(_ value: Int) -> Self {
        .init(tier: .standard, value: max(min(value, 1000), 0))
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
        return lhs.value < rhs.value
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tier == rhs.tier && lhs.value == rhs.value
    }
}

// MARK: - Arithmetic Operators
extension NtkInterceptorPriority {
    /// 优先级加法运算符（保持原 tier，value 限制在 [0, 1000]）
    public static func + (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .init(tier: lhs.tier, value: min(lhs.value + rhs, 1000))
    }

    /// 优先级减法运算符（保持原 tier，value 限制在 [0, 1000]）
    public static func - (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .init(tier: lhs.tier, value: max(lhs.value - rhs, 0))
    }
}
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
swift test --filter NtkInterceptorPriorityTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 1.5: Verify full build**

```bash
swift build 2>&1 | grep -E 'error:|Build complete'
```

Expected: `Build complete!` (errors may appear from downstream files that haven't been updated yet — those are resolved in subsequent tasks).

- [ ] **Step 1.6: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift \
        Tests/CooNetworkTests/NtkInterceptorPriorityTests.swift
git commit -m "feat: add three-tier priority to NtkInterceptorPriority"
```

---

## Task 2: Update Core Interceptor Priorities

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`
- Modify: `Sources/AlamofireClient/Client/NtkDataParsingInterceptor.swift`
- Modify: `Sources/AlamofireClient/Client/AFJsonObjectParsingInterceptor.swift`

- [ ] **Step 2.1: Update NtkDeduplicationInterceptor**

In `NtkDeduplicationInterceptor.swift`, add a `priority` property:

```swift
struct NtkDeduplicationInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority { .outerHighest }
    // ... existing intercept method unchanged
}
```

- [ ] **Step 2.2: Update NtkCacheInterceptor**

In `NtkCacheInterceptor.swift`:
- Remove the `priority` parameter from both `init` overloads
- Change `public var priority: NtkInterceptorPriority` to be set to `.innerLow` in `init`

Result:
```swift
public struct NtkCacheInterceptor: iNtkInterceptor, iNtkCacheProvider {
    public var priority: NtkInterceptorPriority

    private let storage: any iNtkCacheStorage
    private let responseExtractor: ResponseExtractor

    public init(storage: any iNtkCacheStorage) {
        self.storage = storage
        self.priority = .innerLow
        self.responseExtractor = Self.defaultResponseExtractor
    }

    public init(storage: any iNtkCacheStorage, responseExtractor: @escaping ResponseExtractor) {
        self.storage = storage
        self.priority = .innerLow
        self.responseExtractor = responseExtractor
    }
    // ... rest of implementation unchanged
}
```

- [ ] **Step 2.3: Update NtkDataParsingInterceptor**

In `NtkDataParsingInterceptor.swift`, add a `priority` property to the struct:

```swift
public struct NtkDataParsingInterceptor<ResponseData: Sendable & Decodable, Keys: iNtkResponseMapKeys>: iNtkInterceptor {
    public var priority: NtkInterceptorPriority { .dataParsing }
    // ... existing init and intercept unchanged
}
```

- [ ] **Step 2.4: Update AFJsonObjectParsingInterceptor**

In `AFJsonObjectParsingInterceptor.swift`, add a `priority` property:

```swift
public struct AFJsonObjectParsingInterceptor<ResponseData: Sendable, Keys: iNtkResponseMapKeys>: iNtkInterceptor {
    public var priority: NtkInterceptorPriority { .dataParsing }
    // ... existing properties and methods unchanged
}
```

- [ ] **Step 2.5: Verify build**

```bash
swift build 2>&1 | grep -E 'error:|Build complete'
```

Expected: `Build complete!`

- [ ] **Step 2.6: Run all tests**

```bash
swift test --filter NtkInterceptorPriorityTests 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 2.7: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift \
        Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift \
        Sources/AlamofireClient/Client/NtkDataParsingInterceptor.swift \
        Sources/AlamofireClient/Client/AFJsonObjectParsingInterceptor.swift
git commit -m "feat: assign correct tier priorities to core interceptors"
```

---

## Task 3: Simplify NtkNetworkExecutor

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`

- [ ] **Step 3.1: Remove coreInterceptors from Configuration**

In `NtkNetworkExecutor.swift`, remove `var coreInterceptors: [iNtkInterceptor]` from `Configuration`:

```swift
struct Configuration {
    let client: any iNtkClient
    let request: NtkMutableRequest
    let interceptors: [iNtkInterceptor]
    let validation: iNtkResponseValidation
    let dataParsingInterceptor: iNtkInterceptor
}
```

- [ ] **Step 3.2: Simplify execute()**

Replace the `execute()` method body. Remove the separate `executionCoreInterceptors` assembly and just append the two core interceptors directly to `config.interceptors`:

```swift
func execute() async throws -> NtkResponse<ResponseData> {
    let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

    var allInterceptors = config.interceptors
    allInterceptors.append(NtkDeduplicationInterceptor())
    allInterceptors.append(config.dataParsingInterceptor)

    let allSorted = sortInterceptors(allInterceptors)
    // ... rest of method unchanged (chainManager creation, type cast, throw)
}
```

- [ ] **Step 3.3: Simplify loadCache()**

Replace the `loadCache()` method. Remove the separate `executionCoreInterceptors` assembly — only `dataParsingInterceptor` is needed:

```swift
func loadCache() async throws -> NtkResponse<ResponseData>? {
    guard let cacheProvider else { return nil }
    let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

    let realChainManager = NtkInterceptorChainManager(interceptors: [config.dataParsingInterceptor]) { [weak self] context in
        self?.mutableRequest = context.mutableRequest
        guard let cachedData = try await cacheProvider.loadCacheData(for: context.mutableRequest) else {
            throw NtkError.Cache.noCache
        }
        let response = NtkClientResponse(response: cachedData, request: context.mutableRequest, isCache: true)
        return response
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

- [ ] **Step 3.4: Simplify hasCacheData()**

Replace the `hasCacheData()` method body. No interceptor chain needed — call `cacheProvider` directly:

```swift
func hasCacheData() async -> Bool where ResponseData == Bool {
    guard let cacheProvider else { return false }
    return await cacheProvider.hasCacheData(for: mutableRequest)
}
```

- [ ] **Step 3.5: Verify build**

```bash
swift build 2>&1 | grep -E 'error:|Build complete'
```

Expected: may fail with errors in `NtkNetwork.swift` — this is resolved in Task 4. Proceed if the only errors are in that file.

- [ ] **Step 3.6: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift
git commit -m "refactor: simplify NtkNetworkExecutor — remove coreInterceptors, single sorted array"
```

---

## Task 4: Simplify NtkNetwork

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`

- [ ] **Step 4.1: Remove _coreInterceptors and addCoreInterceptor**

In `NtkNetwork.swift`:
- Delete `private var _coreInterceptors: [iNtkInterceptor] = []`
- Delete `fileprivate func addCoreInterceptor(_ i: iNtkInterceptor)` and its body

- [ ] **Step 4.2: Update getOrCreateExecutor()**

In the `getOrCreateExecutor()` method, remove `coreInterceptors: _coreInterceptors` from the `Configuration` initializer:

```swift
let config = NtkNetworkExecutor<ResponseData>.Configuration(
    client: client,
    request: mutableRequest,
    interceptors: _interceptors,
    validation: _validation,
    dataParsingInterceptor: dataParsingInterceptor
)
```

- [ ] **Step 4.3: Verify build**

```bash
swift build 2>&1 | grep -E 'error:|Build complete'
```

Expected: `Build complete!`

- [ ] **Step 4.4: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 4.5: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/NtkNetwork.swift
git commit -m "refactor: remove _coreInterceptors dual-array from NtkNetwork"
```

---

## Task 5: Add Tier-Ordering Integration Test

**Files:**
- Modify: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`

- [ ] **Step 5.1: Write tier-ordering test**

Append to `NtkInterceptorChainManagerTests`:

```swift
// MARK: - Tier 隔离：核心拦截器不被用户拦截器排挤

@Test
@NtkActor
func tierIsolationEnsuresCoreOrderingIsPreserved() async throws {
    // 安排：一个 outer 核心拦截器 + 一个高优先级用户拦截器 + 一个 inner 核心拦截器
    // 无论用户拦截器 value 多高，outer 永远在外，inner 永远在内
    let counter = ChainCallCounter()

    // outer tier (outerHighest = outer/1000)
    let outerCore = ChainTieredInterceptor(
        id: "outerCore",
        priority: .outerHighest,
        counter: counter
    )

    // standard tier, high value (high = standard/1000)
    let userHigh = ChainTieredInterceptor(
        id: "userHigh",
        priority: .high,
        counter: counter
    )

    // inner tier (innerHigh = inner/750)
    let innerCore = ChainTieredInterceptor(
        id: "innerCore",
        priority: .innerHigh,
        counter: counter
    )

    // 排序后顺序应为: outerCore → userHigh → innerCore
    let interceptors = [userHigh, innerCore, outerCore]  // 故意乱序传入
    let sorted = interceptors.sorted { $0.priority > $1.priority }
    let manager = NtkInterceptorChainManager(interceptors: sorted) { context in
        await counter.record("final")
        return ChainDummyResponse(request: ChainDummyRequest())
    }
    let context = makeContext()
    _ = try await manager.execute(context: context)
    let log = await counter.log()

    // 请求流: outerCore→userHigh→innerCore→final
    // 响应流: innerCore→userHigh→outerCore
    #expect(log == [
        "outerCore-request", "userHigh-request", "innerCore-request",
        "final",
        "innerCore-response", "userHigh-response", "outerCore-response"
    ])
}
```

Also add this helper struct near the other test helpers at the bottom of the file:

```swift
/// 带自定义优先级的记录拦截器
@NtkActor
private struct ChainTieredInterceptor: iNtkInterceptor {
    let id: String
    let priority: NtkInterceptorPriority
    let counter: ChainCallCounter

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record("\(id)-request")
        let response = try await next.handle(context: context)
        await counter.record("\(id)-response")
        return response
    }
}
```

- [ ] **Step 5.2: Run the new test to verify it passes**

```bash
swift test --filter tierIsolationEnsuresCoreOrderingIsPreserved 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 5.3: Run full test suite**

```bash
swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5.4: Commit**

```bash
git add Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift \
        Tests/CooNetworkTests/NtkInterceptorPriorityTests.swift
git commit -m "test: add tier isolation integration test for interceptor ordering"
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] `swift build` passes with no errors
- [ ] `swift test` passes with no failures
- [ ] `NtkInterceptorPriority` has no `public init(value:)` (removed)
- [ ] `NtkCacheInterceptor.init` has no `priority` parameter
- [ ] `NtkNetwork` has no `_coreInterceptors` property
- [ ] `NtkNetworkExecutor.Configuration` has no `coreInterceptors` field
