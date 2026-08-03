# NtkActor 使用审查

审查日期：2026-07-31

审查范围：`Sources/CooNetwork`、`Sources/AlamofireClient` 中所有 `@NtkActor` 使用点，以及与它们直接关联的公开协议、请求上下文和解析流水线。

## 结论

本次审查发现，`@NtkActor` 当时承担了过多职责：它既被用来保护共享可变状态，也被当作“所有网络代码的统一执行上下文”。后者不是 actor 的合理边界。是否属于网络流程、方法是否为 `async`，都不能单独构成使用全局 actor 的理由。

合理的隔离边界应由状态所有权决定：

- 真正的进程级共享可变状态，才考虑全局 actor。
- 单个对象拥有的可变状态，优先使用独立 `actor` 或内部锁。
- 单次请求拥有的状态，优先使用每请求 actor、任务内顺序执行或值快照。
- 无共享可变状态的 I/O、解析、校验和适配代码，不需要 `@NtkActor`。
- UI 副作用需要的是 `@MainActor`，`@NtkActor` 不提供主线程保证。

Actor 在 `await` 处允许重入。它只保证同一时刻 actor 隔离代码的同步片段不会并发执行，不保证一个异步方法从入口到返回构成原子事务，也不会让多个步骤天然保持快照一致性。

最终迁移已完成：仅 `NtkTaskManager` 以独立 actor 隔离运行中任务和实例反向索引；无状态 `NtkRequestIdentityBuilder` 在 executor 中完成确定性身份投影，缓存门面和执行值流通过 `Sendable` 跨并发域传递，同步配置继续使用短临界区锁。生产代码、测试和当前架构文档已不再依赖 `NtkActor`，全局 actor 声明已删除。Loading/Toast 的 `MainActor` 契约仍属于独立的 UI API 决策，不影响本次删除结论。

## 问题清单

### A01：解析阶段仍接收完整可变拦截器上下文

- 优先级：高
- 位置：`NtkDataParsingInterceptor`、`iNtkResponsePayloadTransforming`、`iNtkResponsePayloadDecoding`、`iNtkParsingHooks`、`NtkParsingHookDispatcher`、`NtkDefaultResponseParsingPolicy`
- 状态：已修正

解析阶段只需要请求信息和解析辅助数据，却曾把 `@NtkActor` 隔离的 `NtkInterceptorContext` 传给 transformer、decoder、policy 和 hooks。这会把已经移出 actor 的解析方法重新绑定到 actor 隔离状态，并向扩展实现暴露 `client`、可写请求和可写共享数据。

处理方式：在 `acquire` 阶段一次性创建 `NtkParsingContext` 只读结构值快照，后续 `transform -> decode -> policy -> hooks` 只传该快照。快照包含当前 `NtkMutableRequest` 和 context `extraData` 的值副本，不暴露 `client`，解析阶段不能回写拦截器链状态；其中 `Sendable` 容器若持有引用值，不承诺通用深拷贝。transformer 保留 `async`，因为解密、密钥获取或其他异步改造是合理扩展能力；`async` 与 actor 隔离是两个独立问题。

### A02：每请求执行器使用了跨库共享的全局 actor

- 优先级：高
- 位置：`NtkNetworkExecutor`
- 状态：已修正

`NtkNetworkExecutor` 的 `config` 和初始请求快照都属于单个 `NtkNetwork` 实例，但整个类型标记为 `@NtkActor` 后，不相关请求的执行器也共享同一个隔离器。它扩大了调度耦合，并不能表达真实的状态所有权。

处理方式：执行器改为不可变 `final class: Sendable`。`Configuration`、初始请求和拦截器列表在创建时冻结；三个执行入口各自从初始请求快照构建局部请求，不引入独立 actor，也不共享可变请求状态。

### A03：请求上下文使用了跨请求全局隔离

- 优先级：高
- 位置：`NtkInterceptorContext`
- 状态：已修正

`NtkInterceptorContext` 是单次拦截器链的状态容器，却被 `@NtkActor` 隔离。结果是所有请求的上下文读写都依赖同一个全局 actor，而不是只隔离各自请求。

处理方式：`NtkInterceptorContext` 改为每请求 `Sendable struct`，只包含只读 `request` 与按值传递的 `extraData`，删除 `client` 引用。拦截器修改上下文时显式复制并把副本传给下游，源上下文不会被回写。

### A04：公开拦截器协议把第三方业务代码绑定到 NtkActor

- 优先级：高
- 位置：`iNtkInterceptor`、`iNtkRequestHandler`、`NtkInterceptorChainManager`、`iNtkResponseParser`、`NtkResponseParserBox`
- 状态：已修正

协议要求使每个第三方 interceptor/parser 的同步片段都在 `NtkActor` 上执行。重试、日志、业务适配和解析因此共享同一个隔离域，即使实现本身没有共享状态。`await` 会释放 actor，所以这不等于整段请求 I/O 被阻塞，但仍会产生不必要的 actor 跳转、隔离传染和全局同步片段竞争。

处理方式：移除拦截器、请求处理器、响应解析器和请求修改协议上的全局 actor 要求。链条递归调用仍保证请求/响应顺序；实现若持有共享可变状态，由实现自行采用 actor 或锁。

### A05：拦截器链包装层擦除了闭包的 actor 隔离

- 优先级：中
- 位置：`NtkInterceptorChainManager.buildChain`、`NtkInterceptorChainManager.TempHandler`、`NtkRetryInterceptor.retryLoop`
- 状态：已修正

`finalHandler` 声明为 `@NtkActor` 闭包，但 `buildChain` 的返回值和 `TempHandler.handler` 是普通 `@Sendable async` 闭包。链条构建时 actor 隔离被包装层擦除，调用协议 witness 时又进入 actor，形成结构性的反复跳出/跳入。`NtkRetryInterceptor.intercept` 进入 actor 后调用普通 async 的 `retryLoop`，重试时又通过 `next.handle` 回到 actor，也有同类问题；三个只写日志的辅助方法没有异步工作，却被声明为 `async`。

处理方式：`NtkInterceptorChainManager` 改为普通 `Sendable` struct，`finalHandler`、递归链闭包和 `TempHandler` 使用普通 `@Sendable async` 闭包。重试延迟仍保持异步，纯日志辅助方法已改为同步。

### A06：客户端协议把后端 I/O 适配器绑定到 NtkActor

- 优先级：高
- 位置：`iNtkClient.execute`、`AFClient.execute`、`AFClient.sendRequest`
- 状态：已修正

网络客户端通常由底层库负责并发安全，公开协议不应强制所有后端实现进入一个库级 global actor。当前标注会约束第三方 client，并让请求构建和响应收尾同步片段与其他 Ntk 状态共享隔离器。

处理方式：移除 `iNtkClient.execute` 与 `AFClient` 方法上的全局 actor 要求。`AFClient.sendRequest` 现在是普通异步适配方法；第三方 client 可按自身模型使用 actor、锁或底层库同步策略。

### A07：缓存协议和无状态门面使用了 NtkActor

- 优先级：高
- 位置：`iNtkCacheStorage`、`iNtkCacheProvider`、`NtkNetworkCache`
- 状态：已修正

缓存可能是磁盘、数据库、内存 actor 或第三方存储，各实现应拥有自己的同步策略。协议强制 `@NtkActor` 既不能替代存储内部线程安全，也限制了实现方式。`NtkNetworkCache` 只有不可变的 `storage`，类型级隔离本身没有保护对象内可变状态。

处理方式：已移除 `iNtkCacheStorage`、`iNtkCacheProvider` 的协议级全局 actor 要求。`NtkNetworkCache` 改为不可变 `final class: Sendable`，同步创建并只在异步缓存操作中等待存储；它消费 executor 已冻结的 `NtkRequestIdentity`，不拥有过滤、LRU 或身份计算状态。

### A08：NtkActor 不能保证 execute/loadCache 的异步事务原子性

- 优先级：高
- 位置：`NtkNetworkExecutor.execute`、`NtkNetworkExecutor.loadCache`、`NtkNetwork.requestWithCache`
- 状态：已修正

`requestWithCache()` 会并发调用同一 executor 的网络和缓存路径。修正前，两条路径从 executor 的共享 `mutableRequest` 建立 context，并在最终 handler 中写回；由于 actor 在 `await` 处可重入，后写回的旧快照可能覆盖另一条路径已经产生的请求修改。全局 actor 只避免同一同步片段的数据竞争，不提供跨 `await` 的事务一致性。

处理方式：`NtkNetworkExecutor` 只保留创建时冻结的初始请求快照。`execute()`、`loadCache()` 和 `hasCacheData()` 各自从该快照按稳定 interceptor 顺序调用 `iNtkRequestModifyingInterceptor.modifyRequest(_:)`，构建局部请求。进入 `intercept()` 链后 context 请求只读；缓存流程不运行 retry、loading、toast 等普通拦截行为。

### A09：任务管理器需要隔离，但不应使用库级全局 actor

- 优先级：中
- 位置：`NtkTaskManager`
- 状态：已修正

`ongoingRequests` 确实是共享可变状态，需要隔离；问题在于它和客户端、缓存、解析、拦截器共用 `NtkActor`。任务去重状态与这些组件没有共同不变量。

处理方式：`NtkTaskManager` 已改为独立 `actor`，任务表、owner/follower 生命周期和取消控制均由状态所有者自身隔离。请求去重标识生成保持同步，因此取消检查到任务注册之间没有新增跨 actor 重入点。

### A10：请求身份计算不应拥有 actor 或 LRU

- 优先级：中
- 位置：`NtkRequestIdentityBuilder`
- 状态：已修正

请求身份投影是纯函数，不应混入 LRU 或 actor 状态。把身份计算放进共享隔离器会增加不必要的串行化，也模糊缓存、去重与任务调度的职责边界。

处理方式：删除旧管理器及其 LRU。无状态 `NtkRequestIdentityBuilder` 在请求修改、元数据 prune 后生成确定性身份；executor 冻结结果一次并交给缓存和去重。身份失败只关闭这些优化，网络继续。

### A11：Loading/Toast 回调没有 UI 执行保证

- 优先级：中
- 位置：`NtkLoadingInterceptor`、`AFToastInterceptor`
- 状态：待处理

审查时这些拦截器曾因 `iNtkInterceptor` 间接运行在 `NtkActor`，但 `NtkActor` 不是主 actor。名称和用途容易让调用方在回调中直接更新 UI，从而产生错误的线程假设。

建议明确选择一种契约：若库承诺 UI 回调，则将回调声明为 `@MainActor @Sendable` 并显式 `await` 调用；若库只提供事件，则重命名或在公开文档中明确由调用方切换到 `MainActor`。不能把 `NtkActor` 当作 UI 隔离。

### A12：无状态入口和重复隔离标注增加噪声

- 优先级：低
- 位置：`Ntk`、若干协议实现和解析私有方法
- 状态：已修正

`Ntk` 没有实例状态，唯一工厂方法又显式 `nonisolated`，因此类型级 `@NtkActor` 没有实际价值。实现方法重复协议或类型已经给出的隔离标注，会让读者误以为存在额外边界。反过来，在本来非隔离的 struct 中给私有方法添加 `nonisolated` 也没有语义变化。

处理方式：已移除 `Ntk` 类型及其工厂方法的冗余隔离标注，并清理执行器、链条、解析入口、测试与适配器中的重复标注。真实状态所有者迁移为独立 actor 后，生产代码和测试不再引用 `NtkActor`。

### A13：架构文档把“网络相关”误作 actor 边界

- 优先级：低
- 位置：`docs/architecture.md`、`docs/design-decisions.md`、`README.md`、相关源码注释
- 状态：已修正

审查时的文档称 `NtkActor` 用于让“网络相关执行收敛到统一隔离域”，并称 `@NtkActor` 可以保证请求修改串行和状态一致。README 和部分源码注释还把 `NtkNetworkExecutor` 称为“Actor”或“Actor 执行层”。这些表述会鼓励按功能类别而不是按共享状态所有权继续添加标注，也忽略了 actor 在 `await` 处可重入；执行器已经是不可变 `Sendable` 快照。

处理方式：README、当前架构文档和模块指南已改为状态所有权模型：不可变快照和 `Sendable` 负责传递，独立 actor 保护异步状态机，短临界区锁保护同步配置。已删除把网络功能统一调度到同一 global actor 的现行说明。

## 最终迁移结果

1. `NtkTaskManager` 是独立 actor，只拥有运行中任务、等待者生命周期、取消及实例反向索引；它不重新计算请求键。
2. `NtkRequestIdentityBuilder` 是无状态投影器；`NtkNetworkCache` 成为消费既有身份的不可变 `Sendable` 门面，`NtkInterceptorContext` 与 `NtkNetworkExecutor` 继续采用值流和不可变快照。
3. README、架构文档与模块注释已移除“网络功能统一运行在 NtkActor”的过时描述。
4. 生产代码和测试中的属性引用清零后，`NtkActor` 声明已删除。
5. Loading/Toast 的 `MainActor` 契约作为独立 UI 决策保留，不用网络 global actor 代替主线程保证。

迁移各阶段均运行针对性测试与 Swift 6 严格并发检查；最终删除后运行全量测试。`async` 仍只表达可能等待，不单独构成 actor 隔离理由。
