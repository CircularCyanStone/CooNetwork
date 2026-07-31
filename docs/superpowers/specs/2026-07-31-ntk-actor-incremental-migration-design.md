# NtkActor 增量迁移设计

## 状态

核心流水线方案已确认，待用户审阅书面版本。本文只确定迁移顺序和判断标准，不直接改变运行时行为。

## 目标

逐步清理没有状态所有权依据的 `@NtkActor`，同时把可以安全跨并发域传递的不可变类型显式声明为 `Sendable`。每一批改动都保持可编译、可验证，并通过剩余引用重新评估后续范围。

本次允许源码级破坏性调整，但不引入与 `iNtkInterceptor` 平级的新公共概念，也不改变请求、缓存、重试、去重和解析的既有职责。

## 推进原则

1. 先判断状态所有权，再决定是否需要隔离。
2. 没有可变状态的类型不因为“属于网络模块”而保留全局 actor。
3. 真正共享的可变状态必须迁移到明确的独立 actor、锁或 `MainActor`。
4. `async` 只表示可能等待，不单独构成 actor 隔离理由。
5. 每批修改后运行针对性测试，并检查剩余 `@NtkActor` 引用。

## 阶段一：核心流水线解除全局 actor 绑定

本阶段一次处理互相依赖的无状态执行流水线，避免留下普通闭包与 actor 闭包互相包装的中间模型。

### Executor

- `NtkNetworkExecutor`：删除类型级 `@NtkActor`，保留冻结配置和初始请求快照。
- `Ntk`：删除类型级 `@NtkActor`；工厂方法已经是 `nonisolated`，类型没有实例状态。

`NtkNetworkExecutor` 改为 `final class: Sendable`，并让 `Configuration`、`ResponseResult` 显式满足 `Sendable`。执行方法继续从 `initialRequest` 创建局部请求，不保存动作期间的可变状态。

### 每请求 Context

`NtkInterceptorContext` 从 `@NtkActor final class` 改为 `Sendable struct`：

- `request` 保持只读；
- `extraData` 保持值类型属性；
- 删除没有被 interceptor 使用的 `client`；
- executor 的 final handler 直接捕获冻结配置中的 client。

需要写入链内数据的 interceptor 创建 context 副本并显式传给下游。数据只沿请求方向传播；上游不依赖下游对副本的回写。当前生产代码没有修改 `context.extraData`，因此该语义收紧不会改变内置功能。

### Interceptor Chain

`NtkInterceptorChainManager` 改为普通 `Sendable` 结构：

- `finalHandler` 使用普通 `@Sendable async` 闭包；
- `buildChain` 返回相同类型的普通异步闭包；
- `TempHandler.handler` 不再擦除或恢复 actor 隔离；
- 链条顺序继续由逐层 `await next.handle(...)` 保证。

全局 actor 并不能阻止第三方 interceptor 主动并发或重复调用 `next`，因为 actor 在 `await` 处允许重入；因此它不是责任链顺序保证的来源。

### 公开协议

移除以下公开要求上的 `@NtkActor`：

- `iNtkInterceptor.intercept`
- `iNtkRequestModifyingInterceptor.modifyRequest`
- `iNtkRequestHandler`
- `iNtkResponseParser.intercept`
- `iNtkClient.execute`
- `iNtkCacheProvider`
- `iNtkCacheStorage`

这些协议继续要求 `Sendable`。无状态值类型实现可以直接并发使用；有状态实现可以自行采用独立 actor、`MainActor` 或锁。普通 `Sendable` async 协议允许 actor-isolated witness，因此移除协议级 global actor 不会限制实现者选择自己的隔离方式。

同步清理 `NtkResponseParserBox`、`NtkDataParsingInterceptor`、`NtkRetryInterceptor`、`AFClient` 等内置实现中只为满足上述要求而存在的标注。重试延迟和下游调用继续保持异步；纯日志辅助方法改为同步。

### 暂时保留的隔离

本阶段暂不迁移：

- `NtkTaskManager` 和请求标识 LRU
- `NtkNetworkCache`

它们仍持有或依赖真实共享可变状态。核心流水线可通过显式 `await` 调用这些剩余的 actor-isolated 类型，待本阶段验证后再单独处理其状态所有权。

## 阶段二：审计剩余引用

阶段一完成后，使用剩余引用和编译器诊断重新评估：

- 列出每个剩余 `@NtkActor` 所保护的具体可变状态；
- 区分进程级共享状态、对象自有状态、UI 状态和无状态方法；
- 不以引用数量或减少 hop 作为唯一删除依据；
- 不保留“属于网络模块”这一功能分类式隔离理由。

## 阶段三：真实共享状态迁移

后续只处理有明确共享可变状态的模块：

- `NtkTaskManager`：独立 `actor`，保护去重任务表及 owner/follower 生命周期。
- `NtkRequestIdentifierManager`：保留同步调用界面，用锁保护 LRU；请求标识哈希计算保持非隔离纯函数。
- UI Loading/Toast：如果库承诺 UI 回调，改用 `@MainActor @Sendable`；否则保留事件语义并明确调用方责任。

## `NtkActor` 的最终处理

不预先承诺删除 `NtkActor.swift`。完成各阶段后检查剩余引用：

- 若没有真实的进程级共享可变状态需要同一隔离域，删除声明；
- 若仍存在明确的全局不变量，保留 `@globalActor`，但只用于该不变量，并在架构文档中说明它不代表“所有网络代码统一执行”。

## 验收标准

- 阶段一后 executor 可从任意并发任务安全共享，且网络/缓存请求仍从独立快照构建。
- 每次请求和缓存分支拥有独立的 context 值，链内数据只显式向下游传播。
- interceptor、parser、client 和 cache adapter 不再被公开协议强制绑定到 `NtkActor`。
- actor、`MainActor` 和锁保护的第三方实现仍可满足对应 async 协议。
- interceptor 顺序、短路、重试、解析、缓存和错误传播行为保持不变。
- 每阶段 `swift test` 通过，且新增针对并发共享 executor 的回归测试。
- 每阶段记录剩余 `@NtkActor` 用途，不以引用数量作为唯一删除标准。
