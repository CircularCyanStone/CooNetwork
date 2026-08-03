# Ntk 请求修改与缓存读取设计

> 状态：已确认，可作为后续实现与验收依据。
>
> 确认日期：2026-07-31。
>
> 本文只处理请求修改阶段、缓存读取路径及其与 A08 的关系，不扩展其他网络生命周期能力。

## 1. 目标

本设计解决两个相关但独立的问题：

1. `requestWithCache()` 的网络分支和缓存分支共用一个 `NtkNetworkExecutor` 时，请求状态不能互相覆盖或依赖。
2. `loadCache()`、`hasCacheData()` 必须在计算缓存身份前获得请求修改拦截器加入的稳定公共参数。

最终模型采用显式值流：

- executor 保存创建时冻结的初始请求；
- 每个动作从初始请求独立构建局部请求；
- 请求修改只能发生在专门的请求修改阶段；
- 进入普通拦截链后，请求快照只读。

## 2. 非目标

本次不处理以下内容：

- 不增加第二套 request modifier 注册入口。
- 不让缓存路径执行 retry、loading、toast、dedup 等完整网络拦截行为。
- 不新增可抛错的 `hasCacheData()` 重载。
- 不自动判断 token、timestamp 等业务字段是否属于动态参数。
- 不改变 `markRequestConsumed()` 的调用范围。
- 不迁移 `NtkNetworkExecutor` 的 actor 隔离方式。

## 3. 已确认的生命周期

### 3.1 Executor 生命周期

一个 `NtkNetwork` 实例缓存一个 `_executor`。第一次调用 `getOrCreateExecutor()` 时冻结 client、初始请求和 interceptor 列表，后续动作复用同一个 executor。

`markRequestConsumed()` 只约束真正发起网络请求的入口：

- `request()` 调用 `markRequestConsumed()`；
- `requestWithCache()` 调用 `markRequestConsumed()`；
- `loadCache()` 不调用；
- `hasCacheData()` 不调用。

因此，缓存检查、缓存读取和一次网络请求可以发生在同一个 `NtkNetwork` 上，并复用同一个 executor。

### 3.2 `requestWithCache()` 生命周期

`requestWithCache()` 的缓存分支和网络分支通过 `getOrCreateExecutor()` 获得同一个 executor：

```text
NtkNetwork
    |
    v
同一个 NtkNetworkExecutor
    |
    +--> 缓存分支：loadCache()
    |
    +--> 网络分支：execute()
```

共享 executor 只用于共享冻结配置，不代表共享本次动作的请求值。若配置了 cache provider，两个分支分别从 `initialRequest` 执行一次请求修改阶段，得到所有权独立的局部请求。没有 cache provider 时，缓存分支沿现有语义直接返回 `nil`，不执行请求修改阶段。

## 4. 不可违反的边界

1. 对外只保留 `addInterceptor(_:)` 一个注册入口。
2. `iNtkInterceptor` 不声明 `modifyRequest`。
3. 只有明确遵循 `iNtkRequestModifyingInterceptor` 的 interceptor 才参与请求修改阶段。
4. `modifyRequest(_:)` 是修改请求结构的唯一入口。
5. `NtkInterceptorContext.request` 是只读请求快照。
6. `intercept(context:next:)` 可以短路、重试、读取请求、修改 `extraData` 或处理响应，但不能修改 context 中的请求结构。
7. executor 不保存跨动作演进的可变请求，也不接收 final handler 的请求回写。
8. `execute()`、`loadCache()`、`hasCacheData()` 不读取其他动作构建出的请求。
9. 缓存路径只执行请求修改阶段和缓存所需的响应解析阶段。
10. 同 priority 的 interceptor 严格按注册顺序执行。

## 5. 方案评估与决策

### 5.1 否决：在所有 `iNtkInterceptor` 上提供默认 `modifyRequest`

该方案无法区分显式请求修改者和继承默认 no-op 的普通 interceptor。缓存路径只能调用所有 interceptor，无法表达“只有明确声明者参与请求构建”的语义。

### 5.2 否决：独立注册 request modifier

独立数组或 `addRequestModifier` 会引入第二套扩展注册模型，增加注册顺序、生命周期和便捷构造 API 的理解成本。

### 5.3 否决：在普通 `intercept` 中修改请求

缓存路径不能执行完整 interceptor 链，否则会触发 retry、loading、toast、dedup 等副作用。允许普通 `intercept` 修改请求也会重新混合请求构建与响应处理职责。

### 5.4 采用：明确的请求修改拦截器子协议

新增公开协议：

```swift
public protocol iNtkRequestModifyingInterceptor: iNtkInterceptor {
    @NtkActor
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest
}
```

该名称同时表达两层语义：

- 它本质上属于 interceptor 体系；
- 它明确参与请求修改阶段。

普通 `iNtkInterceptor` 没有 `modifyRequest`，executor 无需猜测某个默认实现是否真的修改请求。

## 6. Interceptor 职责设计

### 6.1 唯一修改入口

请求修改拦截器接收当前请求值，返回下一个请求值：

```swift
public struct CommonParameterInterceptor: iNtkRequestModifyingInterceptor {
    @NtkActor
    public func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        var modifiedRequest = request
        modifiedRequest.addHeader(key: "X-Application", value: "CooNetwork")
        return modifiedRequest
    }
}
```

修改器不能依赖 executor 中上一次动作的结果。它可能在同一个 `NtkNetwork` 生命周期中被多次调用，也可能在 `requestWithCache()` 的两个分支中跨 `await` 交错执行。

### 6.2 默认 `intercept` 透传

为纯请求修改拦截器提供默认实现：

```swift
extension iNtkRequestModifyingInterceptor {
    @NtkActor
    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}
```

实现者可以覆盖 `intercept` 来短路请求或处理响应，但仍只能读取 `context.request`。覆盖 `intercept` 不会获得第二个请求修改入口。

### 6.3 只读 Context

`NtkInterceptorContext` 暴露：

```swift
public let request: NtkMutableRequest
```

因为 `NtkMutableRequest` 是值类型，`let` 属性不能通过其 mutating API 修改。普通 interceptor 可以读取请求，也可以复制出自己的局部值，但不能把副本写回 context 或影响后续链条。

`extraData` 继续作为拦截器链内的可变附加信息；它不属于请求结构。

## 7. 顺序规则

所有 interceptor 采用同一套请求流顺序：

1. priority 高的先执行；
2. priority 相同时，按 `addInterceptor(_:)` 的注册顺序执行。

排序必须显式携带原始下标，不能依赖标准库排序算法是否稳定。executor 先稳定排序完整的 interceptor 列表，再筛选 `iNtkRequestModifyingInterceptor`：

```swift
let modifiers = sortInterceptors(config.interceptors).compactMap {
    $0 as? any iNtkRequestModifyingInterceptor
}
```

这样请求修改阶段和普通拦截链对同一组 interceptor 使用一致的相对顺序。

在单个动作内，所有 `modifyRequest` 都在创建 context 前完成。一个同时实现 `modifyRequest` 和自定义 `intercept` 的类型会分别参与两个阶段；不同动作仍可能在 `await` 处交错，但它们持有各自的局部请求。

## 8. 动作数据流

### 8.1 公共请求构建

```text
executor.initialRequest
        |
        v
稳定排序 config.interceptors
        |
        v
筛选 iNtkRequestModifyingInterceptor
        |
        v
依次调用 modifyRequest
        |
        v
本次动作的局部请求
```

### 8.2 `execute()`

1. 从 `initialRequest` 构建局部请求。
2. 用局部请求创建只读 context。
3. 执行完整 interceptor 链。
4. final handler 把 `context.request` 交给 client。
5. 返回响应，不更新 executor 请求状态。

### 8.3 `loadCache()`

1. 没有 cache provider 时直接返回 `nil`。
2. 从 `initialRequest` 构建局部请求。
3. 用局部请求创建只读 context。
4. 只执行缓存响应需要的 parser 链。
5. cache provider 使用局部请求查询缓存。
6. 没有缓存时返回 `nil`。

### 8.4 `hasCacheData()`

1. 没有 cache provider 时直接返回 `false`。
2. 从 `initialRequest` 构建局部请求。
3. cache provider 使用局部请求检查缓存。

## 9. 缓存与请求身份

缓存配置和身份策略是两个独立维度：`cacheConfiguration` 只决定缓存读写、时长和响应写入资格，`NtkRequestIdentityPolicy` 决定请求字段的本地身份投影；缓存模块不再过滤字段或自行计算 key。`cacheConfiguration == nil` 不读写缓存，身份策略仍可供去重使用。

全局 `requestIdentityPolicy` 默认 `.strict`，不会替业务猜测 token、Authorization 或主体。请求级非 `nil` policy 会完整替换 executor 创建时冻结的全局 policy，而不是合并；这允许特殊接口重新纳入全局排除的字段。

请求修改器应在写入动态字段时声明参与状态：

```swift
request.addHeader(key: "Authorization", value: token, identity: .excluded)
request.addParameter(key: "timestamp", value: timestamp, identity: .excluded)
request.addIdentityComponent(key: "user", value: userID)
```

`.included` 和 `.excluded` 直接覆盖 policy 的名称排除与 custom normalizer；仅 `.automatic` 字段交由 policy 处理。Header 名称按 HTTP 规则大小写不敏感，参数键按精确且区分大小写的名称匹配。identity component 按 key 进入本地身份投影，绝不发送给服务器；排除凭证却未加入稳定 user/tenant component 可能造成跨主体缓存或执行结果共享。

每条动作先执行修改器、prune 陈旧身份元数据，再冻结一次身份与有效超时，随后以同一个 context 结果供缓存和去重消费。身份构建或 normalizer 失败时不是 `NtkError`：本次缓存读取/写入和去重关闭，网络请求继续。

## 10. 错误语义

- `execute()`：`modifyRequest` 抛出的错误直接向调用者传播，不执行普通 interceptor 链和 client。
- `loadCache()`：没有 cache provider 或没有缓存时返回 `nil`；请求修改或缓存读取产生的其他错误继续抛出。
- `requestWithCache()`：沿用现有行为，缓存分支错误被记录并视为没有缓存，网络分支错误结束 stream。
- `hasCacheData()`：保持非抛错签名。没有 cache provider、请求修改失败或 storage 返回无缓存时均返回 `false`。

本次不新增错误类型或可抛错的缓存存在性查询 API。

## 11. 当前实现差距

当前工作区已有两项符合设计的中间改动：

- executor 已改为保存 `initialRequest`，并删除 final handler 的请求回写；
- `NtkInterceptorContext` 已改为只读 `request`。

仍需纠正的中间方案：

- 从 `iNtkInterceptor` 删除默认 `modifyRequest`；
- 新增 `iNtkRequestModifyingInterceptor`；
- executor 只筛选并调用该子协议；
- interceptor 排序显式保证同 priority 的注册顺序；
- 测试辅助 interceptor 改为遵循新子协议；
- 架构文档中所有“基础 interceptor 默认修改请求”的描述改为能力子协议。

## 12. 验收标准

- 普通 `iNtkInterceptor` 没有请求修改方法，也不会进入请求修改阶段。
- `iNtkRequestModifyingInterceptor` 继续通过 `addInterceptor(_:)` 注册。
- `modifyRequest(_:)` 是改变请求结构的唯一框架入口。
- `intercept(context:next:)` 无法修改 `context.request`。
- 纯请求修改拦截器可以使用默认 `intercept` 透传。
- 同一个类型可以同时修改请求并自定义普通拦截行为。
- priority 高的修改器先执行；同 priority 严格保持注册顺序。
- `execute()`、`loadCache()`、`hasCacheData()` 在存在对应能力时分别从 `initialRequest` 构建局部请求。
- `requestWithCache()` 的网络和缓存分支共享 executor，但请求值互相独立。
- `loadCache()`、`hasCacheData()` 不调用 `markRequestConsumed()`。
- `loadCache()` 不触发 retry、loading、toast、dedup 等完整网络拦截副作用。
- 稳定公共参数和 identity component 参与本地身份；动态字段由 policy 或字段 participation 明确控制。
- `execute()` 和 `loadCache()` 传播请求修改错误；`hasCacheData()` 在请求修改失败时返回 `false`。

## 13. 兼容性说明

这是一次公开协议边界调整：

- 只处理响应或副作用的现有 interceptor 继续遵循 `iNtkInterceptor`，无需实现请求修改方法。
- 需要修改请求的 interceptor 改为遵循 `iNtkRequestModifyingInterceptor`，并把修改逻辑迁移到 `modifyRequest(_:)`。
- 旧的 `context.mutableRequest` 写法不再保留可写兼容入口；只读访问统一迁移到 `context.request`。

该兼容性变化是建立编译期请求阶段边界所必需的，不提供运行时回退或隐式能力检测。
