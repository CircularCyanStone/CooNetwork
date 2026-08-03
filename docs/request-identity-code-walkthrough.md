# Request Identity 代码阅读路线

这套逻辑解决一个具体问题：请求里的 token、时间戳、签名等字段经常变化，但它们未必代表不同资源。框架需要先生成一个稳定的 `NtkRequestIdentity`，让缓存判断“是不是同一份资源”，再在它的基础上生成 `NtkDeduplicationKey`，判断“两个正在执行的完整网络流程能不能共享同一个 Task”。

## 从哪里接入，到哪里结束

公开配置从 `NtkConfiguration.Builder.requestIdentityPolicy`、`iNtkRequest.requestIdentityPolicy` 和 `NtkMutableRequest` 的字段写入方法开始。真正进入执行框架的入口是 `NtkNetwork.getOrCreateExecutor()`：它创建 `NtkNetworkExecutor.Configuration` 并冻结本次 network 使用的请求 key 策略。

请求 key 真正开始计算的位置是 `NtkNetworkExecutor.makeContext(includeDeduplication:includeCache:)` 对 `NtkRequestIdentityBuilder.build(request:policy:)` 的调用。计算结果写入 `NtkInterceptorContext` 后分成两条消费路径：

```text
请求定义 / 全局策略
        ↓
NtkMutableRequest + 请求修改器
        ↓
NtkNetworkExecutor.makeContext
        ↓
NtkRequestIdentityBuilder.build
        ↓
NtkInterceptorContext.requestIdentity
        ├── 缓存：NtkCacheInterceptor → NtkNetworkCache → iNtkCacheStorage
        └── 去重：NtkDeduplicationKey → NtkDeduplicationInterceptor → NtkTaskManager
```

因此它有两个明确终点：

- 缓存路径止于 `iNtkCacheStorage` 的 `getData`、`hasData`、`setData`。这里收到的是 `requestIdentity.value`，缓存层不会重新计算 key。
- 去重路径止于 `NtkTaskManager.ongoingRequests`。任务管理器用完整的 `NtkDeduplicationKey` 查找正在执行的 Task，不再读取 Header、参数或策略。

## 建议按这个顺序过代码

### 1. `NtkRequestIdentityRule.swift`

先看单个 Header 或参数的三种规则：

- `.automatic`：交给当前有效的 `NtkRequestIdentityPolicy` 决定。
- `.include`：这个字段一定写入请求 key，并绕过策略的排除集合和转换闭包。
- `.exclude`：这个字段一定不写入请求 key，但仍然发送给服务端。

这三个值只控制本地 key，不修改真实请求。

### 2. `NtkRequestIdentityPolicy.swift`

再看批量规则：

- `excludedHeaderNames` 排除 `.automatic` Header，匹配时忽略大小写。
- `excludedParameterNames` 排除 `.automatic` 参数，匹配时区分大小写。
- `transformHeaders` 和 `transformParameters` 在字段写入 key 前改变用于计算 key 的副本，不改变发往服务端的请求。

请求自己提供的 policy 会完整替换全局 policy，不做合并。这样某个特殊接口可以重新定义完整规则，不会被全局排除项永久限制。

### 3. `NtkMutableRequest.swift`

这是业务代码最常接触的入口：

```swift
request.setHeader(
    token,
    forField: "Authorization",
    requestIdentityRule: .exclude
)
request.setParameter(
    timestamp,
    forKey: "timestamp",
    requestIdentityRule: .exclude
)
request.setRequestIdentityValue(userID, forKey: "user")
```

`headers` 和 `parameters` 是会交给网络层的真实请求内容。它们保留 public getter，是因为业务修改器、普通拦截器和 `iNtkRequest` 的消费者都需要读取最终请求；setter 则是 private，框架外不能直接替换或修改字典。

修改 API 按操作结果区分，不再使用含义模糊的 `add`：

- `setHeader` / `setParameter`：添加或替换一个字段。
- `mergeHeaders` / `mergeParameters`：把一批字段合并进现有字典，保留未涉及的旧字段。
- `setHeaders` / `setParameters`：用一批字段完整替换现有字典，旧字段和旧规则全部删除。
- `removeHeader` / `removeParameter`：删除一个字段及其规则。
- `removeAllHeaders` / `removeAllParameters`：删除对应的全部字段及规则，并把属性恢复成 `nil`。

内部的 `RequestIdentityState` 是真实请求旁边的本地附属状态：`headerRules` 和 `parameterRules` 只保存显式的 `.include` / `.exclude`，`.automatic` 通过删除条目表示；`requestIdentityValues` 保存不发送给服务器、只用于区分缓存和请求去重结果的业务值。例如排除动态 token 后写入 userID，能让同一路径的不同用户保持隔离。公开修改方法会同时更新真实字段和这份状态，因此二者不会失去同步，也不再需要 executor 在最后清理陈旧规则。

注意 `setRequestIdentityValue` 的作用不是“给请求添加参数”，而是在排除 token 后补回 user、tenant 等隔离维度。没有这一步，不同用户可能生成相同 key，进而共享缓存或正在执行的结果。

### 4. `NtkNetwork.getOrCreateExecutor()`

这是 request identity 功能进入网络框架生命周期的第一处。首次执行 `request()`、`loadCache()` 或 `hasCacheData()` 时创建 executor，并冻结：

- 初始请求；
- 全局或请求级 `NtkRequestIdentityPolicy`；
- 缓存拦截器列表；
- 去重开关、默认超时和 namespace。

同一个 `NtkNetwork` 后续继续使用这份配置，不会在一次执行中混入后来修改的全局值。

### 5. `NtkNetworkExecutor.makeRequest()`

每条执行路径都从初始请求复制出新的 `NtkMutableRequest`，再按优先级执行所有 `iNtkRequestModifyingInterceptor`。所以 key 使用的是修改完成后的 Header、参数、字段规则和附加值，而不是最初传入的 request。

`requestWithCache()` 会并发走缓存读取和网络请求，两条路径会分别运行请求修改器。若 token、时间戳每次都变化，又没有通过 `.exclude` 或 policy 排除，两条路径会生成不同 key，缓存自然无法命中。

### 6. `NtkNetworkExecutor.makeContext(...)`

这是 `requestIdentity/` 目录的实际调用入口，顺序不能随意调整：

1. 调用 `makeRequest()` 得到修改后的请求。
2. 用 `NtkRequestTimeoutResolver` 生成唯一的有效超时。
3. 判断本次路径是否真的需要缓存或去重。
4. 需要时调用 `NtkRequestIdentityBuilder.build`，且只调用一次。
5. 在请求 key 上加入响应类型、有效超时和 namespace，生成 `NtkDeduplicationKey`。
6. 把最终请求、两个 key 和有效超时一起写入只读 `NtkInterceptorContext`。

如果 builder 抛出 `BuildError`，这里只记录脱敏 warning，并把两个 key 都置空。运行结果是缓存跳过、去重改为按请求实例独立执行，但网络请求和框架超时继续工作。

### 7. `NtkRequestIdentityBuilder.swift`

`build` 是核心计算流程：

1. `headersForRequestIdentity` 按字段规则分成 `included` 和 `automatic` 两组。
2. 从 `automatic` 中删除 policy 排除的字段，再执行 `transformHeaders`。
3. 把转换结果与 `included` 合并；同名冲突直接失败，不猜覆盖优先级。
4. Header 名称统一转成小写；大小写不同但逻辑同名的重复 Header 会失败。
5. `parametersForRequestIdentity` 以相同顺序处理参数，但参数名保持大小写敏感。
6. 按固定顺序写入 method、baseURL、path、Header、参数和 `requestIdentityValues`。
7. 对编码后的字节计算 SHA-256，得到 `NtkRequestIdentity.value`。

`cacheTime`、`shouldCache`、响应类型、timeout 和 namespace 不写入 `NtkRequestIdentity`。前两项属于缓存策略；后三项只决定正在执行的完整流程能不能去重共享。

### 8. `NtkRequestIdentityEncoder.swift`

编码器负责把参数值变成无歧义字节，不决定字段是否参与。每个值都有类型 tag 和长度，字典 key 排序，数组保留顺序，因此以下情况会得到稳定且符合预期的结果：

- 字典插入顺序不同，key 相同。
- `Int(1)`、`String("1")`、`Bool(true)` 的 key 不同。
- `[1, 2]` 和 `[2, 1]` 的 key 不同。
- 不支持的自定义类型、NaN、Infinity 不会退化成 `description`，而是抛出 `BuildError`。

### 9. `NtkDynamicData.swift`

`NtkDynamicRequestIdentityValue` 和 `requestIdentityValue` 是 `NtkDynamicData` 到编码器的内部桥接。它们避免使用 `NSObject.description`，让内容相同的 `NtkDynamicData` 与普通 Swift 字典或数组生成相同的请求 key。

### 10. `NtkRequestIdentity.swift`

`NtkRequestIdentity` 只包装最终的字符串 `value`。外部缓存 provider 可以存储和比较这个值，但不应解析其格式，也不应自己创建第二套 key 算法。

当前仍使用历史持久化前缀 `ntk-identity-v2-`。这是为了继续命中重命名前已经落盘的缓存，不代表公开 API 仍使用 Identity 术语。只有实际编码协议变化时才应该升级前缀。

### 11. 缓存终点

网络响应返回后，`NtkCacheInterceptor.intercept` 从 context 读取同一个 `requestIdentity`，检查缓存配置与响应写入资格，然后调用 `NtkNetworkCache.save`。显式读取缓存时，executor 直接调用 provider 的 `loadCacheData` / `hasCacheData`。

`NtkNetworkCache` 最终只把 `requestIdentity.value` 原样传给 `iNtkCacheStorage`。到这里请求 key 的缓存职责结束。

### 12. 去重终点

`NtkDeduplicationKey` 在 `NtkRequestIdentity` 外再加入：

- `ResponseData` 的运行时类型；
- 真正执行时使用的有效超时；
- 调用方配置的执行 namespace。

`NtkDeduplicationInterceptor` 位于拦截器链最外层，把这个 key 交给 `NtkTaskManager.executeWithDeduplication`。若 `ongoingRequests` 已有相同 key，本次调用等待已有 Task；否则创建新 Task。

当 `deduplicationKey == nil` 时，任务管理器使用 `request.instanceIdentifier` 构造隔离 key。运行结果仍有超时和取消管理，但不会与任何其他请求共享。

## 最容易误解的边界

- `.exclude` 不会删除 Header 或参数，只是不把该字段写入本地请求 key。
- `setRequestIdentityValue` 不会发送给服务端，只负责给本地 key 增加稳定业务维度。
- `NtkRequestIdentity` 判断资源是否相同；`NtkDeduplicationKey` 判断完整执行流程能否共享。
- 缓存和去重都不允许自己重算请求 key，它们只能消费 executor 放进 context 的结果。
- 请求 key 构建失败不会让网络请求失败；请求修改器或真实网络调用抛错则仍按正常错误流程传播。
