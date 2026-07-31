# NtkActor 使用审查

审查日期：2026-07-31

审查范围：`Sources/CooNetwork`、`Sources/AlamofireClient` 中所有 `@NtkActor` 使用点，以及与它们直接关联的公开协议、请求上下文和解析流水线。

## 结论

`@NtkActor` 当前承担了过多职责：它既被用来保护共享可变状态，也被当作“所有网络代码的统一执行上下文”。后者不是 actor 的合理边界。是否属于网络流程、方法是否为 `async`，都不能单独构成使用全局 actor 的理由。

合理的隔离边界应由状态所有权决定：

- 真正的进程级共享可变状态，才考虑全局 actor。
- 单个对象拥有的可变状态，优先使用独立 `actor` 或内部锁。
- 单次请求拥有的状态，优先使用每请求 actor、任务内顺序执行或值快照。
- 无共享可变状态的 I/O、解析、校验和适配代码，不需要 `@NtkActor`。
- UI 副作用需要的是 `@MainActor`，`@NtkActor` 不提供主线程保证。

Actor 在 `await` 处允许重入。它只保证同一时刻 actor 隔离代码的同步片段不会并发执行，不保证一个异步方法从入口到返回构成原子事务，也不会让多个步骤天然保持快照一致性。

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
- 状态：部分修正

缓存可能是磁盘、数据库、内存 actor 或第三方存储，各实现应拥有自己的同步策略。协议强制 `@NtkActor` 既不能替代存储内部线程安全，也限制了实现方式。`NtkNetworkCache` 只有不可变的 `storage`，类型级隔离本身没有保护对象内可变状态。

处理方式：已移除 `iNtkCacheStorage`、`iNtkCacheProvider` 的协议级全局 actor 要求；`NtkCacheInterceptor` 在调用仍为 actor 的 `NtkNetworkCache` 时显式跨隔离边界。`NtkNetworkCache` 的状态所有者/LRU 迁移仍待后续批次，因此本项不宣称全部完成。

### A08：NtkActor 不能保证 execute/loadCache 的异步事务原子性

- 优先级：高
- 位置：`NtkNetworkExecutor.execute`、`NtkNetworkExecutor.loadCache`、`NtkNetwork.requestWithCache`
- 状态：已修正

`requestWithCache()` 会并发调用同一 executor 的网络和缓存路径。修正前，两条路径从 executor 的共享 `mutableRequest` 建立 context，并在最终 handler 中写回；由于 actor 在 `await` 处可重入，后写回的旧快照可能覆盖另一条路径已经产生的请求修改。全局 actor 只避免同一同步片段的数据竞争，不提供跨 `await` 的事务一致性。

处理方式：`NtkNetworkExecutor` 只保留创建时冻结的初始请求快照。`execute()`、`loadCache()` 和 `hasCacheData()` 各自从该快照按稳定 interceptor 顺序调用 `iNtkRequestModifyingInterceptor.modifyRequest(_:)`，构建局部请求。进入 `intercept()` 链后 context 请求只读；缓存流程不运行 retry、loading、toast 等普通拦截行为。

### A09：任务管理器需要隔离，但不应使用库级全局 actor

- 优先级：中
- 位置：`NtkTaskManager`
- 状态：待处理

`ongoingRequests` 确实是共享可变状态，需要隔离；问题在于它和客户端、缓存、解析、拦截器共用 `NtkActor`。任务去重状态与这些组件没有共同不变量。

建议将 `NtkTaskManager` 改为独立 `actor`。这能保留正确的数据竞争保护，同时把任务表的调度域限制在其真实所有者内。

### A10：请求标识管理器混合了有状态 LRU 与纯计算

- 优先级：中
- 位置：`NtkRequestIdentifierManager`
- 状态：待处理

缓存键 LRU 需要隔离，但请求去重标识计算是纯函数。类型级 `@NtkActor` 让两者都进入全局隔离器，还把哈希计算放进同一个串行同步片段。

建议把 LRU 状态放入独立 actor 或锁保护对象；把纯哈希构建提取为非隔离函数。`getRequestIdentifier` 不应要求 actor hop。

### A11：Loading/Toast 回调没有 UI 执行保证

- 优先级：中
- 位置：`NtkLoadingInterceptor`、`AFToastInterceptor`
- 状态：待处理

这些拦截器因 `iNtkInterceptor` 间接运行在 `NtkActor`，但 `NtkActor` 不是主 actor。名称和用途容易让调用方在回调中直接更新 UI，从而产生错误的线程假设。

建议明确选择一种契约：若库承诺 UI 回调，则将回调声明为 `@MainActor @Sendable` 并显式 `await` 调用；若库只提供事件，则重命名或在公开文档中明确由调用方切换到 `MainActor`。不能把 `NtkActor` 当作 UI 隔离。

### A12：无状态入口和重复隔离标注增加噪声

- 优先级：低
- 位置：`Ntk`、若干协议实现和解析私有方法
- 状态：部分修正

`Ntk` 没有实例状态，唯一工厂方法又显式 `nonisolated`，因此类型级 `@NtkActor` 没有实际价值。实现方法重复协议或类型已经给出的隔离标注，会让读者误以为存在额外边界。反过来，在本来非隔离的 struct 中给私有方法添加 `nonisolated` 也没有语义变化。

处理方式：已移除 `Ntk` 类型及其工厂方法的冗余隔离标注，并清理执行器、链条和解析私有入口的重复标注。剩余 `@NtkActor` 仅属于尚未迁移的状态所有者；后续随状态模块审计继续处理。

### A13：架构文档把“网络相关”误作 actor 边界

- 优先级：低
- 位置：`docs/architecture.md`、`docs/design-decisions.md`、`README.md`、相关源码注释
- 状态：待处理

当前文档称 `NtkActor` 用于让“网络相关执行收敛到统一隔离域”，并称 `@NtkActor` 可以保证请求修改串行和状态一致。README 和部分源码注释还把 `NtkNetworkExecutor` 称为“Actor”或“Actor 执行层”。这些表述会鼓励按功能类别而不是按共享状态所有权继续添加标注，也忽略了 actor 在 `await` 处可重入；当前执行器已经是不可变 `Sendable` 快照。

建议在核心迁移方案确定后更新架构文档：明确 actor 解决数据竞争，不负责把整个功能域调度到同一处；区分 `actor` 类型和 `@globalActor` 隔离类。

## 推荐迁移顺序

1. 继续审计 `NtkTaskManager`、请求标识 LRU 和 `NtkNetworkCache`，将共享状态与纯计算拆开，并为各状态所有者选择独立 actor 或锁。
2. 明确 Loading/Toast 的 `MainActor` 契约：若库承诺 UI 回调则显式标注并切换，否则在文档中声明由调用方负责。
3. 更新架构文档、README 与模块注释，移除“网络功能统一运行在 NtkActor”一类过时描述。
4. A09-A13 的每个后续变更继续运行全量测试与 Swift 6 严格并发检查。
5. 在状态所有者迁移后，再决定是否删除 `NtkActor` 声明本身。

每一步都应运行全量测试与 Swift 6 严格并发检查。涉及 executor/context 的步骤还必须增加多请求并发、缓存与网络交错、重试期间上下文一致性测试。

## 不应机械删除的标注

- `NtkNetworkCache`、`NtkTaskManager`、请求标识 LRU 的状态仍需隔离，只是隔离器选错了；本批次没有机械删除这些标注。
- `NtkInterceptorContext` 与 `NtkNetworkExecutor` 已采用值流和不可变快照，不需要再引入独立 actor。
- `async` 不代表需要 actor，反过来移除 actor 也不代表应移除 `async`。会等待外部资源或允许异步扩展的 API 可以继续保持 `async`。
