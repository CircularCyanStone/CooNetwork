# 请求身份、缓存键与去重键设计

> 历史设计记录：本文保留重命名前的术语和接口草案，用于解释当时为什么引入这套能力，不代表当前 API。当前代码请以 [Request Key 代码阅读路线](../../request-key-code-walkthrough.md) 和 [Request Key 命名设计](./2026-08-03-request-key-naming-design.md) 为准。

## 背景

`iNtkRequest.requestConfiguration` 当前同时承担缓存时长、响应缓存判断、请求头过滤、请求参数过滤和去重身份生成。这个接口造成两个问题：

1. `requestConfiguration == nil` 表面表示不使用缓存，实际还会关闭去重字段过滤，使 token、timestamp、nonce、签名和 trace header 等动态字段进入去重 key。
2. 缓存与去重分别生成 key，但共享一部分过滤闭包，调用方无法从名称和注释准确判断配置的真实影响范围。

当前请求修改阶段已经前置。`NtkNetworkExecutor.makeRequest()` 会先执行全部 `iNtkRequestModifyingInterceptor`，得到最终请求快照后才进入普通拦截器链。因此 `NtkDeduplicationInterceptor` 位于 `.outerHighest` 并不会漏掉请求修改器注入的动态字段。本次保留它的最外层执行位置。

## 目标

- 将缓存策略与请求身份策略彻底分离。
- 让业务上等价的请求在 token、timestamp 等动态字段变化时仍产生相同身份。
- 让不同用户、tenant、响应类型、有效 timeout 或执行命名空间的请求保持隔离。
- 缓存键和去重键共享同一份规范化请求身份。
- 对嵌套参数和字典顺序提供确定性编码，不使用 `String(describing:)` 作为身份表示。
- 身份生成失败时保持网络请求可用，并安全地关闭本次缓存与去重。
- 取消和活跃状态查询不再根据修改前的请求重新计算 key。
- 新增公开接口具有解释行为、原因、不变量和安全约束的完整文档注释。

## 非目标

- 不移动 `NtkDeduplicationInterceptor` 的执行位置。
- 不自动推断某个业务字段是否动态或是否定义请求身份。
- 不自动哈希 client、parser、validation、retry 或任意 interceptor 的闭包和实例状态。
- 不保留 `NtkRequestConfiguration` 和 `requestConfiguration` 的兼容桥。
- 不因为身份生成失败而让 `request()` 失败。

## 核心模型

### 缓存配置

`NtkRequestConfiguration` 重命名为 `NtkCacheConfiguration`，只保留缓存职责：

```swift
public struct NtkCacheConfiguration: Sendable {
    public let cacheTime: TimeInterval
    public let shouldCache: @Sendable (any iNtkResponse) -> Bool

    public init(
        cacheTime: TimeInterval,
        shouldCache: @escaping @Sendable (any iNtkResponse) -> Bool = { _ in true }
    )
}
```

`cacheTime` 和 `shouldCache` 不参与请求身份。改变缓存时长不能改变缓存所代表的资源。

缓存启用语义固定为：

- `cacheConfiguration == nil` 时不读取也不写入缓存。
- `cacheConfiguration != nil` 且 `cacheTime` 为有限正数时，允许读取缓存，并由 `shouldCache` 决定是否写入响应。
- `cacheTime` 为零、负数、NaN 或无穷大时，本次缓存读写均关闭，网络请求不受影响。

保留不携带身份职责的 `.default()` 和 `.custom(duration:)` 便捷构造，避免常规缓存调用增加配置成本。原有仅用于配置过滤字段的 `.custom(filteredParams:)` 重载删除，其迁移目标是全局或请求级身份策略。

### 请求协议

`iNtkRequest` 的配置接口调整为：

```swift
public protocol iNtkRequest {
    var cacheConfiguration: NtkCacheConfiguration? { get }
    var requestKeyPolicy: NtkRequestKeyPolicy? { get }
}
```

语义固定为：

- `cacheConfiguration == nil` 表示不缓存。
- `requestKeyPolicy == nil` 表示继承全局请求身份策略。
- 非空的请求级身份策略完整替换全局策略，适用于需要重新纳入全局排除字段的特殊接口。

协议扩展为两个属性提供默认 `nil` 实现，因此只有需要缓存或覆盖身份策略的请求需要声明它们。

### 字段参与状态

新增三态枚举：

```swift
public enum NtkRequestKeyRule: Sendable {
    case automatic
    case included
    case excluded
}
```

- `.automatic` 交给请求级或全局策略决定。
- `.include` 强制字段参与身份计算。
- `.exclude` 强制字段不参与身份计算。

三态而不是布尔值的原因是：调用方必须能够让某个字段继承默认策略，也必须能够在特殊接口中显式覆盖全局排除规则。

### 可变请求接口

`NtkMutableRequest` 的单值和批量写入接口增加默认值为 `.automatic` 的 `identity` 参数：

```swift
public mutating func addHeader(
    key: String,
    value: String,
    identity: NtkRequestKeyRule = .automatic
)

public mutating func addParameter(
    key: String,
    value: Sendable,
    identity: NtkRequestKeyRule = .automatic
)

public mutating func addHeaders(
    _ headers: [String: String],
    identity: NtkRequestKeyRule = .automatic
)

public mutating func addParameters(
    _ parameters: [String: Sendable],
    identity: NtkRequestKeyRule = .automatic
)

public mutating func setParameter(
    _ parameters: [String: Sendable],
    identity: NtkRequestKeyRule = .automatic
)
```

动态字段的推荐写法为：

```swift
request.addHeader(
    key: "Authorization",
    value: token,
    identity: .exclude
)

request.addParameter(
    key: "timestamp",
    value: timestamp,
    identity: .exclude
)
```

身份标记保存在 `NtkMutableRequest` 的专用内部元数据中，不写入请求头、参数或 `extraData`，也不发送给服务器。

字段更新规则：

- 使用带 `identity` 参数的写入方法更新字段时，新状态替换旧状态。
- `.automatic` 通过删除该字段的显式覆盖实现，保证后续策略调整仍能生效。
- `removeHeader` 和 `removeParameter` 同时删除字段及其身份状态。
- `clearHeaders` 和 `clearParameters` 同时清理对应身份状态。
- `setParameter` 清理旧参数的身份状态，并为新参数统一设置传入状态。
- Header 的查找、更新、移除和身份元数据匹配均不区分大小写。使用便捷方法写入 Header 时，先移除大小写不同的同名旧键，避免同一个 HTTP 字段出现两个值。
- `addHeaders` 按稳定的 key 顺序逐项应用相同规则；输入中存在大小写不同的同名 Header 时，排序后的最后一个值确定性地生效。
- 参数键和身份组成键区分大小写。
- 直接修改公开字典不会自动声明身份语义：新键采用 `.automatic`，仍存在的旧键保留已有显式状态，已移除键的陈旧状态在请求冻结时清理。需要改变已有键的身份状态时必须使用上述方法或显式策略。

原始 `iNtkRequest` 中的所有 Header 和参数初始均为 `.automatic`。字段状态描述的是逻辑键，而不是某一次写入的值；因此更新值不会意外恢复参与身份计算。

### 稳定身份组成

排除 token 后可能让不同用户的请求发生碰撞。为此，`NtkMutableRequest` 提供不发送到服务器的稳定身份组成：

```swift
public mutating func addRequestKeyValue(
    key: String,
    value: String
)

public mutating func removeRequestKeyValue(key: String)
```

典型用法：

```swift
request.addRequestKeyValue(key: "user", value: userID)
request.addRequestKeyValue(key: "tenant", value: tenantID)
```

相同 key 再次写入时采用最后一个值。身份组成按 key 排序后参与规范化编码。

身份组成键区分大小写；空字符串也是合法值。它们只用于本地身份投影，不写入日志，也不出现在真实请求中。

## 身份策略

### 全局默认

`NtkConfiguration.Builder` 增加：

```swift
public var requestKeyPolicy: NtkRequestKeyPolicy = .strict
```

`.strict` 不排除任何字段。框架不能默认排除 `Authorization` 或 `token`，因为它们可能是唯一能够区分用户的身份信息。

应用可以在启动时统一配置公共动态字段：

```swift
NtkConfiguration.configure {
    $0.requestKeyPolicy = .init(
        excludedHeaderNames: ["Authorization", "X-Request-ID"],
        excludedParameterNames: ["token", "timestamp", "nonce", "sign"]
    )
}
```

### 策略接口

```swift
public struct NtkRequestKeyPolicy: Sendable {
    public let excludedHeaderNames: Set<String>
    public let excludedParameterNames: Set<String>

    public let transformHeaders:
        (@Sendable ([String: String]) throws -> [String: String])?

    public let transformParameters:
        (@Sendable ([String: Sendable]) throws -> [String: Sendable])?

    public init(
        excludedHeaderNames: Set<String> = [],
        excludedParameterNames: Set<String> = [],
        transformHeaders: (@Sendable ([String: String]) throws -> [String: String])? = nil,
        transformParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])? = nil
    )

    public static let strict: Self
}
```

名称列表覆盖常见的顶层字段过滤。规范化闭包是高级逃生口，用于嵌套结构、字段投影或业务特有的规范化。

构造策略时，Header 名称集合统一转为小写，参数名称保持原样。`.strict` 等价于两个排除集合均为空且没有自定义规范化闭包。

规范化闭包必须满足以下接口不变量：

- 是纯函数，相同输入始终返回相同输出。
- 不读取当前时间、随机数或可变全局状态。
- 只影响身份投影，不修改真正发送的请求。
- 可以过滤或转换 `.automatic` 字段，但无法接触 `.include` 和 `.exclude` 字段。
- 抛错时本次身份不可用，由框架执行安全降级。

名称列表先过滤传给闭包的 `.automatic` 输入，闭包返回值作为该部分的最终身份投影；高级闭包可以创建新的投影字段。闭包输出与 `.include` 字段发生同名冲突，或规范化后出现重复 Header 名称时，不猜测覆盖顺序，直接判定身份构建失败。

### 解析优先级

身份投影按以下固定顺序构建：

1. 请求级策略存在时完整替换全局策略，否则使用全局策略快照。
2. `.exclude` 字段直接删除，不交给策略。
3. `.include` 字段直接保留，不交给策略。
4. `.automatic` 字段经过名称列表和自定义规范化闭包。
5. 加入稳定身份组成。
6. 执行确定性编码并生成摘要。

Header 排除名称按 HTTP 规则不区分大小写并精确匹配。参数排除名称按区分大小写的精确 key 匹配。禁止使用当前的子串 `contains` 行为，避免 `token` 误排除 `tokenValue`。这是一次有意的语义修正：需要同时排除 `token` 和 `Token` 的应用必须分别声明两个参数名。

### 快照时机

`NtkNetworkExecutor` 创建时一次性冻结全局配置快照、请求级策略、去重命名空间和响应类型标识。请求修改器随后可以为每条执行路径添加字段级状态和身份组成，但已经冻结的策略不会因后续 `NtkConfiguration.configure` 调用而变化。

同一快照中的 `requestKeyPolicy`、`isDeduplicationEnabled` 和 `defaultTimeout` 必须一起解析，`NtkTaskManager` 不再在任务注册时重新读取全局配置。这样 key 的组成、是否共享以及实际超时不会来自不同时间点的配置。

## 确定性身份构建

新增无状态的内部深模块 `NtkRequestKeyBuilder`。其接口只接收最终请求投影并返回不可变身份，缓存和去重不能再各自实现过滤或字符串化。

执行器在请求修改完成后构建一次身份解析结果，并将其随不可变 `NtkInterceptorContext` 传递。网络执行路径上的去重和缓存写入消费同一个结果；显式缓存读取和 `hasCacheData()` 各自针对其最终请求快照构建一次结果，但必须使用同一 builder 和算法版本。任何缓存协议适配都不能根据 request 再计算第二份 key。

### 输入

请求身份至少包含：

- HTTP method。
- base URL。
- path。
- 策略处理后的 headers。
- 策略处理后的 parameters。
- 稳定身份组成。

### 规范化规则

- Header 名称转为小写后排序。
- 规范化后出现重复 Header 名称视为身份构建失败，避免依赖字典覆盖顺序。
- 参数字典和嵌套字典按 key 排序。
- 数组保留原有顺序。
- `nil` Header/参数集合与空集合使用相同表示，避免无内容集合产生伪差异。
- 字符串、布尔、整数、浮点等值使用明确的类型标签。
- 字符串 `"1"`、整数 `1` 和布尔值 `true` 必须生成不同表示。
- signed/unsigned 整数使用无歧义十进制表示。
- 浮点值只接受有限值，并使用稳定的位模式或规范化十进制表示。
- `Data` 使用原始字节。
- `URL` 使用明确的绝对字符串表示。
- `UUID` 使用 16 字节标准表示，`Date` 使用有限的绝对时间位模式；二者不能通过描述字符串编码。
- `NtkDynamicData` 递归展开其字典、数组、标量和 null 存储。
- `NSNull` 使用独立 null 标签。
- 不支持任意自定义 `Sendable` 的 `String(describing:)` 降级。

编码采用类型标签和长度前缀构造规范化字节，不使用 `|` 拼接，避免字段内容与分隔符发生碰撞。规范化字节使用 SHA-256 生成稳定摘要，并带算法版本前缀，例如 `ntk-identity-v2-...`。

### 身份类型

```swift
public struct NtkRequestKey: Hashable, Sendable {
    public let digest: String

    internal init(digest: String)
}

struct NtkDeduplicationKey: Hashable, Sendable {
    let requestKey: NtkRequestKey
    let responseType: ObjectIdentifier
    let effectiveTimeout: TimeInterval
    let namespace: String
}
```

缓存直接使用 `NtkRequestKey.digest`。去重使用结构化的 `NtkDeduplicationKey`，不再拼接字符串 runtime key。响应类型使用 `ObjectIdentifier(ResponseData.self)`，因为去重只发生在当前进程；它能精确区分运行时类型，也避免 `String(describing:)` 的跨模块同名碰撞。现有写入 `NtkMutableRequest.responseType` 的字符串元数据随之删除。

`NtkRequestKey` 公开是为了让自定义缓存 provider 消费框架生成的同一身份，不是为了允许调用方自行构造。`digest` 是可持久化但不透明的版本化键；调用方可以存储和比较它，不能解析其内部格式或假设未来算法版本不变。

### 缓存身份传递

缓存接口显式接收已经解析好的身份，彻底移除“只给 request、由下游自行算 key”的入口：

```swift
public protocol iNtkCacheProvider: Sendable {
    func loadCacheData(
        for request: NtkMutableRequest,
        identity: NtkRequestKey
    ) async throws -> (any Sendable)?

    func hasCacheData(
        for request: NtkMutableRequest,
        identity: NtkRequestKey
    ) async -> Bool
}
```

`NtkNetworkCache.hasData`、`loadData` 和 `save` 同样增加必需的 `identity` 参数，并直接使用其 digest，不再依赖 actor 或 request 重新构建 key。执行器和默认缓存拦截器只在缓存配置有效且身份可用时调用这些接口；否则直接返回无缓存或跳过写入。身份在 `NtkInterceptorContext` 内部传递，普通业务拦截器不能替换。

## 缓存键与去重键

### 缓存身份

缓存身份只描述资源：

```text
method + URL + headers + parameters + identity components
```

以下内容不参与缓存身份：

- cacheTime。
- shouldCache。
- responseType。
- timeout。
- deduplication namespace。

### 去重执行身份

去重位于拦截器链最外层，复用完整执行结果，因此在请求身份之外加入：

- `responseType`，避免不同泛型响应类型共享结果。
- 规范化后的 `effectiveTimeout`，避免 owner 的 timeout 随竞争顺序支配 follower。
- `deduplicationNamespace`，用于显式隔离不同执行流水线。

有效 timeout 的规范化与实际执行共享同一个结果：请求值为有限正数时直接使用，否则使用执行器冻结的全局默认值；全局默认值本身无效时回退到框架内建的 20 秒；最终值统一按现有 100 年上限截断。规范化只执行一次，生成的同一个值既写入去重身份，也传给超时任务。不同有效 timeout 的请求不去重。

### 去重命名空间

`NtkNetwork` 增加零默认成本的可选接口：

```swift
@discardableResult
public func setDeduplicationNamespace(_ namespace: String) -> Self
```

默认命名空间为 `"default"`，普通调用方无需配置。统一网络工厂存在不同 client、parser、validation、retry 或响应处理语义时，应设置不同命名空间。

相同命名空间表示调用方承诺两条执行流水线可以共享最终结果。框架不自动哈希拦截器类型或闭包配置，因为这种指纹无法覆盖实例状态，会产生虚假的等价保证。

命名空间按字符串原值精确比较，不做大小写或空白归一化。setter 只影响执行器创建前的配置；执行器一旦创建，后续修改不影响该执行快照。

## 去重时序

保留 `NtkDeduplicationInterceptor.priority == .outerHighest`。

完整时序为：

```text
initial request
  -> all request modifiers
  -> identity and effective-timeout finalization
  -> immutable interceptor context
  -> deduplication interceptor
  -> remaining interceptors
  -> client
```

此时请求修改已经完成，普通拦截器不能再修改请求身份。上下文持有可用的 `NtkRequestKey` 或不可用状态，以及已经规范化的有效 timeout 和精确响应类型。最外层去重使 retry、client、parser、validation 和 cache write 只执行一次，follower 共享完整结果。

只有缓存或去重至少有一个实际启用时才构建请求身份，避免在没有消费者的路径上触发无意义的规范化工作和警告。有效 timeout 无论是否去重都必须解析，因为独立请求同样由任务管理器负责超时。

## 取消与任务索引

当前执行使用修改后的请求生成 key，但 `NtkNetwork.cancel()` 使用修改前的请求重新计算 key。请求修改器加入参与身份的字段后，取消可能无法定位任务。

`NtkTaskManager` 改为维护反向索引：

```swift
private var runtimeKeyByInstanceID: [UUID: RuntimeKey]
```

内部 runtime key 使用结构化枚举：

```swift
enum RuntimeKey: Hashable, Sendable {
    case shared(NtkDeduplicationKey)
    case isolated(UUID)
}
```

owner 和 follower 注册时都记录 `instanceIdentifier -> runtimeKey`。取消和实例活跃状态查询只使用 `instanceIdentifier`，不重新读取请求内容或全局配置。

`NtkTaskManager` 的对应入口调整为 `cancelRequest(instanceIdentifier:)` 和 `isRequestActive(instanceIdentifier:)`。执行入口接收执行器已经解析好的可选去重身份和有效 timeout；身份缺失、全局关闭去重或请求级关闭去重时使用 `.isolated(instanceIdentifier)`。

取消与清理规则：

- 任务注册前取消由共享 `NtkCancellableState` 拦截。
- follower 取消只移除自身等待任务和反向索引。
- owner 取消但仍有 follower 时，底层任务继续。
- 所有等待者取消后，取消底层任务并清理 entry。
- 请求完成后清理关联的全部实例索引。
- `cancelAllRequests()` 同时清空任务表和全部反向索引。

`NtkTaskManager` 只负责任务合并、等待、超时、取消和清理，不再负责请求身份生成。

## 身份失败与降级

身份失败不会进入面向业务层的 `NtkError`。`NtkError` 的既有接口用于 `request()` 能够向业务调用方抛出的公共失败；身份失败只影响缓存和去重优化，业务层无法也不需要捕获。

失败类型归属于身份构建模块：

```swift
struct NtkRequestKeyBuilder {
    enum Failure: Error, Sendable {
        case unsupportedValue(path: String, type: String)
        case normalizationFailed(section: Section, errorType: String)
        case invalidHeaderName(String)
        case duplicateNormalizedHeader(String)
        case projectionCollision(section: Section, key: String)
    }
}
```

失败处理：

- 去重跳过，当前请求独立执行。
- 缓存跳过读取和写入。
- 网络请求继续。
- warning 包含字段路径和类型，不输出字段值、凭证或自定义错误的描述文本。
- 所有构建模式都执行相同的安全降级。用户输入不受支持或自定义规范化抛错是可恢复问题，不能用会中断 Debug 请求的 assertion；只有框架自身不可能发生的内部不变量破坏才允许断言。

未来只有在身份失败能够从公开接口抛给业务层时，才重新评估公开错误类型。即使公开独立的身份预检接口，也应优先使用独立的 `NtkRequestKeyError`，而不是自动并入网络请求失败语义的 `NtkError`。

## 模块与文件布局

建议布局：

```text
NtkNetwork/
  cache/
    NtkCacheConfiguration.swift
    NtkNetworkCache.swift

  identity/
    NtkRequestKeyRule.swift
    NtkRequestKeyPolicy.swift
    NtkRequestKey.swift
    NtkRequestKeyBuilder.swift
    NtkRequestKeyBuilder+Failure.swift
    NtkRequestTimeoutResolver.swift

  deduplication/
    NtkDeduplicationKey.swift
    NtkDeduplicationInterceptor.swift
    NtkTaskManager.swift
```

现有 `NtkRequestIdentifierManager` 的身份计算和 LRU 映射删除。纯身份计算不再通过 actor；`NtkTaskManager` actor 继续拥有运行中任务和反向索引。

## 迁移

本次允许源码级破坏性调整，因此直接执行：

```text
NtkRequestConfiguration -> NtkCacheConfiguration
requestConfiguration    -> cacheConfiguration
```

所有源代码、测试、示例和文档同步迁移。过滤字段、过滤闭包和参数规范化能力迁移到 `NtkRequestKeyPolicy`，不保留 deprecated typealias 或属性桥。

旧配置默认排除 `token`，新全局身份策略出于跨用户安全考虑默认为 `.strict`。因此只做类型重命名不会继续排除 `token`：迁移时必须按业务语义选择全局排除、请求级策略或字段级 `.exclude`，并在排除鉴权凭证时加入稳定的 user/tenant 身份组成。

缓存键算法版本变化会自然使旧缓存不可达。实现和发布说明需要明确这是一次缓存键版本升级；旧缓存由现有存储淘汰策略处理，不在本次引入批量删除接口。

## 注释要求

新增公开类型和方法必须提供完整中文文档注释，至少说明：

- 接口解决的问题和适用场景。
- 默认行为和继承规则。
- 字段参与状态的优先级。
- 是否影响真实网络请求。
- 更新、覆盖和移除时的身份元数据行为。
- 身份失败时的降级方式。
- 排除凭证字段时的跨用户安全风险。
- 自定义规范化闭包的确定性要求。
- 去重命名空间代表的等价性承诺。

禁止只把符号名称翻译成一句话的注释，例如“添加参数”“返回配置”。内部复杂实现只在不明显的不变量、碰撞规避、并发清理或安全降级位置添加简洁说明。

## 测试策略

### 请求身份

- token、timestamp 值不同但标记 `.exclude` 时身份相同。
- 参与身份的稳定参数不同时身份不同。
- `.include` 覆盖全局排除规则。
- `.exclude` 字段不进入自定义规范化闭包。
- Header 名称大小写不影响身份。
- Header 便捷方法按大小写不敏感语义更新、移除并维护身份状态。
- 批量 Header 中大小写不同的同名字段按稳定规则选择结果。
- 参数 key 精确匹配，排除 `token` 不影响 `tokenValue`。
- 顶层和嵌套字典插入顺序不同仍产生相同身份。
- 数组顺序不同产生不同身份。
- 字符串、整数和布尔值具有不同类型表示。
- `Data`、`URL`、null 和 `NtkDynamicData` 产生确定性表示。
- 不支持的自定义 `Sendable` 返回结构化 Failure，不使用字符串描述。
- Header/参数的 nil 集合与空集合身份相同。
- `UUID` 和 `Date` 不依赖描述字符串且跨重复构建稳定。
- 自定义规范化输出与 `.include` 字段冲突时身份不可用。

### 策略与快照

- 请求级策略完整替换全局策略。
- executor 创建后修改全局策略不影响已有快照。
- executor 创建后修改全局去重开关、默认 timeout 或 namespace 不影响已有快照。
- 自定义规范化闭包抛错时网络继续，缓存和去重跳过。
- 身份组成能够隔离不同 user 和 tenant。

### 缓存

- 缓存和去重消费同一个 `NtkRequestKey`。
- cacheTime 不改变缓存键。
- identity unavailable 时不读取、不写入缓存。
- cacheConfiguration 缺失或 cacheTime 无效时不读取、不写入缓存。
- 新键带算法版本前缀。

### 去重

- 相同请求身份、响应类型、有效 timeout 和 namespace 只执行一次。
- 不同 responseType 不去重。
- 不同有效 timeout 不去重。
- 不同 namespace 不去重。
- 默认 namespace 不增加调用配置成本并保持跨实例去重。
- 身份不可用时请求独立执行。
- 去重 key 使用的 effectiveTimeout 与实际超时任务使用完全相同的值。
- 请求修改器添加动态排除字段后仍能去重。

### 取消与并发

- 请求修改器添加参与身份的稳定字段后，取消仍能通过 instance ID 定位任务。
- follower 取消不影响 owner 和其他 follower。
- owner 取消但 follower 存在时底层任务继续。
- 全部等待者取消后底层任务取消。
- 完成、失败和取消都会清理反向索引。
- 全量取消清空所有反向索引。
- 并发身份生成和并发去重结果稳定。

### 性能

- 更新现有请求标识性能测试，使其覆盖新的规范化器。
- 性能测试验证常见浅层参数和中等嵌套参数没有明显回退。
- 不为避免微小计算成本重新引入两套身份表示或 LRU 结果不一致风险。

## 验收标准

- 不使用缓存的请求也能通过全局或字段级策略排除动态字段并稳定去重。
- 缓存配置中不再存在任何身份过滤职责。
- 同一个最终请求投影只经过一份规范化实现。
- 单条网络执行路径上的缓存与去重消费上下文中的同一次身份解析结果。
- 缓存键跨进程稳定，去重身份在同一进程内结构化可比较。
- 不同用户、响应类型、有效 timeout 和 namespace 不会错误合并。
- 取消不重新计算请求 key。
- 身份失败不会传播到业务层，也不会阻止网络请求。
- 所有新增公开接口具备非翻译性的完整注释。
- 全量 Swift 测试通过，示例和 README 使用新接口。
