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
- **NtkError 使用事件式顶层 + 独立子错误类型** — 顶层 `NtkError` 只表达公共失败事件（如 `invalidRequest`、`invalidResponseType`、`requestTimeout`、`clientFailed`），不再按 request/response/serialization/validation/client 五域建模；复杂错误下沉到 `NtkResponseSerializationError`、`NtkResponseValidationError`、`NtkClientError`，其中 AF 作为官方维护的 client 子空间，经 `NtkError.clientFailed(reason: .af(...))` 暴露，而不是继续使用旧的 `NtkError.AF` 嵌套枚举体系
- **NtkNetworkExecutor 三个方法的拦截器链构建"重复"** — 组合策略和错误处理完全不同，仅排序逻辑重复（已提取为 `sortInterceptors`），强行统一降低可读性

## 其他

- **缓存过期用时间戳比较** — `timeIntervalSince1970` 是 UTC 秒数，与时区无关，性能优于创建 Date 对象
- **NtkLogger 日志级别** — `log()` 方法已实现级别检查，所有便捷方法均经过检查，无绕过调用
- **NtkCacheMeta 用 NSSecureCoding 不用 Codable** — 设计定位为接口缓存，NSSecureCoding 满足 OC 组件存储需求，Codable 非核心需求
