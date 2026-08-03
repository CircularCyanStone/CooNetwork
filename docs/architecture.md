# Architecture

## 设计目标

为不同网络组件提供统一接入方式，使用 Swift 6 并发模型确保线程安全。

## 核心架构：状态所有权

1. **配置层 (`NtkNetwork`)** — Builder 模式类，使用短临界区锁保护同步配置和请求快照，保留链式调用接口。
2. **执行层 (`NtkNetworkExecutor`)** — 不可变 `Sendable` 执行快照；每次动作从初始请求创建局部值，不共享动作期间的可变状态。
3. **状态所有者** — `NtkTaskManager` 是唯一的任务状态 actor，拥有运行中任务及 `instanceIdentifier` 到运行时键的反向索引；它不生成请求身份。

`NtkRequestIdentityBuilder` 是无状态的确定性投影器：请求修改器完成后，executor 对该路径冻结一次身份，并把同一结果放入不可变 context。缓存与去重消费该身份；身份不可用时两项优化关闭而网络继续。缓存键只描述资源，去重再以结构化身份加入响应类型、有效超时和执行 namespace。

actor 隔离按共享可变状态的所有权划分，不按“网络功能”统一调度。无状态模块和只读快照使用 `Sendable`；短小、同步且不跨 `await` 的配置临界区使用锁。

## 拦截器优先级

使用三层 Tier 结构（`outer` > `standard` > `inner`）控制拦截器执行顺序，构成洋葱模型。同 Tier 内再比 value（降序）。统一使用 `NtkInterceptorPriority` 结构体。

- **outer tier**：最外层，请求流最先执行，响应流最晚返回。框架专用（Dedup 用 `outerHighest`）。
- **standard tier**：业务拦截器默认层级，暴露 `low(250)` / `medium(750)` / `high(1000)` 给用户使用。
- **inner tier**：最内层，请求流最晚执行，响应流最先返回。框架专用（ResponseParser 用 `innerHigh`，CacheInterceptor 用 `innerLow`）。

业务拦截器只应使用 `standard` tier 的常量（`.low` / `.medium` / `.high`），`outer`/`inner` 为框架内部保留。

## iNtkResponseParser 协议

响应解析与拦截器解耦：`iNtkResponseParser` 不直接实现 `iNtkInterceptor`，由框架通过 `NtkResponseParserBox` 包装为优先级锁定为 `innerHigh` 的拦截器注入链中。实现者无需也无法干预优先级。

## 数据解析架构

响应解析采用稳定的多阶段流水线：payload 先经过 `normalize`，再执行 `transformers`，随后由 decoder 解释协议数据，最后由 policy 决定最终 outcome。

- **parser / interceptor**：负责流程编排与阶段衔接，不承担最终成功/失败裁决
- **decoder**：负责解释 payload，并在必要时恢复最小 header 信息，不直接决定最终结果
- **policy**：唯一允许影响最终 outcome 的裁决层，统一处理 validation、header fallback、空 data、`NtkNever` 等规则
- **hooks**：只做日志、埋点、广播等观察型副作用，不参与裁决，也不改写最终结果

最小术语对照：
- **normalize**：payload 入口结构 gate，决定原始响应是否能进入解析流水线
- **transformers**：payload 预处理层，负责解密、解包、结构改写等输入改造
- **decoder**：协议解释层，负责 decode 与最小 header 恢复
- **policy**：结果裁决层，负责输出最终成功或最终错误
- **hooks**：只读观察点，负责旁路副作用

这套边界的目标是把“解释输入”和“决定结果”分离，避免 parser 再次退化为规则汇聚点。

## 执行器生命周期与状态一致性

单个 `NtkNetwork` 复用同一个 `NtkNetworkExecutor` 及其冻结配置。每次 `execute()`、`loadCache()`、`hasCacheData()` 都从初始请求快照创建局部请求；`requestWithCache()` 的网络和缓存分支共享 executor，但不共享本次动作的请求值。

缓存读取不会重跑完整拦截器链。只有显式遵循 `iNtkRequestModifyingInterceptor` 的 interceptor 才会在 context 创建前参与请求构建；随后 prune 元数据、解析有效超时并只构建一次身份。普通 `intercept()` 只能读取最终请求。请求修改器按 priority 降序执行，同 priority 保持注册顺序。

## 后端适配边界

核心层负责抽象与通用执行链，具体网络后端只负责适配：

- **核心抽象**：`iNtkClient`、`iNtkRequest`、`iNtkResponse`、`iNtkInterceptor`
- **核心通用能力**：并发隔离、拦截器链、去重、缓存、解析流水线
- **后端适配层**：如 AlamofireClient，负责把具体库语义翻译到核心抽象，不反向污染核心层

新增后端时，应优先通过稳定扩展点承接差异：实现 `iNtkClient`、提供适配用 decoder / transformer、配置 parser / policy / hooks。核心模块不应直接引入具体后端类型，也不应为了单一后端语义反向修改核心抽象。

## fatalError 策略

仅用于开发期契约错误（无法恢复 + 状态不可信 + 内部强约束）。运行期可恢复异常一律 `throw`。

当前保留项：`AFClient.execute`、`NtkDataParsingInterceptor`（请求类型必须是 iAFRequest）、`iNtkClient.cancel` 默认实现。

新增需 PR 写明契约定义、为何不能 throw、失败后状态影响。

## 相关文档

- [设计决策记录](./design-decisions.md) — 经评审确认的刻意设计，code review 前请先查阅
