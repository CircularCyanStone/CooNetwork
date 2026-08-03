# Stable Request Identity Implementation Plan

> 历史执行记录：本文描述重命名前的方案和当时使用的命令，旧的 Identity、Participation、Canonical 等符号不代表当前 API，也不是现在要继续执行的步骤。当前代码请以 [Request Key 代码阅读路线](../../request-key-code-walkthrough.md) 和 [Request Key 命名设计](../specs/2026-08-03-request-key-naming-design.md) 为准。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将缓存配置与请求身份彻底分离，以确定性请求身份统一缓存键和去重键，并让动态 token、timestamp 等字段可以低成本地显式退出身份计算。

**Architecture:** `NtkRequestKeyBuilder` 在请求修改完成后，对策略投影执行确定性编码并生成 SHA-256 身份；executor 把同一次身份解析、有效 timeout 和精确响应类型冻结到只读 context。缓存直接消费请求身份，`NtkTaskManager` 只消费结构化去重身份并通过 instance ID 反向索引处理取消，不再读取请求配置或自行计算 key。

**Tech Stack:** Swift 6.1、Foundation、CryptoKit、Swift Package Manager、Swift Testing、actor 隔离、`os_unfair_lock`

**Approved design:** `docs/superpowers/specs/2026-08-02-request-identity-design.md`

---

## File Map

- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyRule.swift`: 字段参与身份计算的三态模型。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyPolicy.swift`: 全局/请求级身份投影策略。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKey.swift`: 可持久化但不透明的公开请求身份。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder.swift`: Header、参数、身份组成的投影与摘要生成。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder+Failure.swift`: 仅供框架内部降级和诊断的失败模型。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyEncoder.swift`: 带类型标签和长度前缀的确定性字节编码器。
- Create `Sources/CooNetwork/NtkNetwork/identity/NtkRequestTimeoutResolver.swift`: key 与实际超时共用的规范化入口。
- Create `Sources/CooNetwork/NtkNetwork/cache/NtkCacheConfiguration.swift`: 只负责缓存时长和写入判断。
- Create `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationKey.swift`: 当前进程内的结构化执行身份。
- Modify `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift`: 保存字段参与元数据、稳定身份组成和冻结 timeout。
- Modify `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`: 为身份编码器提供不发生标量类型转换的内部投影。
- Modify `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequest.swift`: 暴露独立的缓存配置和身份策略。
- Modify `Sources/CooNetwork/NtkNetwork/iNtk/iNtkCacheProvider.swift`: 显式接收框架生成的请求身份。
- Modify `Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift`: 增加全局默认身份策略。
- Modify `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`: 冻结配置快照、namespace，并按 instance ID 取消。
- Modify `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`: 请求修改后只解析一次身份与 timeout。
- Modify `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`: 携带内部只读执行身份。
- Modify `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`: 缓存写入消费 context 中的身份。
- Modify `Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift`: 直接使用身份 digest 作为缓存键。
- Modify `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift`: 把 context 的结构化身份交给任务管理器。
- Modify `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`: 只负责合并、timeout、取消和反向索引。
- Modify `Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift`: 只保留请求级去重开关。
- Delete `Sources/CooNetwork/NtkNetwork/cache/NtkRequestConfiguration.swift`: 删除缓存与身份耦合的旧配置。
- Delete `Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift`: 删除旧 MD5/Hasher/LRU 双轨 key 实现。
- Create `Tests/CooNetworkTests/NtkMutableRequestIdentityTests.swift`: 字段状态和身份组成测试。
- Create `Tests/CooNetworkTests/NtkRequestKeyEncoderTests.swift`: 标量、容器和 Foundation 值编码测试。
- Create `Tests/CooNetworkTests/NtkRequestKeyBuilderTests.swift`: 策略优先级、确定性和失败测试。
- Create `Tests/CooNetworkTests/NtkRequestTimeoutResolverTests.swift`: timeout 规范化测试。
- Create `Tests/CooNetworkTests/NtkRequestKeyBuilderPerformanceTests.swift`: 新规范化器性能基线。
- Delete `Tests/CooNetworkTests/NtkRequestIdentifierManagerTests.swift`: 旧 LRU 和双轨 key 测试已失去对象。
- Delete `Tests/CooNetworkTests/NtkRequestIdentifierManagerPerformanceTests.swift`: 删除针对旧 LRU 的对比测试。
- Modify `Tests/CooNetworkTests/NtkTaskManagerTests.swift`: 结构化 key、反向索引和取消测试。
- Modify `Tests/CooNetworkTests/NtkNetworkCacheTests.swift`: 身份显式传递测试。
- Modify `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`: 身份解析、缓存共享和失败降级测试。
- Modify `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`: 动态字段、namespace、类型和 timeout 端到端测试。
- Modify `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`: 缓存配置属性迁移。
- Modify `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`: 缓存配置属性迁移。
- Modify `README.md`, `docs/architecture.md`, `docs/design-decisions.md`, `docs/ntk-actor-audit.md`, `docs/ntk-request-modification-design.md`: 更新公开用法、架构不变量和仍在维护的设计说明。
- Modify relevant `CLAUDE.md` files under `Sources/CooNetwork/NtkNetwork/`: 更新模块所有权说明。

## Sequencing Constraint

Tasks 1-6 可以暂时保留旧 `NtkRequestConfiguration`，仅用于保持每个中间提交可编译；新代码不得再增加对它的依赖。Task 7 必须一次性删除旧类型、旧属性、旧标识管理器和全部生产/测试引用，最终产物不保留 deprecated bridge、typealias 或兼容转发。

### Task 1: 建立独立公开配置与字段身份元数据

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/cache/NtkCacheConfiguration.swift`
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyRule.swift`
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequest.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift`
- Test: `Tests/CooNetworkTests/NtkMutableRequestIdentityTests.swift`

- [ ] **Step 1: 写入公开默认值和字段状态失败测试**

创建 `Tests/CooNetworkTests/NtkMutableRequestIdentityTests.swift`：

```swift
import Foundation
import Testing
@testable import CooNetwork

struct NtkMutableRequestIdentityTests {
    @Test
    func headerHelpersUseCaseInsensitiveLogicalKeys() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addHeader(key: "Authorization", value: "first", identity: .exclude)
        request.addHeader(key: "authorization", value: "second", identity: .include)

        #expect(request.headers == ["authorization": "second"])
        #expect(request.requestKeyRule(forHeader: "AUTHORIZATION") == .include)

        request.removeHeader(key: "AUTHORIZATION")
        #expect(request.headers?.isEmpty == true)
        #expect(request.requestKeyRule(forHeader: "authorization") == .automatic)
    }

    @Test
    func parameterStateAndIdentityComponentsNeverEnterPayload() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addParameter(key: "timestamp", value: 123, identity: .exclude)
        request.addRequestKeyValue(key: "user", value: "42")

        #expect(request.parameters?["timestamp"] as? Int == 123)
        #expect(request.requestKeyRule(forParameter: "timestamp") == .exclude)
        #expect(request.requestKeyValues == ["user": "42"])
        #expect(request.extraData.isEmpty)
        #expect(request.headers == nil)
    }

    @Test
    func automaticClearsAnExplicitOverrideAndSetParameterReplacesMetadata() {
        var request = NtkMutableRequest(IdentityMetadataRequest())
        request.addParameter(key: "token", value: "a", identity: .exclude)
        request.addParameter(key: "token", value: "b", identity: .automatic)
        #expect(request.requestKeyRule(forParameter: "token") == .automatic)

        request.addParameter(key: "tenant", value: "coo", identity: .include)
        request.setParameter(["next": 1], identity: .exclude)
        #expect(request.requestKeyRule(forParameter: "tenant") == .automatic)
        #expect(request.requestKeyRule(forParameter: "next") == .exclude)
    }

    @Test
    func policyCanonicalizesOnlyHeaderNames() {
        let policy = NtkRequestKeyPolicy(
            excludedHeaderNames: ["Authorization"],
            excludedParameterNames: ["Token"]
        )
        #expect(policy.excludeHeaderNames == ["authorization"])
        #expect(policy.excludeParameterNames == ["Token"])
        #expect(NtkRequestKeyPolicy.strict.excludeHeaderNames.isEmpty)
    }

    @Test(arguments: [
        (30.0, true),
        (0.0, false),
        (-1.0, false),
        (Double.nan, false),
        (Double.infinity, false)
    ])
    func cacheConfigurationRequiresFinitePositiveDuration(
        cacheTime: TimeInterval,
        expected: Bool
    ) {
        #expect(NtkCacheConfiguration(cacheTime: cacheTime).isEnabled == expected)
    }
}

private struct IdentityMetadataRequest: iNtkRequest {
    var path: String { "/identity/metadata" }
}
```

- [ ] **Step 2: 运行测试确认新模型尚不存在**

Run:

```bash
swift test --filter NtkMutableRequestIdentityTests
```

Expected: 编译失败，缺少 `NtkRequestKeyRule`、`NtkRequestKeyPolicy`、`NtkCacheConfiguration` 和带 `identity` 参数的写入方法。

- [ ] **Step 3: 创建三个职责单一的公开模型**

按以下签名和注释语义创建三个文件。每个公开成员都要沿用这里的“适用场景 + 默认行为 + 安全影响”层次，不能缩成符号名称的翻译：

```swift
// NtkRequestKeyRule.swift
/// 控制单个请求字段是否参与缓存与去重共用的请求身份。
///
/// 该标记只改变本地身份投影，不会删除字段，也不会改变发送到服务端的请求。
/// `.automatic` 继承请求级或全局策略；`.include` 和 `.exclude` 用于显式覆盖策略。
public enum NtkRequestKeyRule: Sendable {
    /// 由有效的请求身份策略判断，适合没有特殊身份语义的普通字段。
    case automatic
    /// 强制参与身份，用于覆盖全局排除但实际区分资源或用户的字段。
    case included
    /// 强制退出身份，适合每次生成但不改变业务资源的 token、timestamp 或 nonce。
    case excluded
}

// NtkRequestKeyPolicy.swift
/// 定义 `.automatic` 字段如何投影为稳定请求身份。
///
/// 策略只作用于缓存键和去重键，不修改真实 Header 或参数。排除 Authorization 等
/// 凭证后，调用方必须通过未排除的稳定字段或 identity component 隔离 user/tenant，
/// 否则不同业务主体可能共享缓存或正在执行的请求。
public struct NtkRequestKeyPolicy: Sendable {
    /// 不参与身份的 Header 逻辑名称；构造时统一小写并按精确名称匹配。
    public let excludedHeaderNames: Set<String>
    /// 不参与身份的顶层参数 key；保持大小写并按精确 key 匹配。
    public let excludedParameterNames: Set<String>
    /// 对 `.automatic` Header 的高级纯函数投影；不会接触 included/excluded 字段。
    public let transformHeaders:
        (@Sendable ([String: String]) throws -> [String: String])?
    /// 对 `.automatic` 参数的高级纯函数投影；抛错会关闭本次缓存与去重。
    public let transformParameters:
        (@Sendable ([String: Sendable]) throws -> [String: Sendable])?

    /// 创建身份策略。闭包必须对相同输入返回相同输出，且不能读取时间、随机数或可变全局状态。
    public init(
        excludedHeaderNames: Set<String> = [],
        excludedParameterNames: Set<String> = [],
        transformHeaders: (@Sendable ([String: String]) throws -> [String: String])? = nil,
        transformParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])? = nil
    ) {
        self.excludeHeaderNames = Set(excludedHeaderNames.map { $0.lowercased() })
        self.excludeParameterNames = excludedParameterNames
        self.transformHeaders = transformHeaders
        self.transformParameters = transformParameters
    }

    /// 不排除、不转换任何字段的安全默认策略。
    public static let strict = Self()
}

// NtkCacheConfiguration.swift
/// 只描述响应缓存的有效期和写入资格，不参与请求身份计算。
///
/// `cacheTime` 只有在有限且大于零时才启用缓存读写；无效值安全地关闭缓存，
/// 但不会阻止网络请求。动态字段过滤必须使用 `NtkRequestKeyPolicy` 或字段标记。
public struct NtkCacheConfiguration: Sendable {
    /// 本次写入的缓存有效期；只有有限正数才启用缓存读写。
    public let cacheTime: TimeInterval
    /// 响应通过其他校验后决定是否写入缓存；不会参与缓存 key。
    public let shouldCache: @Sendable (any iNtkResponse) -> Bool

    /// 创建缓存配置；无效 cacheTime 安全关闭缓存，不抛错也不影响网络请求。
    public init(
        cacheTime: TimeInterval,
        shouldCache: @escaping @Sendable (any iNtkResponse) -> Bool = { _ in true }
    ) {
        self.cacheTime = cacheTime
        self.shouldCache = shouldCache
    }

    /// 创建 30 天有效期的常规缓存配置，不隐式排除任何身份字段。
    public static func `default`() -> Self {
        .init(cacheTime: 30 * 24 * 60 * 60)
    }

    /// 创建指定有效期的缓存配置；非有限正数会关闭缓存读写。
    public static func custom(duration: TimeInterval) -> Self {
        .init(cacheTime: duration)
    }

    var isEnabled: Bool {
        cacheTime.isFinite && cacheTime > 0
    }
}
```

- [ ] **Step 4: 扩展请求协议和全局配置**

在 `iNtkRequest` 增加并提供默认 `nil` 实现；旧 `requestConfiguration` 仅作为中间编译依赖保留到 Task 7：

```swift
/// 控制响应是否允许进入缓存；nil 表示本请求不读写缓存。
///
/// 该配置不负责过滤身份字段，cacheTime 和 shouldCache 也不会改变资源 key。
var cacheConfiguration: NtkCacheConfiguration? { get }

/// 覆盖本请求使用的身份投影策略；nil 表示继承 executor 创建时冻结的全局策略。
///
/// 非 nil 值完整替换全局策略而非合并。排除鉴权字段时必须保留稳定的业务主体隔离。
var requestKeyPolicy: NtkRequestKeyPolicy? { get }

public extension iNtkRequest {
    var cacheConfiguration: NtkCacheConfiguration? { nil }
    var requestKeyPolicy: NtkRequestKeyPolicy? { nil }
}
```

在 `NtkMutableRequest` 增加只读转发，使最终请求快照仍满足协议：

```swift
public var cacheConfiguration: NtkCacheConfiguration? {
    originalRequest.cacheConfiguration
}

public var requestKeyPolicy: NtkRequestKeyPolicy? {
    originalRequest.requestKeyPolicy
}
```

在 `NtkConfiguration.Builder` 增加：

```swift
/// 请求身份的全局默认投影规则。
///
/// 默认 `.strict` 不排除任何字段，防止框架在不知道用户和 tenant 语义时
/// 把不同业务主体的请求错误合并。应用应在启动阶段声明公共动态字段。
public var requestKeyPolicy: NtkRequestKeyPolicy = .strict
```

- [ ] **Step 5: 在 NtkMutableRequest 中实现元数据不变量**

增加私有存储和内部只读入口：

```swift
private var headerRequestKeyRules: [String: NtkRequestKeyRule] = [:]
private var parameterRequestKeyRules: [String: NtkRequestKeyRule] = [:]
private var storedRequestKeyValues: [String: String] = [:]

var requestKeyValues: [String: String] { storedRequestKeyValues }

func requestKeyRule(forHeader key: String) -> NtkRequestKeyRule {
    headerRequestKeyRules[key.lowercased()] ?? .automatic
}

func requestKeyRule(forParameter key: String) -> NtkRequestKeyRule {
    parameterRequestKeyRules[key] ?? .automatic
}

private mutating func setHeaderRequestKeyRule(
    _ participation: NtkRequestKeyRule,
    for key: String
) {
    let key = key.lowercased()
    if participation == .automatic {
        headerRequestKeyRules.removeValue(forKey: key)
    } else {
        headerRequestKeyRules[key] = participation
    }
}

private mutating func setParameterRequestKeyRule(
    _ participation: NtkRequestKeyRule,
    for key: String
) {
    if participation == .automatic {
        parameterRequestKeyRules.removeValue(forKey: key)
    } else {
        parameterRequestKeyRules[key] = participation
    }
}
```

把公开便捷方法统一改为带默认参数的实现，Header 批量输入先排序，所有 Header 查找和删除均使用大小写不敏感语义：

```swift
/// 写入一个 HTTP Header，并声明该逻辑字段如何参与缓存与去重共用的请求身份。
///
/// Header 名称按 HTTP 规则不区分大小写；写入前会删除大小写不同的同名旧键。
/// `identity` 默认 `.automatic`，由请求级或全局策略决定。该标记只影响本地身份，
/// Header 的真实值仍会发送到服务端；更新同名字段时，新状态完整替换旧状态。
public mutating func addHeader(
    key: String,
    value: String,
    identity: NtkRequestKeyRule = .automatic
) {
    if headers == nil { headers = [:] }
    let matchingKeys = headers?.keys.filter {
        $0.caseInsensitiveCompare(key) == .orderedSame
    } ?? []
    for existingKey in matchingKeys {
        headers?.removeValue(forKey: existingKey)
    }
    headers?[key] = value
    setHeaderRequestKeyRule(identity, for: key)
}

/// 按稳定 key 顺序批量写入 Header，并为每个字段应用同一身份状态。
///
/// 输入中存在大小写不同的同名键时，排序后的最后一个值确定性地生效；
/// 每个字段仍会发送到服务端，`identity` 只控制本地身份投影。
public mutating func addHeaders(
    _ newHeaders: [String: String],
    identity: NtkRequestKeyRule = .automatic
) {
    for key in newHeaders.keys.sorted() {
        addHeader(key: key, value: newHeaders[key]!, identity: identity)
    }
}

/// 写入请求参数，并声明该精确 key 如何参与缓存与去重共用的请求身份。
///
/// 参数 key 区分大小写。`.exclude` 适用于 timestamp、nonce 等不改变业务资源的
/// 动态值；排除 token 等凭证时必须另有稳定 user/tenant 身份，避免跨主体共享。
public mutating func addParameter(
    key: String,
    value: Sendable,
    identity: NtkRequestKeyRule = .automatic
) {
    if parameters == nil { parameters = [:] }
    parameters?[key] = value
    setParameterRequestKeyRule(identity, for: key)
}

/// 按稳定 key 顺序批量写入参数，并为每个精确 key 应用同一身份状态。
///
/// 参数和值仍会完整发送到服务端；该状态不会写入 parameters 或 extraData。
public mutating func addParameters(
    _ newParameters: [String: Sendable],
    identity: NtkRequestKeyRule = .automatic
) {
    for key in newParameters.keys.sorted() {
        addParameter(key: key, value: newParameters[key]!, identity: identity)
    }
}

/// 全量替换请求参数及其字段身份状态。
///
/// 旧参数的显式状态会全部删除，新参数统一使用传入状态；调用方仍需自行把需要保留的
/// 旧参数合并进 `newParameters`。该操作不会改变 Header 或稳定 identity component。
public mutating func setParameter(
    _ newParameters: [String: Sendable],
    identity: NtkRequestKeyRule = .automatic
) {
    parameters = newParameters
    parameterRequestKeyRules.removeAll()
    for key in newParameters.keys {
        setParameterRequestKeyRule(identity, for: key)
    }
}

/// 增加一个只参与本地身份、不发送到服务端的稳定业务组成。
///
/// 适合在排除 Authorization 等动态凭证后加入 userID 或 tenantID。相同 key 再次写入
/// 时最后一个值生效；key 区分大小写，值不会进入 Header、parameters 或 extraData。
public mutating func addRequestKeyValue(key: String, value: String) {
    storedRequestKeyValues[key] = value
}

/// 删除指定的稳定身份组成，不改变任何真实请求字段。
///
/// 删除后，请求可能与其他 user/tenant 产生相同身份；调用方必须确认剩余字段仍能
/// 表达正确的缓存和去重隔离边界。
public mutating func removeRequestKeyValue(key: String) {
    storedRequestKeyValues.removeValue(forKey: key)
}
```

删除和冻结清理使用以下实现：

```swift
/// 按大小写不敏感语义删除 Header，并同步删除其显式身份状态。
///
/// 如果公开 headers 字典中存在多个大小写不同的同名键，此方法会全部删除。
public mutating func removeHeader(key: String) {
    let matchingKeys = headers?.keys.filter {
        $0.caseInsensitiveCompare(key) == .orderedSame
    } ?? []
    for existingKey in matchingKeys {
        headers?.removeValue(forKey: existingKey)
    }
    headerRequestKeyRules.removeValue(forKey: key.lowercased())
}

/// 删除精确参数 key，并同步删除其显式身份状态。
public mutating func removeParameter(key: String) {
    parameters?.removeValue(forKey: key)
    parameterRequestKeyRules.removeValue(forKey: key)
}

/// 清空全部 Header 及其身份元数据，避免后续同名字段继承陈旧覆盖状态。
public mutating func clearHeaders() {
    headers = nil
    headerRequestKeyRules.removeAll()
}

/// 清空全部参数及其身份元数据，稳定 identity component 不受影响。
public mutating func clearParameters() {
    parameters = nil
    parameterRequestKeyRules.removeAll()
}

mutating func pruneIdentityMetadata() {
    let headerKeys = Set((headers ?? [:]).keys.map { $0.lowercased() })
    headerRequestKeyRules = headerRequestKeyRules.filter {
        headerKeys.contains($0.key)
    }
    let parameterKeys = Set((parameters ?? [:]).keys)
    parameterRequestKeyRules = parameterRequestKeyRules.filter {
        parameterKeys.contains($0.key)
    }
}
```

- [ ] **Step 6: 运行测试并提交**

Run:

```bash
swift test --filter NtkMutableRequestIdentityTests
```

Expected: PASS。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/cache/NtkCacheConfiguration.swift Sources/CooNetwork/NtkNetwork/identity Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequest.swift Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift Tests/CooNetworkTests/NtkMutableRequestIdentityTests.swift
git commit -m "feat: add request identity policy metadata"
```

### Task 2: 实现无歧义的确定性值编码器

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder.swift`
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder+Failure.swift`
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyEncoder.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Test: `Tests/CooNetworkTests/NtkRequestKeyEncoderTests.swift`

- [ ] **Step 1: 写入标量、容器和失败测试**

创建 `Tests/CooNetworkTests/NtkRequestKeyEncoderTests.swift`：

```swift
import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestKeyEncoderTests {
    @Test
    func dictionaryOrderDoesNotChangeBytes() throws {
        let lhs: [String: Sendable] = ["b": 2, "a": 1]
        let rhs: [String: Sendable] = ["a": 1, "b": 2]
        #expect(try NtkRequestKeyEncoder.encodeValue(lhs, path: "parameters") ==
                NtkRequestKeyEncoder.encodeValue(rhs, path: "parameters"))
    }

    @Test
    func typedSwiftContainersUseTheSameRecursiveEncoding() throws {
        let dictionary: any Sendable = ["a": 1, "b": 2]
        let array: any Sendable = [1, 2, 3]
        #expect(try !NtkRequestKeyEncoder.encodeValue(
            dictionary,
            path: "dictionary"
        ).isEmpty)
        #expect(try !NtkRequestKeyEncoder.encodeValue(
            array,
            path: "array"
        ).isEmpty)
    }

    @Test
    func arrayOrderAndScalarTypesRemainDistinct() throws {
        #expect(try NtkRequestKeyEncoder.encodeValue([1, 2], path: "array") !=
                NtkRequestKeyEncoder.encodeValue([2, 1], path: "array"))
        #expect(try NtkRequestKeyEncoder.encodeValue("1", path: "value") !=
                NtkRequestKeyEncoder.encodeValue(1, path: "value"))
        #expect(try NtkRequestKeyEncoder.encodeValue(1, path: "value") !=
                NtkRequestKeyEncoder.encodeValue(true, path: "value"))
    }

    @Test
    func foundationAndDynamicValuesAreStable() throws {
        let uuid = UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!
        let date = Date(timeIntervalSinceReferenceDate: 123.5)
        let value = NtkDynamicData(dictionary: [
            "uuid": uuid,
            "date": date,
            "data": Data([0, 1, 2]),
            "url": URL(string: "https://example.com/a?b=1")!,
            "null": NSNull()
        ])
        #expect(try NtkRequestKeyEncoder.encodeValue(value, path: "dynamic") ==
                NtkRequestKeyEncoder.encodeValue(value, path: "dynamic"))
    }

    @Test
    func nonFiniteAndUnsupportedValuesFailWithoutStringFallback() {
        #expect(throws: NtkRequestKeyBuilder.Failure.self) {
            try NtkRequestKeyEncoder.encodeValue(Double.nan, path: "parameters.score")
        }
        #expect(throws: NtkRequestKeyBuilder.Failure.self) {
            try NtkRequestKeyEncoder.encodeValue(
                UnsupportedIdentityValue(),
                path: "parameters.custom"
            )
        }
    }
}

private struct UnsupportedIdentityValue: Sendable {}
```

- [ ] **Step 2: 运行测试确认编码器缺失**

Run:

```bash
swift test --filter NtkRequestKeyEncoderTests
```

Expected: 编译失败，缺少编码器和内部失败类型。

- [ ] **Step 3: 创建内部失败模型**

创建 `NtkRequestKeyBuilder+Failure.swift`：

```swift
extension NtkRequestKeyBuilder {
    enum Section: String, Sendable {
        case headers
        case parameters
        case requestKeyValues
    }

    enum Failure: Error, Sendable, Equatable {
        case unsupportedValue(path: String, type: String)
        case nonFiniteValue(path: String, type: String)
        case normalizationFailed(section: Section, errorType: String)
        case invalidHeaderName(String)
        case duplicateNormalizedHeader(String)
        case projectionCollision(section: Section, key: String)

        var logMessage: String {
            switch self {
            case .unsupportedValue(let path, let type):
                return "unsupported value at \(path), type=\(type)"
            case .nonFiniteValue(let path, let type):
                return "non-finite value at \(path), type=\(type)"
            case .normalizationFailed(let section, let errorType):
                return "normalization failed in \(section.rawValue), errorType=\(errorType)"
            case .invalidHeaderName(let name):
                return "invalid header name at headers.\(name)"
            case .duplicateNormalizedHeader(let name):
                return "duplicate normalized header at headers.\(name)"
            case .projectionCollision(let section, let key):
                return "projection collision in \(section.rawValue).\(key)"
            }
        }
    }
}
```

在 `NtkRequestKeyBuilder.swift` 先放置空声明 `struct NtkRequestKeyBuilder {}`，Task 3 再补完整构建逻辑。

- [ ] **Step 4: 为 NtkDynamicData 暴露不转换类型的内部视图**

在同文件新增内部枚举和只读属性，必须直接 switch 私有 `storage`，不能调用会把整数转换成字符串的公开 getter：

```swift
enum NtkDynamicRequestKeyValue: Sendable {
    case dictionary([String: any Sendable])
    case array([any Sendable])
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
}

extension NtkDynamicData {
    var requestKeyValue: NtkDynamicRequestKeyValue {
        switch storage {
        case .dictionary(let value): .dictionary(value)
        case .array(let value): .array(value)
        case .string(let value): .string(value)
        case .int(let value): .int(value)
        case .double(let value): .double(value)
        case .bool(let value): .bool(value)
        case .null: .null
        }
    }
}
```

- [ ] **Step 5: 实现带标签和长度前缀的编码器**

创建 `NtkRequestKeyEncoder.swift`。实现必须使用固定 UInt8 tag、UInt64 big-endian 长度和排序后的 UTF-8 key；核心递归分派如下：

```swift
import Foundation

struct NtkRequestKeyEncoder {
    private enum Tag: UInt8 {
        case string = 1, boolFalse, boolTrue, signedInteger, unsignedInteger
        case float32, float64, data, url, uuid, date, null, dictionary, array
    }

    private var bytes = Data()

    static func encodeValue(_ value: any Sendable, path: String) throws -> Data {
        var encoder = Self()
        try encoder.appendValue(value, path: path)
        return encoder.bytes
    }

    mutating func appendField(tag: UInt8, payload: Data) {
        appendFrame(tag: tag, payload: payload)
    }

    mutating func appendStringField(tag: UInt8, value: String) {
        appendFrame(tag: tag, payload: Data(value.utf8))
    }

    mutating func appendOptionalStringField(tag: UInt8, value: String?) {
        var payload = Data([value == nil ? 0 : 1])
        if let value { payload.append(Data(value.utf8)) }
        appendFrame(tag: tag, payload: payload)
    }

    mutating func appendStringDictionaryField(tag: UInt8, value: [String: String]) {
        var payload = Data()
        payload.appendCount(value.count)
        for key in value.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            payload.appendLengthPrefixed(Data(value[key]!.utf8))
        }
        appendFrame(tag: tag, payload: payload)
    }

    mutating func appendValueDictionaryField(
        tag: UInt8,
        value: [String: any Sendable],
        path: String
    ) throws {
        appendFrame(tag: tag, payload: try Self.encodeDictionary(value, path: path))
    }

    var data: Data { bytes }

    private mutating func appendValue(_ value: any Sendable, path: String) throws {
        switch value {
        case let value as String:
            appendFrame(tag: Tag.string.rawValue, payload: Data(value.utf8))
        case let value as Bool:
            appendFrame(tag: (value ? Tag.boolTrue : Tag.boolFalse).rawValue, payload: Data())
        case let value as Int: appendSigned(Int64(value))
        case let value as Int8: appendSigned(Int64(value))
        case let value as Int16: appendSigned(Int64(value))
        case let value as Int32: appendSigned(Int64(value))
        case let value as Int64: appendSigned(value)
        case let value as UInt: appendUnsigned(UInt64(value))
        case let value as UInt8: appendUnsigned(UInt64(value))
        case let value as UInt16: appendUnsigned(UInt64(value))
        case let value as UInt32: appendUnsigned(UInt64(value))
        case let value as UInt64: appendUnsigned(value)
        case let value as Float:
            guard value.isFinite else { throw nonFinite(path, value) }
            appendFixedWidth(tag: .float32, value: value.bitPattern)
        case let value as Double:
            guard value.isFinite else { throw nonFinite(path, value) }
            appendFixedWidth(tag: .float64, value: value.bitPattern)
        case let value as Data:
            appendFrame(tag: Tag.data.rawValue, payload: value)
        case let value as URL:
            appendFrame(tag: Tag.url.rawValue, payload: Data(value.absoluteString.utf8))
        case let value as UUID:
            var raw = value.uuid
            appendFrame(tag: Tag.uuid.rawValue, payload: Swift.withUnsafeBytes(of: &raw) { Data($0) })
        case let value as Date:
            let interval = value.timeIntervalSinceReferenceDate
            guard interval.isFinite else { throw nonFinite(path, value) }
            appendFixedWidth(tag: .date, value: interval.bitPattern)
        case is NSNull:
            appendFrame(tag: Tag.null.rawValue, payload: Data())
        case let value as [String: any Sendable]:
            appendFrame(tag: Tag.dictionary.rawValue, payload: try Self.encodeDictionary(value, path: path))
        case let value as [any Sendable]:
            appendFrame(tag: Tag.array.rawValue, payload: try Self.encodeArray(value, path: path))
        case let value as NtkDynamicData:
            try appendDynamic(value.requestKeyValue, path: path)
        default:
            throw NtkRequestKeyBuilder.Failure.unsupportedValue(
                path: path,
                type: String(reflecting: type(of: value))
            )
        }
    }
}
```

同文件加入以下辅助实现；所有整数先转 big-endian，数组保留顺序，字典按 key 排序：

```swift
private extension NtkRequestKeyEncoder {
    mutating func appendFrame(tag: UInt8, payload: Data) {
        bytes.append(tag)
        bytes.appendLengthPrefixed(payload)
    }

    mutating func appendSigned(_ value: Int64) {
        appendFrame(
            tag: Tag.signedInteger.rawValue,
            payload: Data(String(value).utf8)
        )
    }

    mutating func appendUnsigned(_ value: UInt64) {
        appendFrame(
            tag: Tag.unsignedInteger.rawValue,
            payload: Data(String(value).utf8)
        )
    }

    mutating func appendFixedWidth<T: FixedWidthInteger>(tag: Tag, value: T) {
        var value = value.bigEndian
        let payload = Swift.withUnsafeBytes(of: &value) { Data($0) }
        appendFrame(tag: tag.rawValue, payload: payload)
    }

    static func encodeDictionary(
        _ dictionary: [String: any Sendable],
        path: String
    ) throws -> Data {
        var payload = Data()
        payload.appendCount(dictionary.count)
        for key in dictionary.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            payload.append(try encodeValue(dictionary[key]!, path: "\(path).\(key)"))
        }
        return payload
    }

    static func encodeArray(
        _ array: [any Sendable],
        path: String
    ) throws -> Data {
        var payload = Data()
        payload.appendCount(array.count)
        for (index, value) in array.enumerated() {
            payload.append(try encodeValue(value, path: "\(path)[\(index)]"))
        }
        return payload
    }

    mutating func appendDynamic(
        _ value: NtkDynamicRequestKeyValue,
        path: String
    ) throws {
        switch value {
        case .dictionary(let value):
            try appendValue(value, path: path)
        case .array(let value):
            try appendValue(value, path: path)
        case .string(let value):
            try appendValue(value, path: path)
        case .int(let value):
            try appendValue(value, path: path)
        case .double(let value):
            try appendValue(value, path: path)
        case .bool(let value):
            try appendValue(value, path: path)
        case .null:
            try appendValue(NSNull(), path: path)
        }
    }

    func nonFinite<T>(_ path: String, _ value: T) -> NtkRequestKeyBuilder.Failure {
        .nonFiniteValue(path: path, type: String(reflecting: type(of: value)))
    }
}

private extension Data {
    mutating func appendCount(_ count: Int) {
        appendUInt64(UInt64(count))
    }

    mutating func appendLengthPrefixed(_ value: Data) {
        appendUInt64(UInt64(value.count))
        append(value)
    }

    mutating func appendUInt64(_ value: UInt64) {
        var value = value.bigEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
```

不得使用 `String(describing:)` 编码值，不得用分隔符拼接，也不得用 `Mirror` 绕过受支持类型白名单。

- [ ] **Step 6: 运行测试并提交**

Run:

```bash
swift test --filter NtkRequestKeyEncoderTests
```

Expected: PASS。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/identity Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift Tests/CooNetworkTests/NtkRequestKeyEncoderTests.swift
git commit -m "feat: add deterministic identity encoding"
```

### Task 3: 构建统一请求身份投影

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKey.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestKeyBuilder+Failure.swift`
- Test: `Tests/CooNetworkTests/NtkRequestKeyBuilderTests.swift`

- [ ] **Step 1: 写入策略优先级和确定性失败测试**

创建 `Tests/CooNetworkTests/NtkRequestKeyBuilderTests.swift`，先写入以下主路径测试：

```swift
import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestKeyBuilderTests {
    @Test
    func excludedDynamicFieldsProduceOneIdentity() throws {
        var first = makeRequest(token: "token-a", timestamp: 1)
        first.addHeader(key: "Authorization", value: "token-a", identity: .exclude)
        first.addParameter(key: "timestamp", value: 1, identity: .exclude)
        first.addRequestKeyValue(key: "user", value: "42")

        var second = makeRequest(token: "token-b", timestamp: 2)
        second.addHeader(key: "authorization", value: "token-b", identity: .exclude)
        second.addParameter(key: "timestamp", value: 2, identity: .exclude)
        second.addRequestKeyValue(key: "user", value: "42")

        #expect(try NtkRequestKeyBuilder.build(request: first, policy: .strict) ==
                NtkRequestKeyBuilder.build(request: second, policy: .strict))
    }

    @Test
    func includedOverridesGlobalExclusionAndUserComponentSeparatesUsers() throws {
        let policy = NtkRequestKeyPolicy(excludedParameterNames: ["tenant"])
        var first = makeRequest()
        first.addParameter(key: "tenant", value: "a", identity: .include)
        first.addRequestKeyValue(key: "user", value: "1")
        var second = makeRequest()
        second.addParameter(key: "tenant", value: "b", identity: .include)
        second.addRequestKeyValue(key: "user", value: "2")

        #expect(try NtkRequestKeyBuilder.build(request: first, policy: policy) !=
                NtkRequestKeyBuilder.build(request: second, policy: policy))
    }

    @Test
    func headerCaseAndDictionaryInsertionOrderDoNotChangeIdentity() throws {
        var first = makeRequest()
        first.addHeader(key: "X-CLIENT", value: "ios")
        first.setParameter(["outer": ["b": 2, "a": 1] as [String: Sendable]])
        var second = makeRequest()
        second.addHeader(key: "x-client", value: "ios")
        second.setParameter(["outer": ["a": 1, "b": 2] as [String: Sendable]])

        #expect(try NtkRequestKeyBuilder.build(request: first, policy: .strict) ==
                NtkRequestKeyBuilder.build(request: second, policy: .strict))
    }

    @Test
    func normalizerCannotSeeExplicitFieldsAndCollisionFails() throws {
        let policy = NtkRequestKeyPolicy(transformParameters: { parameters in
            #expect(parameters["secret"] == nil)
            return ["stable": "from-normalizer"]
        })
        var request = makeRequest()
        request.addParameter(key: "secret", value: "value", identity: .exclude)
        request.addParameter(key: "stable", value: "included", identity: .include)

        #expect(throws: NtkRequestKeyBuilder.Failure.self) {
            try NtkRequestKeyBuilder.build(request: request, policy: policy)
        }
    }

    @Test
    func unsupportedValueReturnsInternalFailure() {
        var request = makeRequest()
        request.addParameter(key: "custom", value: UnsupportedIdentityParameter())
        #expect(throws: NtkRequestKeyBuilder.Failure.self) {
            try NtkRequestKeyBuilder.build(request: request, policy: .strict)
        }
    }

    private func makeRequest(token: String = "token", timestamp: Int = 0) -> NtkMutableRequest {
        var request = NtkMutableRequest(IdentityBuilderRequest())
        request.addHeader(key: "Content-Type", value: "application/json")
        request.addParameter(key: "token", value: token)
        request.addParameter(key: "timestamp", value: timestamp)
        return request
    }
}

private struct IdentityBuilderRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/identity/build" }
    var method: NtkHTTPMethod { .post }
}

private struct UnsupportedIdentityParameter: Sendable {}
```

在同一个 test struct 内加入以下边界测试，完整覆盖精确匹配、空集合、容器顺序、Foundation 值、闭包失败和重复 Header：

```swift
@Test
func excludedParameterNamesAreCaseSensitiveExactMatches() throws {
    let policy = NtkRequestKeyPolicy(excludedParameterNames: ["token"])
    var first = NtkMutableRequest(IdentityBuilderRequest())
    first.setParameter(["token": "a", "Token": "A", "tokenValue": "one"])
    var second = NtkMutableRequest(IdentityBuilderRequest())
    second.setParameter(["token": "b", "Token": "A", "tokenValue": "one"])
    #expect(try NtkRequestKeyBuilder.build(request: first, policy: policy) ==
            NtkRequestKeyBuilder.build(request: second, policy: policy))

    second.addParameter(key: "tokenValue", value: "two")
    #expect(try NtkRequestKeyBuilder.build(request: first, policy: policy) !=
            NtkRequestKeyBuilder.build(request: second, policy: policy))
}

@Test
func nilAndEmptyCollectionsHaveOneIdentity() throws {
    let nilCollections = NtkMutableRequest(IdentityBuilderRequest())
    var emptyCollections = NtkMutableRequest(IdentityBuilderRequest())
    emptyCollections.headers = [:]
    emptyCollections.parameters = [:]
    #expect(try NtkRequestKeyBuilder.build(request: nilCollections, policy: .strict) ==
            NtkRequestKeyBuilder.build(request: emptyCollections, policy: .strict))
}

@Test
func arrayOrderAndScalarTypesChangeIdentity() throws {
    var first = NtkMutableRequest(IdentityBuilderRequest())
    first.setParameter(["value": [1, 2] as [any Sendable]])
    var reordered = NtkMutableRequest(IdentityBuilderRequest())
    reordered.setParameter(["value": [2, 1] as [any Sendable]])
    var stringValue = NtkMutableRequest(IdentityBuilderRequest())
    stringValue.setParameter(["value": "1"])
    var booleanValue = NtkMutableRequest(IdentityBuilderRequest())
    booleanValue.setParameter(["value": true])

    let integerIdentity = try NtkRequestKeyBuilder.build(request: first, policy: .strict)
    #expect(integerIdentity != NtkRequestKeyBuilder.build(request: reordered, policy: .strict))
    #expect(integerIdentity != NtkRequestKeyBuilder.build(request: stringValue, policy: .strict))
    #expect(integerIdentity != NtkRequestKeyBuilder.build(request: booleanValue, policy: .strict))
}

@Test
func supportedFoundationAndDynamicValuesRepeatExactly() throws {
    var request = NtkMutableRequest(IdentityBuilderRequest())
    request.setParameter([
        "data": Data([1, 2, 3]),
        "url": URL(string: "https://example.com/resource")!,
        "uuid": UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!,
        "date": Date(timeIntervalSinceReferenceDate: 123),
        "null": NSNull(),
        "dynamic": NtkDynamicData(array: [1, "two", NSNull()])
    ])
    let first = try NtkRequestKeyBuilder.build(request: request, policy: .strict)
    let second = try NtkRequestKeyBuilder.build(request: request, policy: .strict)
    #expect(first == second)
}

@Test
func normalizationFailureStoresOnlyErrorType() {
    let policy = NtkRequestKeyPolicy(transformParameters: { _ in
        throw IdentityNormalizerError.containsSensitiveDescription
    })
    let request = NtkMutableRequest(IdentityBuilderRequest())
    do {
        _ = try NtkRequestKeyBuilder.build(request: request, policy: policy)
        Issue.record("期望规范化失败")
    } catch let failure as NtkRequestKeyBuilder.Failure {
        guard case .normalizationFailed(.parameters, let errorType) = failure else {
            Issue.record("错误类型不符: \(failure)")
            return
        }
        #expect(errorType.contains("IdentityNormalizerError"))
        #expect(!errorType.contains("secret-value"))
    } catch {
        Issue.record("错误类型不符: \(error)")
    }
}

@Test
func duplicateCaseInsensitiveHeadersFailIdentityOnly() {
    var request = NtkMutableRequest(IdentityBuilderRequest())
    request.headers = ["Authorization": "a", "authorization": "b"]
    #expect(throws: NtkRequestKeyBuilder.Failure.self) {
        try NtkRequestKeyBuilder.build(request: request, policy: .strict)
    }
}

@Test
func headerExclusionIsCaseInsensitiveAndExact() throws {
    let policy = NtkRequestKeyPolicy(excludedHeaderNames: ["Authorization"])
    var first = NtkMutableRequest(IdentityBuilderRequest())
    first.headers = ["authorization": "a", "Authorization-Mode": "stable"]
    var second = NtkMutableRequest(IdentityBuilderRequest())
    second.headers = ["AUTHORIZATION": "b", "Authorization-Mode": "stable"]
    #expect(try NtkRequestKeyBuilder.build(request: first, policy: policy) ==
            NtkRequestKeyBuilder.build(request: second, policy: policy))

    second.headers?["Authorization-Mode"] = "changed"
    #expect(try NtkRequestKeyBuilder.build(request: first, policy: policy) !=
            NtkRequestKeyBuilder.build(request: second, policy: policy))
}

@Test
func cacheTimeAndTimeoutDoNotChangeResourceIdentity() throws {
    let first = NtkMutableRequest(IdentityBuilderConfiguredRequest(
        timeout: 10,
        cacheTime: 60
    ))
    let second = NtkMutableRequest(IdentityBuilderConfiguredRequest(
        timeout: 20,
        cacheTime: 3_600
    ))
    #expect(try NtkRequestKeyBuilder.build(request: first, policy: .strict) ==
            NtkRequestKeyBuilder.build(request: second, policy: .strict))
}
```

在文件底部定义错误，其描述故意包含敏感文本，以验证 builder 不保存该描述：

```swift
private enum IdentityNormalizerError: Error, CustomStringConvertible {
    case containsSensitiveDescription
    var description: String { "secret-value" }
}

private struct IdentityBuilderConfiguredRequest: iNtkRequest {
    let timeout: TimeInterval
    let cacheTime: TimeInterval
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/identity/config-independent" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? {
        .custom(duration: cacheTime)
    }
}
```

- [ ] **Step 2: 运行测试确认 builder 尚未实现**

Run:

```bash
swift test --filter NtkRequestKeyBuilderTests
```

Expected: 编译失败，缺少 `NtkRequestKey` 和 `build(request:policy:)`。

- [ ] **Step 3: 创建公开但不可自行构造的身份值**

创建 `NtkRequestKey.swift`，完整文档必须声明 digest 可存储、不可解析、算法版本可能升级：

```swift
/// 框架根据最终请求投影生成的稳定身份。
///
/// 自定义缓存 provider 可以存储和比较该值，但不能自行构造或解析 digest。
/// 算法升级会改变前缀和内容，旧缓存由现有淘汰策略自然清理。
public struct NtkRequestKey: Hashable, Sendable {
    /// 包含算法版本的持久化缓存键；它不是业务字段，也不应作为鉴权凭证。
    public let digest: String

    init(digest: String) {
        self.digest = digest
    }
}
```

- [ ] **Step 4: 实现字段投影和 SHA-256 摘要**

在 `NtkRequestKeyBuilder.swift` 使用 `CryptoKit` 实现：

```swift
import CryptoKit
import Foundation

struct NtkRequestKeyBuilder {
    static func build(
        request: NtkMutableRequest,
        policy: NtkRequestKeyPolicy
    ) throws -> NtkRequestKey {
        let headers = try projectHeaders(request: request, policy: policy)
        let parameters = try projectParameters(request: request, policy: policy)

        var encoder = NtkRequestKeyEncoder()
        encoder.appendStringField(tag: 1, value: request.method.rawValue)
        encoder.appendOptionalStringField(tag: 2, value: request.baseURL?.absoluteString)
        encoder.appendStringField(tag: 3, value: request.path)
        encoder.appendStringDictionaryField(tag: 4, value: headers)
        try encoder.appendValueDictionaryField(tag: 5, value: parameters, path: "parameters")
        encoder.appendStringDictionaryField(tag: 6, value: request.requestKeyValues)

        let digest = SHA256.hash(data: encoder.data)
            .map { String(format: "%02x", $0) }
            .joined()
        return NtkRequestKey(digest: "ntk-identity-v2-\(digest)")
    }
}
```

同文件使用以下投影实现，固定“字段状态拆分 -> 名称排除 -> normalizer -> included 合并”的顺序：

```swift
private extension NtkRequestKeyBuilder {
    static func projectHeaders(
        request: NtkMutableRequest,
        policy: NtkRequestKeyPolicy
    ) throws -> [String: String] {
        var included: [String: String] = [:]
        var automatic: [String: String] = [:]

        for (key, value) in request.headers ?? [:] {
            switch request.requestKeyRule(forHeader: key) {
            case .exclude:
                continue
            case .include:
                included[key] = value
            case .automatic:
                if !policy.excludeHeaderNames.contains(key.lowercased()) {
                    automatic[key] = value
                }
            }
        }

        let normalized: [String: String]
        do {
            normalized = try policy.transformHeaders?(automatic) ?? automatic
        } catch {
            throw Failure.normalizationFailed(
                section: .headers,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = normalized
        let normalizedKeys = Set(normalized.keys.map { $0.lowercased() })
        for (key, value) in included {
            guard !normalizedKeys.contains(key.lowercased()) else {
                throw Failure.projectionCollision(section: .headers, key: key)
            }
            merged[key] = value
        }

        var canonical: [String: String] = [:]
        for (key, value) in merged {
            guard isValidHeaderName(key) else {
                throw Failure.invalidHeaderName(key)
            }
            let canonicalKey = key.lowercased()
            guard canonical[canonicalKey] == nil else {
                throw Failure.duplicateNormalizedHeader(canonicalKey)
            }
            canonical[canonicalKey] = value
        }
        return canonical
    }

    static func projectParameters(
        request: NtkMutableRequest,
        policy: NtkRequestKeyPolicy
    ) throws -> [String: any Sendable] {
        var included: [String: any Sendable] = [:]
        var automatic: [String: any Sendable] = [:]

        for (key, value) in request.parameters ?? [:] {
            switch request.requestKeyRule(forParameter: key) {
            case .exclude:
                continue
            case .include:
                included[key] = value
            case .automatic:
                if !policy.excludeParameterNames.contains(key) {
                    automatic[key] = value
                }
            }
        }

        let normalized: [String: any Sendable]
        do {
            normalized = try policy.transformParameters?(automatic) ?? automatic
        } catch {
            throw Failure.normalizationFailed(
                section: .parameters,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = normalized
        for (key, value) in included {
            guard merged[key] == nil else {
                throw Failure.projectionCollision(section: .parameters, key: key)
            }
            merged[key] = value
        }
        return merged
    }

    static func isValidHeaderName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let punctuation = Set("!#$%&'*+-.^_`|~".utf8)
        return name.utf8.allSatisfy {
            $0 <= 127 && (
                (48...57).contains($0) ||
                (65...90).contains($0) ||
                (97...122).contains($0) ||
                punctuation.contains($0)
            )
        }
    }
}
```

闭包抛错只保留 `String(reflecting: type(of: error))`，不保存或记录 error description。

- [ ] **Step 5: 运行身份与编码器测试并提交**

Run:

```bash
swift test --filter 'NtkRequestKeyBuilderTests|NtkRequestKeyEncoderTests|NtkMutableRequestIdentityTests'
```

Expected: PASS，digest 以 `ntk-identity-v2-` 开头。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/identity Tests/CooNetworkTests/NtkRequestKeyBuilderTests.swift
git commit -m "feat: build stable request identities"
```

### Task 4: 统一有效 timeout 与结构化去重身份

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/identity/NtkRequestTimeoutResolver.swift`
- Create: `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationKey.swift`
- Test: `Tests/CooNetworkTests/NtkRequestTimeoutResolverTests.swift`

- [ ] **Step 1: 写入 timeout 规范化测试**

创建测试文件：

```swift
import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestTimeoutResolverTests {
    @Test(arguments: [1.0, 20.0, 100.5])
    func finitePositiveRequestTimeoutWins(_ value: TimeInterval) {
        #expect(NtkRequestTimeoutResolver.resolve(requested: value, configuredDefault: 30) == value)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func invalidRequestTimeoutUsesConfiguredDefault(_ value: TimeInterval) {
        #expect(NtkRequestTimeoutResolver.resolve(requested: value, configuredDefault: 30) == 30)
    }

    @Test
    func invalidDefaultUsesBuiltInValueAndAllValuesAreClamped() {
        #expect(NtkRequestTimeoutResolver.resolve(requested: .nan, configuredDefault: -1) == 20)
        #expect(NtkRequestTimeoutResolver.resolve(
            requested: 4_000_000_000,
            configuredDefault: 20
        ) == 3_153_600_000)
    }
}
```

- [ ] **Step 2: 运行测试确认 resolver 缺失**

Run `swift test --filter NtkRequestTimeoutResolverTests`。

Expected: 编译失败。

- [ ] **Step 3: 实现 resolver 和去重身份**

```swift
enum NtkRequestTimeoutResolver {
    static let builtInDefault: TimeInterval = 20
    static let maximum: TimeInterval = 3_153_600_000

    static func resolve(
        requested: TimeInterval,
        configuredDefault: TimeInterval
    ) -> TimeInterval {
        let candidate: TimeInterval
        if requested.isFinite && requested > 0 {
            candidate = requested
        } else if configuredDefault.isFinite && configuredDefault > 0 {
            candidate = configuredDefault
        } else {
            candidate = builtInDefault
        }
        return min(candidate, maximum)
    }
}

struct NtkDeduplicationKey: Hashable, Sendable {
    let requestKey: NtkRequestKey
    let responseType: ObjectIdentifier
    let effectiveTimeout: TimeInterval
    let namespace: String
}
```

- [ ] **Step 4: 运行测试并提交**

Run `swift test --filter NtkRequestTimeoutResolverTests`。

Expected: PASS。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/identity/NtkRequestTimeoutResolver.swift Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationKey.swift Tests/CooNetworkTests/NtkRequestTimeoutResolverTests.swift
git commit -m "feat: normalize request execution identity"
```

### Task 5: 在 executor 中冻结并传递一次身份解析

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 写入快照、类型和失败降级测试**

在 `NtkNetworkExecutorTests` 增加测试，使用内部 `Configuration(globalConfiguration:deduplicationNamespace:)` 注入独立配置快照，避免修改进程全局状态：

```swift
@Test
func executorFreezesPolicyTimeoutAndNamespace() async throws {
    var builder = NtkConfiguration.Builder()
    builder.defaultTimeout = 45
    builder.requestKeyPolicy = .init(excludedParameterNames: ["timestamp"])
    let global = NtkConfiguration(builder: builder)
    let capture = ExecPreparedContextCapture()
    var request = NtkMutableRequest(ExecSnapshotRequest(timeout: .nan))
    request.addParameter(key: "timestamp", value: 123)
    let expectedIdentity = try NtkRequestKeyBuilder.build(
        request: request,
        policy: builder.requestKeyPolicy
    )
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecPreparedContextInterceptor(capture: capture)
        ],
        globalConfiguration: global,
        deduplicationNamespace: "account-a"
    )

    _ = try await NtkNetworkExecutor<Bool>(config: config).execute()

    #expect(await capture.effectiveTimeout() == 45)
    #expect(await capture.namespace() == "account-a")
    #expect(await capture.responseType() == ObjectIdentifier(Bool.self))
    #expect(await capture.requestKey() == expectedIdentity)
}

@Test
func unsupportedIdentityValueKeepsNetworkAvailableAndDisablesSharing() async throws {
    let capture = ExecPreparedContextCapture()
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/identity-failure"))
    request.addParameter(key: "custom", value: UnsupportedExecIdentityValue())
    let executor = makeExecutorCapturingPreparedContext(request: request, capture: capture)

    let response = try await executor.execute()

    #expect(response.data == true)
    #expect(await capture.requestKey() == nil)
    #expect(await capture.deduplicationKey() == nil)
}

@Test
func requestLevelPolicyCompletelyReplacesGlobalPolicy() async throws {
    var builder = NtkConfiguration.Builder()
    builder.requestKeyPolicy = .init(excludedParameterNames: ["tenant"])
    let global = NtkConfiguration(builder: builder)
    let capture = ExecPreparedContextCapture()
    var request = NtkMutableRequest(ExecSnapshotRequest(
        timeout: 30,
        requestKeyPolicy: .strict
    ))
    request.addParameter(key: "tenant", value: "a")
    let expected = try NtkRequestKeyBuilder.build(request: request, policy: .strict)
    let executor = NtkNetworkExecutor<Bool>(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecPreparedContextInterceptor(capture: capture)
        ],
        globalConfiguration: global
    ))

    _ = try await executor.execute()

    #expect(await capture.requestKey() == expected)
}
```

测试捕获器读取 context 的 internal 字段；`UnsupportedExecIdentityValue` 是空 `Sendable` struct。

在测试替身区域加入完整捕获器和 interceptor：

```swift
private actor ExecPreparedContextCapture {
    private var context: NtkInterceptorContext?

    func record(_ context: NtkInterceptorContext) { self.context = context }
    func effectiveTimeout() -> TimeInterval? { context?.effectiveTimeout }
    func namespace() -> String? { context?.deduplicationKey?.namespace }
    func responseType() -> ObjectIdentifier? { context?.deduplicationKey?.responseType }
    func requestKey() -> NtkRequestKey? { context?.requestKey }
    func deduplicationKey() -> NtkDeduplicationKey? {
        context?.deduplicationKey
    }
}

private struct ExecPreparedContextInterceptor: iNtkInterceptor {
    let capture: ExecPreparedContextCapture

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await capture.record(context)
        return try await next.handle(context: context)
    }
}

private struct ExecSnapshotRequest: iNtkRequest {
    let timeout: TimeInterval
    let requestKeyPolicy: NtkRequestKeyPolicy?
    var path: String { "/executor/snapshot" }

    init(
        timeout: TimeInterval,
        requestKeyPolicy: NtkRequestKeyPolicy? = nil
    ) {
        self.timeout = timeout
        self.requestKeyPolicy = requestKeyPolicy
    }
}

private struct UnsupportedExecIdentityValue: Sendable {}

private func makeExecutorCapturingPreparedContext(
    request: NtkMutableRequest,
    capture: ExecPreparedContextCapture
) -> NtkNetworkExecutor<Bool> {
    NtkNetworkExecutor(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecPreparedContextInterceptor(capture: capture)
        ]
    ))
}
```

- [ ] **Step 2: 运行测试确认 context 尚无执行身份**

Run `swift test --filter NtkNetworkExecutorTests`。

Expected: 编译失败，缺少配置初始化器和 context 身份字段。

- [ ] **Step 3: 让可变请求持有冻结 timeout**

把 `NtkMutableRequest.timeout` 改为 `public internal(set) var timeout: TimeInterval`，初始化时读取原请求。增加内部方法，在 executor 配置创建时刷新请求级计算属性并在最终准备时写入规范化 timeout：

```swift
mutating func refreshConfigurationSnapshot() {
    timeout = originalRequest.timeout
}

mutating func applyEffectiveTimeout(_ value: TimeInterval) {
    timeout = value
}
```

这样 TaskManager 的 framework timeout 和 `AFClient` 读取的 request timeout 使用同一值；请求修改器仍不能随意改变 timeout。

- [ ] **Step 4: 扩展不可变 context 和 executor Configuration**

```swift
public struct NtkInterceptorContext: Sendable {
    public let request: NtkMutableRequest
    public var extraData: [String: any Sendable]

    let requestKey: NtkRequestKey?
    let deduplicationKey: NtkDeduplicationKey?
    let effectiveTimeout: TimeInterval

    init(
        request: NtkMutableRequest,
        requestKey: NtkRequestKey? = nil,
        deduplicationKey: NtkDeduplicationKey? = nil,
        effectiveTimeout: TimeInterval = NtkRequestTimeoutResolver.builtInDefault,
        extraData: [String: any Sendable] = [:]
    ) {
        self.request = request
        self.requestKey = requestKey
        self.deduplicationKey = deduplicationKey
        self.effectiveTimeout = effectiveTimeout
        self.extraData = extraData
    }
}
```

`NtkNetworkExecutor.Configuration` 增加以下自定义初始化器；请求级 policy 非空时完整替换全局 policy：

```swift
struct Configuration: Sendable {
    let client: any iNtkClient
    let request: NtkMutableRequest
    let interceptors: [any iNtkInterceptor]
    let requestKeyPolicy: NtkRequestKeyPolicy
    let isDeduplicationEnabled: Bool
    let defaultTimeout: TimeInterval
    let deduplicationNamespace: String

    init(
        client: any iNtkClient,
        request: NtkMutableRequest,
        interceptors: [any iNtkInterceptor],
        globalConfiguration: NtkConfiguration = .current,
        deduplicationNamespace: String = "default"
    ) {
        var request = request
        request.refreshConfigurationSnapshot()
        let builder = globalConfiguration.builder
        self.client = client
        self.request = request
        self.interceptors = interceptors
        self.requestKeyPolicy = request.requestKeyPolicy ?? builder.requestKeyPolicy
        self.isDeduplicationEnabled = builder.isDeduplicationEnabled
        self.defaultTimeout = builder.defaultTimeout
        self.deduplicationNamespace = deduplicationNamespace
    }
}
```

- [ ] **Step 5: 在修改器完成后只准备一次 context**

新增统一入口并让 `execute()`、`loadCache()`、`hasCacheData()` 使用它：

```swift
private func makeContext(
    includeDeduplication: Bool,
    includeCache: Bool
) async throws -> NtkInterceptorContext {
    var request = try await makeRequest()
    request.pruneIdentityMetadata()
    let effectiveTimeout = NtkRequestTimeoutResolver.resolve(
        requested: request.timeout,
        configuredDefault: config.defaultTimeout
    )
    request.applyEffectiveTimeout(effectiveTimeout)

    let deduplicationEnabled = includeDeduplication &&
        config.isDeduplicationEnabled && request.isDeduplicationEnabled
    let cacheEnabled = includeCache && request.cacheConfiguration?.isEnabled == true
    let identity: NtkRequestKey?
    if deduplicationEnabled || cacheEnabled {
        do {
            identity = try NtkRequestKeyBuilder.build(
                request: request,
                policy: config.requestKeyPolicy
            )
        } catch let failure as NtkRequestKeyBuilder.Failure {
            logger.warning(
                "Request identity unavailable: \(failure.logMessage)",
                category: .identity
            )
            identity = nil
        }
    } else {
        identity = nil
    }

    let deduplicationKey = deduplicationEnabled ? identity.map {
        NtkDeduplicationKey(
            requestKey: $0,
            responseType: ObjectIdentifier(ResponseData.self),
            effectiveTimeout: effectiveTimeout,
            namespace: config.deduplicationNamespace
        )
    } : nil

    return NtkInterceptorContext(
        request: request,
        requestKey: identity,
        deduplicationKey: deduplicationKey,
        effectiveTimeout: effectiveTimeout
    )
}
```

`execute()` 的原始 `makeRequest()` + context 初始化替换为：

```swift
let context = try await makeContext(
    includeDeduplication: true,
    includeCache: cacheProvider != nil
)
```

Task 7 再把缓存 provider 调用改为显式接收 `context.requestKey`；在此之前旧缓存读取签名继续编译，但不能新增任何旧 key 计算。

为 logger 增加 `.identity` category。用户输入导致的 Failure 只能 warning 并返回 nil，不得 assertion、throw 或记录参数值。

- [ ] **Step 6: 在 NtkNetwork 中加入 namespace 配置快照**

增加锁保护属性和完整公开注释：

```swift
private var _deduplicationNamespace = "default"

/// 设置当前执行流水线的去重命名空间。
///
/// 相同 namespace 表示调用方承诺 client、parser、validation、retry 和响应处理语义
/// 可以共享最终结果。默认 `"default"` 保持普通调用零配置；不同流水线必须显式隔离。
/// 该值按原字符串精确比较，只影响 executor 创建前的配置快照。
///
/// - Parameter namespace: 不做大小写或空白归一化的执行隔离名称。
/// - Returns: 当前 network，便于同步链式配置。
@discardableResult
public func setDeduplicationNamespace(_ namespace: String) -> Self {
    lock.withLock { _deduplicationNamespace = namespace }
    return self
}
```

`getOrCreateExecutor()` 在同一临界区内复制 namespace 和 `NtkConfiguration.current`，传入 executor Configuration；执行器创建后 setter 不影响已有快照。

配置创建片段固定为：

```swift
let globalConfiguration = NtkConfiguration.current
let configuration = NtkNetworkExecutor<ResponseData>.Configuration(
    client: client,
    request: mutableRequest,
    interceptors: _interceptors,
    globalConfiguration: globalConfiguration,
    deduplicationNamespace: _deduplicationNamespace
)
```

- [ ] **Step 7: 运行测试并提交**

Run:

```bash
swift test --filter 'NtkNetworkExecutorTests|NtkRequestTimeoutResolverTests|NtkRequestKeyBuilderTests'
```

Expected: PASS；原有请求修改时序测试继续通过。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Sources/CooNetwork/NtkNetwork/NtkNetwork.swift Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "feat: prepare immutable request execution identity"
```

### Task 6: 用结构化 key 和反向索引重写任务管理

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkCancellableState.swift`
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`

- [ ] **Step 1: 把 TaskManager 测试迁移到显式执行身份**

删除所有 `request.responseType = ...`，增加统一 helper：

```swift
private func deduplicationKey<Response: Sendable>(
    _ type: Response.Type,
    digest: String = "ntk-identity-v2-test",
    timeout: TimeInterval = 30,
    namespace: String = "default"
) -> NtkDeduplicationKey {
    NtkDeduplicationKey(
        requestKey: NtkRequestKey(digest: digest),
        responseType: ObjectIdentifier(type),
        effectiveTimeout: timeout,
        namespace: namespace
    )
}
```

所有执行调用改为：

```swift
try await NtkTaskManager.shared.executeWithDeduplication(
    request: request,
    identity: deduplicationKey(String.self),
    effectiveTimeout: 30
) {
    "result"
} as String
```

所有取消和活跃查询改为：

```swift
await NtkTaskManager.shared.cancelRequest(
    instanceIdentifier: request.instanceIdentifier
)
let isActive = await NtkTaskManager.shared.isRequestActive(
    instanceIdentifier: request.instanceIdentifier
)
```

把现有 `testDifferentResponseTypesShouldNotDedup` 改为使用 `ObjectIdentifier` helper，并加入以下测试和辅助方法：

```swift
@Test
func timeoutNamespaceAndMissingIdentityKeepExecutionsIsolated() async throws {
    let base = deduplicationKey(String.self)
    try await expectTwoExecutions(
        first: base,
        second: deduplicationKey(String.self, timeout: 31)
    )
    try await expectTwoExecutions(
        first: base,
        second: deduplicationKey(String.self, namespace: "secondary")
    )
    try await expectTwoExecutions(first: nil, second: nil)
}

@Test
func cancellationUsesInstanceIdentifierAfterRequestContentChanges() async {
    let gate = TaskExecutionGate()
    var request = NtkMutableRequest(
        TaskManagerDummyRequest(path: "/task-manager/instance-index")
    )
    request.isCancelledRef = NtkCancellableState()
    let snapshot = request
    let task = Task {
        try await NtkTaskManager.shared.executeWithDeduplication(
            request: snapshot,
            identity: deduplicationKey(String.self),
            effectiveTimeout: 30
        ) {
            await gate.signalFirstStarted()
            await gate.waitForFirstRelease()
            return "result"
        } as String
    }
    await gate.waitUntilFirstStarted()

    request.addParameter(key: "stable", value: UUID().uuidString)
    request.isCancelledRef?.cancel()
    await NtkTaskManager.shared.cancelRequest(
        instanceIdentifier: request.instanceIdentifier
    )
    #expect(await NtkTaskManager.shared.isRequestActive(
        instanceIdentifier: request.instanceIdentifier
    ) == false)

    await gate.releaseFirst()
    do {
        _ = try await task.value
        Issue.record("期望取消错误")
    } catch {
        #expect(isCancellationError(error))
    }
}

private func expectTwoExecutions(
    first: NtkDeduplicationKey?,
    second: NtkDeduplicationKey?
) async throws {
    let counter = ExecutionCounter()
    let firstRequest = NtkMutableRequest(
        TaskManagerDummyRequest(path: "/task-manager/isolation-matrix")
    )
    let secondRequest = NtkMutableRequest(
        TaskManagerDummyRequest(path: "/task-manager/isolation-matrix")
    )
    async let firstValue: String = NtkTaskManager.shared.executeWithDeduplication(
        request: firstRequest,
        identity: first,
        effectiveTimeout: first?.effectiveTimeout ?? 30
    ) {
        await counter.increment()
        try await Task.sleep(nanoseconds: 20_000_000)
        return "first"
    }
    async let secondValue: String = NtkTaskManager.shared.executeWithDeduplication(
        request: secondRequest,
        identity: second,
        effectiveTimeout: second?.effectiveTimeout ?? 30
    ) {
        await counter.increment()
        return "second"
    }
    _ = try await (firstValue, secondValue)
    #expect(await counter.value() == 2)
}
```

保留现有 owner/follower 取消矩阵，并在 `cancelAllRequests()` 测试末尾加入：

```swift
await NtkTaskManager.shared.cancelAllRequests()
#expect(await NtkTaskManager.shared.isRequestActive(
    instanceIdentifier: ownerRequest.instanceIdentifier
) == false)
#expect(await NtkTaskManager.shared.isRequestActive(
    instanceIdentifier: followerRequest.instanceIdentifier
) == false)
```

- [ ] **Step 2: 运行测试确认旧 TaskManager 接口不匹配**

Run `swift test --filter NtkTaskManagerTests`。

Expected: 编译失败，TaskManager 仍要求从 request 计算 key。

- [ ] **Step 3: 替换 RuntimeKey 和任务注册状态**

在 `NtkTaskManager` 中使用：

```swift
private enum RuntimeKey: Hashable, Sendable {
    case shared(NtkDeduplicationKey)
    case isolated(UUID)
}

private struct RequestTaskEntry {
    let token: UUID
    let task: Task<Sendable, Error>
    let ownerInstanceId: UUID
    var ownerActive = true
    var followerTasks: [UUID: Task<Sendable, Error>] = [:]
}

private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]
private var runtimeKeyByInstanceID: [UUID: RuntimeKey] = [:]
```

公开内部入口固定为：

```swift
func executeWithDeduplication<T: Sendable>(
    request: NtkMutableRequest,
    identity: NtkDeduplicationKey?,
    effectiveTimeout: TimeInterval,
    execution: @escaping @Sendable () async throws -> T
) async throws -> T

func cancelRequest(instanceIdentifier: UUID)
func isRequestActive(instanceIdentifier: UUID) -> Bool
```

runtime key 只由 `identity.map(RuntimeKey.shared) ?? .isolated(request.instanceIdentifier)` 生成；TaskManager 不读取 `NtkConfiguration`、request policy、headers、parameters、responseType 字符串或 timeout 原值。

执行入口按以下固定分支注册任务；只有 `.shared` 查询 follower，`.isolated` 永远创建 owner：

```swift
func executeWithDeduplication<T: Sendable>(
    request: NtkMutableRequest,
    identity: NtkDeduplicationKey?,
    effectiveTimeout: TimeInterval,
    execution: @escaping @Sendable () async throws -> T
) async throws -> T {
    if request.isCancelledRef?.isCancelled == true {
        throw NtkError.requestCancelled
    }

    let runtimeKey = identity.map(RuntimeKey.shared)
        ?? .isolated(request.instanceIdentifier)
    let timeoutForExecution = identity?.effectiveTimeout ?? effectiveTimeout

    if identity != nil,
       let result: T = try await awaitOngoingResultIfAvailable(
           runtimeKey: runtimeKey,
           request: request
       ) {
        return result
    }

    return try await executeNewRequestWithTimeout(
        runtimeKey: runtimeKey,
        request: request,
        effectiveTimeout: timeoutForExecution,
        execution: execution
    )
}

func cancelRequest(instanceIdentifier: UUID) {
    guard let runtimeKey = runtimeKeyByInstanceID[instanceIdentifier] else { return }
    cancelWaiter(runtimeKey: runtimeKey, instanceIdentifier: instanceIdentifier)
}

func isRequestActive(instanceIdentifier: UUID) -> Bool {
    runtimeKeyByInstanceID[instanceIdentifier] != nil
}
```

- [ ] **Step 4: 在每条生命周期路径维护反向索引**

owner/follower 注册后立即写入索引；完成和取消按匹配的 runtime key 删除，防止旧清理误删未来映射：

```swift
private func register(_ instanceIdentifier: UUID, for runtimeKey: RuntimeKey) {
    runtimeKeyByInstanceID[instanceIdentifier] = runtimeKey
}

private func removeIndex(_ instanceIdentifier: UUID, for runtimeKey: RuntimeKey) {
    guard runtimeKeyByInstanceID[instanceIdentifier] == runtimeKey else { return }
    runtimeKeyByInstanceID.removeValue(forKey: instanceIdentifier)
}

private func removeAllIndexes(for entry: RequestTaskEntry, runtimeKey: RuntimeKey) {
    removeIndex(entry.ownerInstanceId, for: runtimeKey)
    for instanceIdentifier in entry.followerTasks.keys {
        removeIndex(instanceIdentifier, for: runtimeKey)
    }
}
```

在 follower helper 中，创建 waiter 后且第一次 `await waiterTask.value` 之前执行：

```swift
entry.followerTasks[request.instanceIdentifier] = waiterTask
ongoingRequests[runtimeKey] = entry
register(request.instanceIdentifier, for: runtimeKey)
```

在 owner helper 中，创建 entry 后且第一次等待底层 task 之前执行：

```swift
ongoingRequests[runtimeKey] = entry
register(request.instanceIdentifier, for: runtimeKey)
```

`ownerDidFinish` 立即删除 owner index；`followerDidFinish` 删除自身 index；引用计数归零时取消底层任务并清理 entry；`cancelAllRequests()` 取消全部 waiter/underlying tasks 后同时 `removeAll()` 两张表。

对应清理方法使用以下实现，不允许通过扫描 key 前缀判断活动状态：

```swift
private func ownerDidFinish(runtimeKey: RuntimeKey, token: UUID) {
    guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
    entry.ownerActive = false
    removeIndex(entry.ownerInstanceId, for: runtimeKey)
    if entry.followerTasks.isEmpty {
        ongoingRequests.removeValue(forKey: runtimeKey)
    } else {
        ongoingRequests[runtimeKey] = entry
    }
}

private func followerDidFinish(
    runtimeKey: RuntimeKey,
    token: UUID,
    instanceIdentifier: UUID
) {
    guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
    entry.followerTasks.removeValue(forKey: instanceIdentifier)
    removeIndex(instanceIdentifier, for: runtimeKey)
    if !entry.ownerActive && entry.followerTasks.isEmpty {
        entry.task.cancel()
        ongoingRequests.removeValue(forKey: runtimeKey)
    } else {
        ongoingRequests[runtimeKey] = entry
    }
}

private func cancelWaiter(runtimeKey: RuntimeKey, instanceIdentifier: UUID) {
    guard var entry = ongoingRequests[runtimeKey] else {
        runtimeKeyByInstanceID.removeValue(forKey: instanceIdentifier)
        return
    }
    if entry.ownerInstanceId == instanceIdentifier {
        entry.ownerActive = false
    } else if let waiter = entry.followerTasks.removeValue(forKey: instanceIdentifier) {
        waiter.cancel()
    } else {
        removeIndex(instanceIdentifier, for: runtimeKey)
        return
    }
    removeIndex(instanceIdentifier, for: runtimeKey)
    if !entry.ownerActive && entry.followerTasks.isEmpty {
        entry.task.cancel()
        ongoingRequests.removeValue(forKey: runtimeKey)
    } else {
        ongoingRequests[runtimeKey] = entry
    }
}

func cancelAllRequests() {
    for entry in ongoingRequests.values {
        for waiter in entry.followerTasks.values { waiter.cancel() }
        entry.task.cancel()
    }
    ongoingRequests.removeAll()
    runtimeKeyByInstanceID.removeAll()
}
```

- [ ] **Step 5: timeout 只使用 executor 解析结果**

把 `executeWithTimeout` 改为直接接受已验证的 `effectiveTimeout`，删除方法内的全局读取、fallback 和 clamp：

```swift
private func executeWithTimeout<T: Sendable>(
    effectiveTimeout: TimeInterval,
    execution: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        defer { group.cancelAll() }
        group.addTask { try await execution() }
        group.addTask {
            try await Task.sleep(
                nanoseconds: UInt64(effectiveTimeout * 1_000_000_000)
            )
            throw NtkError.requestTimeout(.framework(timeout: effectiveTimeout))
        }
        guard let result = try await group.next() else {
            throw NtkError.requestCancelled
        }
        return result
    }
}
```

- [ ] **Step 6: 接通 interceptor 和 NtkNetwork.cancel**

```swift
func intercept(
    context: NtkInterceptorContext,
    next: iNtkRequestHandler
) async throws -> any iNtkResponse {
    try await NtkTaskManager.shared.executeWithDeduplication(
        request: context.request,
        identity: context.deduplicationKey,
        effectiveTimeout: context.effectiveTimeout
    ) {
        try await next.handle(context: context)
    }
}
```

`NtkNetwork.cancel()` 保留先设置 `NtkCancellableState` 的前置行为，然后只传 `instanceIdentifier`。从 `NtkNetwork.init` 删除 responseType 字符串注入，从 `NtkMutableRequest+deduplication.swift` 删除 responseType key/property，只保留请求级去重开关。

```swift
public func cancel() async {
    let request = lock.withLock { mutableRequest }
    request.isCancelledRef?.cancel()
    await NtkTaskManager.shared.cancelRequest(
        instanceIdentifier: request.instanceIdentifier
    )
}
```

- [ ] **Step 7: 运行任务与执行器测试并提交**

Run:

```bash
swift test --filter 'NtkTaskManagerTests|NtkNetworkExecutorTests|NtkNetworkIntegrationTests'
```

Expected: PASS；不同 response type、timeout、namespace 不共享；全部取消后两张任务表均无活动实例。

Commit:

```bash
git add Sources/CooNetwork/NtkNetwork/deduplication Sources/CooNetwork/NtkNetwork/NtkNetwork.swift Sources/CooNetwork/NtkNetwork/model/NtkCancellableState.swift Tests/CooNetworkTests/NtkTaskManagerTests.swift
git commit -m "refactor: index deduplicated tasks by execution identity"
```

### Task 7: 让缓存消费同一身份并删除旧 key 系统

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkCacheProvider.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequest.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkMutableRequest.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestConfiguration.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift`
- Delete: `Tests/CooNetworkTests/NtkRequestIdentifierManagerTests.swift`
- Delete: `Tests/CooNetworkTests/NtkRequestIdentifierManagerPerformanceTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkCacheTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`

- [ ] **Step 1: 写入显式缓存身份和禁用语义测试**

更新 `NtkNetworkCacheTests`：

```swift
@Test
func cacheUsesProvidedOpaqueIdentityWithoutRecalculation() async {
    let capture = NetworkCacheKeyCapture()
    let cache = NtkNetworkCache(storage: NetworkCacheTestStorage(capture: capture))
    let request = NtkMutableRequest(NetworkCacheTestRequest())
    let identity = NtkRequestKey(digest: "ntk-identity-v2-explicit")

    _ = await cache.hasData(for: request, identity: identity)

    #expect(await capture.key() == identity.digest)
    requireSendable(cache)
}
```

把 storage test double 改为记录 key 的实现：

```swift
private actor NetworkCacheKeyCapture {
    private var capturedKey: String?
    func record(_ key: String) { capturedKey = key }
    func key() -> String? { capturedKey }
}

private struct NetworkCacheTestStorage: iNtkCacheStorage {
    let capture: NetworkCacheKeyCapture

    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await capture.record(key)
        return true
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        await capture.record(key)
        return nil
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await capture.record(key)
        return true
    }
}
```

在 `NtkNetworkExecutorTests` 增加：cache config 为 nil、cacheTime 非有限正数或 identity 构建失败时，`loadCache()` 返回 nil、`hasCacheData()` 返回 false、storage 调用次数为 0；网络请求仍成功。

使用现有 `ExecCacheRequestCapture` 增加两条完整测试；nil 配置由同一测试的 `cacheConfiguration: nil` argument 覆盖：

```swift
@Test(arguments: [
    nil as NtkCacheConfiguration?,
    NtkCacheConfiguration(cacheTime: 0),
    NtkCacheConfiguration(cacheTime: .nan)
])
func disabledCacheConfigurationNeverTouchesStorage(
    configuration: NtkCacheConfiguration?
) async throws {
    let capture = ExecCacheRequestCapture()
    let storage = ExecCapturingCacheStorage(capture: capture)
    let request = NtkMutableRequest(ExecDummyRequest(
        path: "/executor/cache-disabled",
        cacheConfiguration: configuration
    ))
    let executor = NtkNetworkExecutor<Bool>(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            NtkCacheInterceptor(storage: storage)
        ]
    ))

    #expect(try await executor.loadCache() == nil)
    #expect(await executor.hasCacheData() == false)
    #expect(await capture.storageCalls() == 0)
}

@Test
func identityFailureSkipsCacheButStillExecutesNetwork() async throws {
    let capture = ExecCacheRequestCapture()
    var request = NtkMutableRequest(ExecDummyRequest(
        path: "/executor/cache-identity-failure",
        cacheConfiguration: .custom(duration: 60)
    ))
    request.addParameter(key: "unsupported", value: UnsupportedExecIdentityValue())
    let executor = NtkNetworkExecutor<Bool>(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            NtkCacheInterceptor(storage: ExecCapturingCacheStorage(capture: capture))
        ]
    ))

    #expect(try await executor.loadCache() == nil)
    #expect((try await executor.execute()).data == true)
    #expect(await capture.storageCalls() == 0)
}
```

把 `ExecCacheRequestCapture` 的计数扩展为 get/has/set 共用总数，并让 `ExecCapturingCacheStorage` 的三个协议方法都先调用 `recordStorageCall`：

```swift
private actor ExecCacheRequestCapture {
    private var headers: [String: String] = [:]
    private var storageCallCount = 0

    func recordStorageCall(_ request: NtkMutableRequest) {
        headers = request.headers ?? [:]
        storageCallCount += 1
    }

    func headerValue(for key: String) -> String? { headers[key] }
    func storageCalls() -> Int { storageCallCount }
}
```

同步把文件内原有 `hasDataCalls()` 断言迁移到 `storageCalls()`；需要验证 Header 的测试继续使用 `headerValue(for:)`。

```swift
private struct ExecCapturingCacheStorage: iNtkCacheStorage {
    let capture: ExecCacheRequestCapture

    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await capture.recordStorageCall(request)
        return false
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        await capture.recordStorageCall(request)
        return nil
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await capture.recordStorageCall(request)
        return true
    }
}
```

- [ ] **Step 2: 运行测试确认缓存接口仍会自行算 key**

Run:

```bash
swift test --filter 'NtkNetworkCacheTests|NtkNetworkExecutorTests'
```

Expected: 编译失败，缓存 API 尚未接受 `NtkRequestKey`。

- [ ] **Step 3: 修改缓存 provider 和缓存管理器签名**

```swift
/// 向 executor 暴露缓存读取能力，并消费框架已经确定的请求身份。
///
/// provider 不得从 request 再计算 key；同一执行路径必须与去重共享传入的 identity。
public protocol iNtkCacheProvider: Sendable {
    /// 按框架生成的稳定身份读取缓存；存储错误可以抛出，身份失败不会调用此方法。
    func loadCacheData(
        for request: NtkMutableRequest,
        identity: NtkRequestKey
    ) async throws -> (any Sendable)?

    /// 按框架生成的稳定身份查询缓存；身份或缓存配置不可用时 executor 直接返回 false。
    func hasCacheData(
        for request: NtkMutableRequest,
        identity: NtkRequestKey
    ) async -> Bool
}
```

`NtkNetworkCache` 的三个方法固定为：

```swift
/// 使用调用方已解析的身份查询缓存，避免缓存层形成第二套 key 算法。
public func hasData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async -> Bool

public func loadData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async throws -> (any Sendable)?

public func save(
    data: Sendable,
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async -> Bool
```

三个方法均直接把 `identity.digest` 交给 storage；`save` 使用 `request.cacheConfiguration` 计算 expiration，先 guard `isEnabled`。删除 `createCacheKey` 和所有 actor await。

方法体固定为：

```swift
public func hasData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async -> Bool {
    await storage.hasData(key: identity.digest, for: request)
}

/// 使用调用方已解析的身份读取未过期数据；身份本身不从 request 重新生成。
public func loadData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async throws -> (any Sendable)? {
    guard let metadata = await storage.getData(
        key: identity.digest,
        for: request
    ) else { return nil }
    guard metadata.expirationDate >= Date().timeIntervalSince1970 else { return nil }
    return metadata.data
}

/// 使用调用方已解析的身份保存响应，并以请求缓存配置计算本次写入的过期时间。
/// 缓存配置无效时返回 false；该结果不影响网络响应交付。
public func save(
    data: Sendable,
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async -> Bool {
    guard let configuration = request.cacheConfiguration,
          configuration.isEnabled
    else { return false }
    let creationDate = Date().timeIntervalSince1970
    let metadata = NtkCacheMeta(
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0.0",
        creationDate: creationDate,
        expirationDate: creationDate + configuration.cacheTime,
        data: data
    )
    return await storage.setData(
        metaData: metadata,
        key: identity.digest,
        for: request
    )
}
```

- [ ] **Step 4: 缓存读写只消费 context 身份**

`NtkCacheInterceptor.intercept` 的写入 guard 必须一次检查配置和身份：

```swift
let response = try await next.handle(context: context)
guard let configuration = context.request.cacheConfiguration,
      configuration.isEnabled,
      let identity = context.requestKey,
      configuration.shouldCache(response),
      let data = responseExtractor(response)
else { return response }

let cache = NtkNetworkCache(storage: storage)
_ = await cache.save(data: data, for: context.request, identity: identity)
return response
```

`loadCacheData` 和 `hasCacheData` 转发显式 identity。executor 的缓存路径先 `makeContext(includeDeduplication:false, includeCache:true)`，再 guard `context.requestKey`，身份不可用时不调用 provider。

provider 转发和 executor guard 使用以下代码：

```swift
public func loadCacheData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async throws -> (any Sendable)? {
    try await NtkNetworkCache(storage: storage).loadData(
        for: request,
        identity: identity
    )
}

public func hasCacheData(
    for request: NtkMutableRequest,
    identity: NtkRequestKey
) async -> Bool {
    await NtkNetworkCache(storage: storage).hasData(
        for: request,
        identity: identity
    )
}
```

```swift
// NtkNetworkExecutor.loadCache()
let context = try await makeContext(
    includeDeduplication: false,
    includeCache: true
)
guard let identity = context.requestKey else { return nil }
// final handler 内：
guard let data = try await cacheProvider.loadCacheData(
    for: context.request,
    identity: identity
) else {
    throw NtkError.Cache.noCache
}

// NtkNetworkExecutor.hasCacheData()
guard let context = try? await makeContext(
    includeDeduplication: false,
    includeCache: true
), let identity = context.requestKey else { return false }
return await cacheProvider.hasCacheData(
    for: context.request,
    identity: identity
)
```

- [ ] **Step 5: 完成破坏性 API 迁移并删除旧实现**

从 `iNtkRequest` 和 `NtkMutableRequest` 删除 `requestConfiguration`；所有测试 fixture 改为 `cacheConfiguration: NtkCacheConfiguration?`。把 executor 的动态缓存身份测试改为：

```swift
request.addParameter(key: "tenant", value: "coo")
request.addParameter(
    key: "token",
    value: await source.nextToken(),
    identity: .exclude
)
```

同步修正测试工厂的缓存启用语义。`ExecDummyRequest` 改为：

```swift
private struct ExecDummyRequest: iNtkRequest {
    let path: String
    let cacheConfiguration: NtkCacheConfiguration?

    init(
        path: String = "/executor/test",
        cacheConfiguration: NtkCacheConfiguration? = nil
    ) {
        self.path = path
        self.cacheConfiguration = cacheConfiguration
    }
}
```

`makeExecutor`、`makeBoolExecutor` 和 `makeExecutorWithModifier` 在收到非 nil cache interceptor/storage 时，用 `.default()` 构造 request；无 provider 的路径继续传 nil。所有手工创建、并期望读取缓存的 executor request 同样显式传 `.default()`。

`NtkNetworkIntegrationTests.makeNetwork` 使用以下 request 构造，保持“传入 cache storage 的用例启用缓存”的原意：

```swift
let request = IntegDummyRequest(
    path: path,
    cacheConfiguration: cacheStorage == nil ? nil : .default()
)
return NtkNetwork<Bool>.with(
    client,
    request: request,
    responseParser: IntegMockParsingInterceptor(),
    interceptors: interceptors
)
```

并把 fixture 定义改为：

```swift
private struct IntegDummyRequest: iNtkRequest {
    var path: String
    var cacheConfiguration: NtkCacheConfiguration?

    init(
        path: String = "/integration/test",
        cacheConfiguration: NtkCacheConfiguration? = nil
    ) {
        self.path = path
        self.cacheConfiguration = cacheConfiguration
    }
}
```

删除旧配置、旧标识管理器及其两份测试文件。不得保留 `NtkRequestConfiguration` typealias、属性桥、MD5、Swift `Hasher`、LRUNode 或 LRUList。

- [ ] **Step 6: 扫描旧符号、运行缓存与解析测试**

Run:

```bash
rg -n 'NtkRequestConfiguration|requestConfiguration|NtkRequestIdentifierManager|LRUNode|LRUList|getCacheKey|getRequestIdentifier' Sources Tests
```

Expected: 无输出。

Run:

```bash
swift test --filter 'NtkNetworkCacheTests|NtkNetworkExecutorTests|AFDataParsingInterceptorTests|NtkPayloadDecoderTests'
```

Expected: PASS。

- [ ] **Step 7: 提交缓存迁移**

```bash
git add Sources/CooNetwork/NtkNetwork Tests/CooNetworkTests
git commit -m "refactor: unify cache and dedup request identity"
```

### Task 8: 补齐端到端隔离与性能回归覆盖

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Create: `Tests/CooNetworkTests/NtkRequestKeyBuilderPerformanceTests.swift`

- [ ] **Step 1: 写入动态字段和稳定业务身份端到端测试**

把 `NtkNetworkIntegrationTests` 标记为 `@Suite(.serialized)`，加入以下两个测试：

```swift
@Test
func excludedDynamicFieldsDeduplicateForOneStableUser() async throws {
    let client = IntegDedupCountingClient()
    let first = makeIdentityNetwork(
        client: client,
        token: "token-a",
        timestamp: 1,
        userID: "user-42"
    )
    let second = makeIdentityNetwork(
        client: client,
        token: "token-b",
        timestamp: 2,
        userID: "user-42"
    )

    async let firstResponse = first.request()
    async let secondResponse = second.request()
    _ = try await (firstResponse, secondResponse)

    #expect(await client.executionCount() == 1)
}

@Test
func stableUserComponentPreventsCrossUserDeduplication() async throws {
    let client = IntegDedupCountingClient()
    let first = makeIdentityNetwork(
        client: client,
        token: "token-a",
        timestamp: 1,
        userID: "user-a"
    )
    let second = makeIdentityNetwork(
        client: client,
        token: "token-b",
        timestamp: 2,
        userID: "user-b"
    )

    async let firstResponse = first.request()
    async let secondResponse = second.request()
    _ = try await (firstResponse, secondResponse)

    #expect(await client.executionCount() == 2)
}
```

加入测试网络工厂、modifier 和计数 client：

```swift
private struct IntegDynamicIdentityModifier: iNtkRequestModifyingInterceptor {
    let token: String
    let timestamp: Int
    let userID: String

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "Authorization", value: token, identity: .exclude)
        request.addParameter(key: "timestamp", value: timestamp, identity: .exclude)
        request.addRequestKeyValue(key: "user", value: userID)
        return request
    }
}

private struct IntegIdentityRequest: iNtkRequest {
    let timeout: TimeInterval
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/integration/request-identity" }
    var method: NtkHTTPMethod { .get }
}

private actor IntegDedupCountingClient: iNtkClient {
    private var count = 0

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        count += 1
        try await Task.sleep(nanoseconds: 30_000_000)
        return NtkClientResponse(
            data: true,
            msg: nil,
            response: true,
            request: request,
            isCache: false
        )
    }

    func executionCount() -> Int { count }
}

private func makeIdentityNetwork(
    client: IntegDedupCountingClient,
    token: String,
    timestamp: Int,
    userID: String,
    timeout: TimeInterval = 30,
    namespace: String = "default"
) -> NtkNetwork<Bool> {
    let network = NtkNetwork<Bool>.with(
        client,
        request: IntegIdentityRequest(timeout: timeout),
        responseParser: IntegMockParsingInterceptor()
    )
    network.addInterceptor(IntegDynamicIdentityModifier(
        token: token,
        timestamp: timestamp,
        userID: userID
    ))
    network.setDeduplicationNamespace(namespace)
    return network
}
```

- [ ] **Step 2: 写入执行隔离矩阵测试**

加入 timeout 和 namespace 的端到端断言：

```swift
@Test
func timeoutAndNamespaceSeparateOtherwiseEqualExecutions() async throws {
    let timeoutClient = IntegDedupCountingClient()
    let tenSeconds = makeIdentityNetwork(
        client: timeoutClient,
        token: "a",
        timestamp: 1,
        userID: "42",
        timeout: 10
    )
    let twentySeconds = makeIdentityNetwork(
        client: timeoutClient,
        token: "b",
        timestamp: 2,
        userID: "42",
        timeout: 20
    )
    async let firstTimeout = tenSeconds.request()
    async let secondTimeout = twentySeconds.request()
    _ = try await (firstTimeout, secondTimeout)
    #expect(await timeoutClient.executionCount() == 2)

    let namespaceClient = IntegDedupCountingClient()
    let primary = makeIdentityNetwork(
        client: namespaceClient,
        token: "a",
        timestamp: 1,
        userID: "42",
        namespace: "primary"
    )
    let secondary = makeIdentityNetwork(
        client: namespaceClient,
        token: "b",
        timestamp: 2,
        userID: "42",
        namespace: "secondary"
    )
    async let firstNamespace = primary.request()
    async let secondNamespace = secondary.request()
    _ = try await (firstNamespace, secondNamespace)
    #expect(await namespaceClient.executionCount() == 2)
}

@Test
func namespaceSetterDoesNotMutateAnExistingExecutorSnapshot() async throws {
    let client = IntegDedupCountingClient()
    let frozen = makeIdentityNetwork(
        client: client,
        token: "a",
        timestamp: 1,
        userID: "42"
    )
    _ = frozen.getOrCreateExecutor()
    frozen.setDeduplicationNamespace("changed-after-freeze")
    let defaultNamespace = makeIdentityNetwork(
        client: client,
        token: "b",
        timestamp: 2,
        userID: "42"
    )

    async let first = frozen.request()
    async let second = defaultNamespace.request()
    _ = try await (first, second)

    #expect(await client.executionCount() == 1)
}
```

response type 的精确隔离由 Task 6 的 `testDifferentResponseTypesShouldNotDedup` 覆盖，该测试必须使用 `ObjectIdentifier(String.self)` 与 `ObjectIdentifier(Int.self)`，不得通过字符串伪造类型。

- [ ] **Step 3: 运行端到端测试确认组合行为**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS；同一 user 的动态字段变化执行一次，不同 user、timeout 或 namespace 执行两次。配置快照和身份失败降级继续由 Task 5/Task 7 的 executor 测试覆盖，避免再修改进程全局配置。

- [ ] **Step 4: 创建新规范化器性能基线**

创建 `NtkRequestKeyBuilderPerformanceTests.swift`，删除旧 LRU 对比，只保留真实新路径：

```swift
@Suite
struct NtkRequestKeyBuilderPerformanceTests {
    @Test
    func commonRequestBuildsWithinBudget() throws {
        let request = makePerformanceRequest(parameterCount: 12)
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<1_000 {
            _ = try NtkRequestKeyBuilder.build(request: request, policy: .strict)
        }
        let milliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1_000
        #expect(milliseconds < 1_000)
    }

    @Test
    func nestedRequestProducesOneConcurrentDigest() async throws {
        let request = makePerformanceRequest(parameterCount: 100)
        let digests = await withTaskGroup(of: String?.self, returning: [String?].self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? NtkRequestKeyBuilder.build(
                        request: request,
                        policy: .strict
                    ).digest
                }
            }
            var values: [String?] = []
            for await value in group { values.append(value) }
            return values
        }
        #expect(Set(digests.compactMap { $0 }).count == 1)
    }
}
```

在同一文件定义稳定数据工厂，不读取当前时间或随机数：

```swift
private struct IdentityPerformanceRequest: iNtkRequest {
    let values: [String: any Sendable]
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/identity/performance" }
    var method: NtkHTTPMethod { .post }
    var parameters: [String: any Sendable]? { values }
}

private func makePerformanceRequest(parameterCount: Int) -> NtkMutableRequest {
    var values: [String: any Sendable] = [
        "nested": [
            "enabled": true,
            "ids": [1, 2, 3] as [any Sendable]
        ] as [String: any Sendable]
    ]
    for index in 0..<parameterCount {
        values["parameter_\(index)"] = "value_\(index)"
    }
    return NtkMutableRequest(IdentityPerformanceRequest(values: values))
}
```

- [ ] **Step 5: 运行隔离矩阵和性能测试并提交**

Run:

```bash
swift test --filter 'NtkNetworkIntegrationTests|NtkNetworkExecutorTests|NtkRequestKeyBuilderPerformanceTests'
```

Expected: PASS；动态字段被排除时执行一次，user/type/timeout/namespace 任一不同均执行两次。

Commit:

```bash
git add Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift Tests/CooNetworkTests/NtkRequestKeyBuilderPerformanceTests.swift
git commit -m "test: cover stable request identity integration"
```

### Task 9: 更新公开文档、模块说明并执行全量验证

**Files:**
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/design-decisions.md`
- Modify: `docs/ntk-actor-audit.md`
- Modify: `docs/ntk-request-modification-design.md`
- Modify: `Sources/CooNetwork/NtkNetwork/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/model/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`

- [ ] **Step 1: 用真实新 API 重写 README 缓存和动态字段示例**

README 必须展示请求自身只声明缓存语义：

```swift
struct ProfileRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/profile" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? {
        .custom(duration: 300)
    }
}
```

展示启动时公共策略和字段级覆盖：

```swift
NtkConfiguration.configure {
    $0.requestKeyPolicy = .init(
        excludedHeaderNames: ["X-Request-ID"],
        excludedParameterNames: ["nonce", "sign"]
    )
}

struct AuthenticationModifier: iNtkRequestModifyingInterceptor {
    let token: String
    let timestamp: Int
    let userID: String

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "Authorization", value: token, identity: .exclude)
        request.addParameter(key: "timestamp", value: timestamp, identity: .exclude)
        request.addRequestKeyValue(key: "user", value: userID)
        return request
    }
}
```

紧邻示例说明：排除鉴权凭证而不加入稳定 user/tenant component 可能跨用户共享缓存或执行结果；`.strict` 默认不替业务做该推断。

- [ ] **Step 2: 更新架构和设计决策**

`docs/architecture.md` 删除 `NtkRequestIdentifierManager` actor/LRU 所有权描述，增加：无状态 identity builder 负责确定性投影；executor 冻结一次身份；TaskManager actor 只拥有运行任务和反向索引。

`docs/design-decisions.md` 记录三项经确认不变量：缓存配置与身份策略分离；身份 Failure 是内部优化降级而非 `NtkError`；response type 使用 `ObjectIdentifier` 且 timeout/namespace 进入去重执行身份。

`docs/ntk-actor-audit.md` 把旧 identifier actor/LRU 结论更新为无状态 identity builder；`docs/ntk-request-modification-design.md` 把动态字段处理从旧缓存过滤器改为全局策略和字段级 participation。既有 `docs/superpowers/plans/` 与旧 specs 是历史执行记录，不回写其当时的符号名称。

对应 `CLAUDE.md` 文件同步核心类型列表和职责，不能继续把缓存过滤归入 cache 模块。

- [ ] **Step 3: 扫描旧 API、危险字符串化和注释完整性**

Run:

```bash
rg -n 'NtkRequestConfiguration|requestConfiguration|NtkRequestIdentifierManager|filteredParameterNames|filterHeaders|filterParameters|ntk_response_type|responseType = String' Sources Tests README.md docs/architecture.md docs/design-decisions.md docs/ntk-actor-audit.md docs/ntk-request-modification-design.md
```

Expected: 无输出。

Run:

```bash
rg -n 'String\(describing:.*value|joined\(separator: "\|"\)|Insecure\.MD5|Hasher\(' Sources/CooNetwork/NtkNetwork
```

Expected: 请求身份路径无匹配；其他调试输出若匹配，逐项确认不参与 key。

人工检查所有新增 public declaration 的 `///` 注释，确认解释原因、默认行为、覆盖优先级、安全风险、是否发送到服务端和失败降级，删除“添加参数”“返回配置”这类翻译性注释。

- [ ] **Step 4: 执行格式、构建和全量测试**

Run:

```bash
swift format lint --recursive Sources Tests
```

Expected: 若环境安装 `swift-format`，无格式错误；若命令不可用，记录该限制并继续使用编译器验证。

Run:

```bash
swift build
swift test
```

Expected: 两条命令退出码均为 0，全量 Swift Testing suite 通过。

- [ ] **Step 5: 检查变更范围并提交文档收尾**

Run:

```bash
git diff --check
git status --short
```

Expected: 无空白错误；状态只包含本计划列出的源码、测试和文档变更。

Commit:

```bash
git add README.md docs/architecture.md docs/design-decisions.md docs/ntk-actor-audit.md docs/ntk-request-modification-design.md Sources/CooNetwork/NtkNetwork/CLAUDE.md Sources/CooNetwork/NtkNetwork/cache/CLAUDE.md Sources/CooNetwork/NtkNetwork/deduplication/CLAUDE.md Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md Sources/CooNetwork/NtkNetwork/model/CLAUDE.md Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md
git commit -m "docs: document stable request identity"
```

## Final Verification Checklist

- [ ] `NtkCacheConfiguration` 中只有 cacheTime 和 shouldCache。
- [ ] `requestKeyPolicy == nil` 继承 executor 冻结的全局策略。
- [ ] `.include` 和 `.exclude` 均绕过自定义 normalizer。
- [ ] Header 匹配不区分大小写，参数名精确且区分大小写。
- [ ] 缓存和去重使用同一个 `NtkRequestKey` 实例，不重新计算。
- [ ] key 编码不使用值描述字符串、分隔符拼接、MD5 或 Swift Hasher。
- [ ] identity Failure 不进入 `NtkError`，所有构建模式均继续网络请求。
- [ ] response type、effective timeout 和 namespace 都进入去重身份。
- [ ] TaskManager 不读取请求字段或全局配置，只维护任务状态和反向索引。
- [ ] 取消和活跃查询只使用 instanceIdentifier。
- [ ] 不存在旧配置、旧标识管理器或兼容桥。
- [ ] README 明确排除凭证后的跨用户风险。
- [ ] `swift build` 和 `swift test` 全量通过。
