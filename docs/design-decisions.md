# 设计决策记录

经评审确认的刻意设计。code review 时请勿将以下设计作为问题提出。

## 并发安全

- **NtkNetwork 使用 `@unchecked Sendable`** — 避免 Actor 传染性，配置层需在任意线程初始化且支持链式调用，内部通过 `lock.withLock` 保护可变状态，执行委托给 Actor
- **NtkUnfairLock 使用 `@unchecked Sendable`** — `os_unfair_lock` 是 C 类型，封装后通过锁保护内部状态，`@unchecked Sendable` 是唯一可行方案
- **NtkMutableRequest struct 拷贝不会状态不一致** — 拦截器只读访问，修改需显式赋值回 context，`@NtkActor` 保证串行执行

## 类型安全

- **NtkReturnCode.encode 使用 `try?`** — 防御性设计，`_type`/`rawValue` 由同一 init 设置不会不一致，生产环境不崩溃优先于严格错误传播
- **NtkDynamicData 中的 `as! T`** — switch type 已约束 T 的类型，不存在失败路径；rawValue/valueType 私有存储，构造方法同步设置
- **NtkDataParsingInterceptor 的 `NtkNever() as! ResponseData`** — 前置 `is NtkNever.Type` 检查已确认类型，Swift 泛型不支持类型精化，`as!` 是标准做法

## 架构模式

- **拦截器三层 Tier 优先级（outer / standard / inner）** — 框架核心逻辑（Dedup、ResponseParser、Cache）需要与业务拦截器严格隔离，不能依赖 value 数值约定；三层 Tier 在编译期区分身份，业务层只能使用 `standard`，框架层使用 `outer`/`inner`，任何越界一看即知
- **iNtkResponseParser 与 iNtkInterceptor 解耦** — 解析器是框架感知的核心组件，优先级必须由框架控制（`innerHigh`）；若直接实现 `iNtkInterceptor`，使用者可任意覆写 priority，破坏执行顺序保证；通过 `NtkResponseParserBox` 包装后优先级锁死，实现者无需也无法干预
- **NtkDataParsingInterceptor 位于 CooNetwork 而非 AlamofireClient** — 解析逻辑（`NtkPayload` normalize + `iNtkResponsePayloadTransforming` + `iNtkResponsePayloadDecoding` + `iNtkParsingHooks`）与具体网络库无关；放在核心层让非 AF 客户端（如 mPaaS）也可复用，只需提供自定义 transformer / decoder
- **AFClient 依赖 Alamofire 类型** — 适配器模式的正确应用，`iNtkClient` 协议是抽象层，AFClient 负责翻译为具体调用，再加一层才是过度抽象
- **NtkError 使用最小顶层 + 域错误直抛模型** — `NtkError` 只保留跨域公共错误（如 `invalidRequest`、`invalidResponseType`、`requestTimeout` 等）；`NtkError.Validation`、`NtkError.Serialization`、`NtkError.Client`、`NtkError.Cache` 作为正式域错误类型直接抛出与捕获。框架不再使用 `responseValidationFailed(reason:)`、`responseSerializationFailed(reason:)`、`clientFailed(reason:)` 这类无信息增量的顶层包装 case，消费端按“具体域优先，顶层兜底”的顺序处理错误。
- **NtkNetworkExecutor 三个方法的拦截器链构建"重复"** — 组合策略和错误处理完全不同，仅排序逻辑重复（已提取为 `sortInterceptors`），强行统一降低可读性

## 数据解析职责边界

- **parser 只负责解释流程，不负责最终裁决** — `NtkDataParsingInterceptor` 的职责是编排 acquire / prepare / interpret / decide / notify 阶段，避免把规则继续堆回 parser 中央
- **policy 是唯一 outcome 决策点** — `validation`、header fallback、`NtkNever`、空 data 等最终成功/失败判断统一收口到 policy，避免多处共同裁决
- **hooks 只保留 observer 语义** — hooks 只做日志、埋点、广播等旁路副作用；不吞错、不恢复、不改结果
- **decoder 负责协议解释，不负责命运裁决** — `extractHeader` 仍属于解释 payload 的一部分，但 fallback 后返回什么错误或是否放行，必须由 policy 决定

## 错误模型与错误消费约定

- **顶层公共错误与域错误分层消费** — 调用方优先捕获 `NtkError.Validation`、`NtkError.Serialization`、`NtkError.Client`、`NtkError.Cache` 等具体域错误；顶层 `NtkError` 只负责跨域公共语义兜底
- **边界错误语义固定** — `invalidRequest`、`invalidResponseType`、`invalidTypedResponse` 分别对应请求构造边界、响应形态边界、最终类型交付边界，不互相兜底，不再复用模糊错误语义
- **避免为简单错误再包一层领域壳** — 简单且稳定的失败直接用顶层 case；只有需要额外上下文的复杂错误才进入正式域错误类型

## 执行器一致性

- **单次请求共享 executor 是刻意设计** — `requestWithCache()`、普通请求和相关执行路径必须复用同一个 `NtkNetworkExecutor`，以保证 `mutableRequest`、拦截器修改和上下文状态的一致性

## 目录与模块归属原则

- **按职责分层，不按临时实现堆叠** — 协议、模型、解析器、后端适配层应各自收敛，不把长期边界建立在一次性搬迁步骤上
- **核心模块优先承载跨后端通用能力** — 解析流水线、拦截器链、错误模型等应留在核心层；具体 client 差异由适配层吸收

## 其他

- **缓存过期用时间戳比较** — `timeIntervalSince1970` 是 UTC 秒数，与时区无关，性能优于创建 Date 对象
- **NtkLogger 日志级别** — `log()` 方法已实现级别检查，所有便捷方法均经过检查，无绕过调用
- **NtkCacheMeta 用 NSSecureCoding 不用 Codable** — 设计定位为接口缓存，NSSecureCoding 满足 OC 组件存储需求，Codable 非核心需求
