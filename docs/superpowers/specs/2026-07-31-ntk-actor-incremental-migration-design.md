# NtkActor 增量迁移设计

## 状态

待用户审阅。本文只确定迁移顺序和判断标准，不直接改变运行时行为。

## 目标

逐步清理没有状态所有权依据的 `@NtkActor`，同时把可以安全跨并发域传递的不可变类型显式声明为 `Sendable`。每一批改动都保持可编译、可验证，并通过剩余引用重新评估后续范围。

本次允许源码级破坏性调整，但不引入与 `iNtkInterceptor` 平级的新公共概念，也不改变请求、缓存、重试、去重和解析的既有职责。

## 推进原则

1. 先判断状态所有权，再决定是否需要隔离。
2. 没有可变状态的类型不因为“属于网络模块”而保留全局 actor。
3. 真正共享的可变状态必须迁移到明确的独立 actor、锁或 `MainActor`。
4. `async` 只表示可能等待，不单独构成 actor 隔离理由。
5. 每批修改后运行针对性测试，并检查剩余 `@NtkActor` 引用。

## 阶段一：无状态入口清理

先处理不承担可变状态保护、且不依赖协议隔离契约的类型：

- `NtkNetworkExecutor`：删除类型级 `@NtkActor`，保留冻结配置和初始请求快照。
- `Ntk`：删除类型级 `@NtkActor`；工厂方法已经是 `nonisolated`，类型没有实例状态。
- 其他只有不可变存储、且当前调用链允许独立移除的无状态门面，逐个以编译结果确认，不做机械批量删除。

`NtkNetworkExecutor` 改为 `final class: Sendable`，并让 `Configuration`、`ResponseResult` 显式满足 `Sendable`。执行方法继续从 `initialRequest` 创建局部请求，不保存动作期间的可变状态。

本阶段暂不修改：

- `NtkInterceptorContext`
- `iNtkInterceptor`、`iNtkClient`、缓存协议等公开协议
- `NtkInterceptorChainManager`
- `NtkTaskManager` 和请求标识 LRU

这样可以先验证 executor 的不可变快照模型，而不引入整条调用链的隔离迁移。

## 阶段二：基于剩余引用决定流水线迁移

阶段一完成后，使用剩余引用和编译器诊断重新评估：

- 如果 executor 仅产生预期的协议 actor hop，记录并进入下一阶段；
- 不因为减少 hop 而改变仍然拥有共享状态的类型；
- 只有在明确确认 context/chain 的共享状态可改为每请求值流后，才移除对应协议级 `@NtkActor`。

此阶段将单独设计 `NtkInterceptorContext.extraData` 的语义，不在阶段一隐式改变上下游可见性。

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
- 无状态入口不再要求调用方进入 `NtkActor`。
- 尚未迁移的协议和 context 行为保持不变。
- 每阶段 `swift test` 通过，且新增针对并发共享 executor 的回归测试。
- 每阶段记录剩余 `@NtkActor` 用途，不以引用数量作为唯一删除标准。
