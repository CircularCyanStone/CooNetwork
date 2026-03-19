# Architecture

## 设计目标

为不同网络组件提供统一接入方式，使用 Swift 6 并发模型确保线程安全。

## 核心架构：双层设计

1. **配置层 (NtkNetwork)** — 非 Actor 的 Builder 模式类，支持同步链式调用，使用 `@unchecked Sendable` 配合内部锁保护可变状态
2. **执行层 (NtkNetworkExecutor)** — Actor 类，处理请求执行和拦截器链调用，所有执行逻辑在隔离域内

配置方法需要支持链式调用，而执行逻辑需要并发隔离。单层设计要么无法链式调用，要么无法保证线程安全。

## @NtkActor 机制

`@NtkActor` 是自定义 `@globalActor`，将网络相关执行收敛到统一隔离域，隔离范围限制在网络模块内部。不使用 MainActor 或默认全局并发上下文，减少不必要的跨域传递。

## 拦截器优先级

高优先级 (1000) 先执行请求流 / 后执行响应流，中等 (750) 默认，低 (250) 反之。统一使用 `NtkInterceptorPriority` 结构体。

## fatalError 策略

仅用于开发期契约错误（无法恢复 + 状态不可信 + 内部强约束）。运行期可恢复异常一律 `throw`。

当前保留项：`AFClient.execute`、`AFDataParsingInterceptor`（请求类型必须是 iAFRequest）、`iNtkClient.cancel` 默认实现。

新增需 PR 写明契约定义、为何不能 throw、失败后状态影响。

## 相关文档

- [设计决策记录](./design-decisions.md) — 经评审确认的刻意设计，code review 前请先查阅
