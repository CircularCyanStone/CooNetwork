# NtkActor 增量迁移设计

## 状态

核心流水线迁移已完成；剩余状态所有者的隔离方案和删除 `NtkActor` 的最终决策已确认。本文只确定迁移顺序和判断标准，不直接改变运行时行为。

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
- `NtkRequestIdentifierManager`：独立 `actor`，保护缓存键 LRU；请求去重标识哈希计算保持 `nonisolated` 纯函数。
- `NtkNetworkCache`：移除 `@NtkActor`，改为不可变 `final class: Sendable`；缓存键生成通过 `await` 访问独立的标识符 actor。
- UI Loading/Toast：如果库承诺 UI 回调，改用 `@MainActor @Sendable`；否则保留事件语义并明确调用方责任。

### 隔离选择依据

`NtkTaskManager` 管理包含 `await` 和可重入点的异步任务生命周期，独立 actor 能让编译器检查任务表访问，同时把调度域限制在任务状态所有者内。

`NtkRequestIdentifierManager` 的 LRU 是一个完整的共享可变数据结构。虽然短同步临界区可以用锁实现，但当前公开类型已经受 global actor 隔离，普通调用方本来就需要跨隔离域 `await`；而唯一生产缓存调用方也处于 async 流程。改成独立 actor 不会把异步要求传播到同步业务接口，并能避免 `@unchecked Sendable` 和人工锁约束。

`getRequestIdentifier` 不访问 LRU。它及其纯计算辅助方法保持 `nonisolated`，使 `NtkTaskManager` 能在取消检查和任务注册之间同步生成标识符，不新增跨 actor `await` 和可重入点。

`NtkNetwork` 继续使用短临界区锁保护同步配置和请求快照。其链式配置接口天然同步，没有异步状态机；将其改为 actor 会把 `await` 传播到配置接口而没有相应收益。actor 和锁按状态操作形态选择，不以语言特性新旧作为判断依据。

### 调用关系

- `NtkTaskManager` 同步调用 `NtkRequestIdentifierManager.shared.getRequestIdentifier` 的非隔离纯计算路径。
- `NtkNetworkCache` 在已有 async 方法中等待 `NtkRequestIdentifierManager.shared.getCacheKey`。
- `NtkCacheInterceptor` 同步创建 `NtkNetworkCache`，只在缓存读写和缓存键 actor 调用处等待。
- `NtkRequestIdentifierManager.requestCache` 当前没有读取点，迁移时删除；LRU 的真实状态由节点索引和链表共同组成。

## `NtkActor` 的最终处理

三个剩余生产使用点之间不存在必须在同一隔离域维护的共同不变量：任务表、缓存键 LRU 和缓存门面分别拥有独立状态语义。完成阶段三后删除 `NtkActor.swift`，并清理测试、README、架构文档和源码注释中的遗留引用。

删除的是不再成立的公开隔离概念，不是共享实例模式。`NtkTaskManager.shared` 和 `NtkRequestIdentifierManager.shared` 继续存在，各自通过独立 actor 保护自身状态。

## 验收标准

- 阶段一后 executor 可从任意并发任务安全共享，且网络/缓存请求仍从独立快照构建。
- 每次请求和缓存分支拥有独立的 context 值，链内数据只显式向下游传播。
- interceptor、parser、client 和 cache adapter 不再被公开协议强制绑定到 `NtkActor`。
- actor、`MainActor` 和锁保护的第三方实现仍可满足对应 async 协议。
- interceptor 顺序、短路、重试、解析、缓存和错误传播行为保持不变。
- `NtkTaskManager` 与缓存键 LRU 不再共享串行执行器，且去重标识生成不会给任务状态机新增可重入点。
- `NtkNetworkCache` 可跨并发域安全共享；标识符 LRU 的全部可变访问由独立 actor 隔离。
- 生产代码和测试不再引用 `NtkActor`，过时的全局网络执行域文档被删除或改写。
- 每阶段 `swift test` 通过，且新增针对并发共享 executor 的回归测试。
- 每阶段记录剩余 `@NtkActor` 用途，不以引用数量作为唯一删除标准。
