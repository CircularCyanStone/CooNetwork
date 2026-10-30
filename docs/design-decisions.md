# 设计决策记录

经评审确认的刻意设计。code review 时请勿将以下设计作为问题提出。

## 并发安全

- **NtkNetwork 使用 `@unchecked Sendable`** — 避免 Actor 传染性，配置层需在任意线程初始化且支持链式调用，内部通过 `lock.withLock` 保护可变状态，执行委托给 Actor
- **NtkUnfairLock 使用 `@unchecked Sendable`** — `os_unfair_lock` 是 C 类型，封装后通过锁保护内部状态，`@unchecked Sendable` 是唯一可行方案
- **NtkMutableRequest struct 作为请求快照传递** — `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 返回新的请求值；进入拦截器链后只能读取 `NtkInterceptorContext.request`

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
- **NtkNetworkExecutor 三个方法的拦截器链构建"重复"** — 组合策略和错误处理完全不同，仅排序逻辑由 `NtkInterceptorOrdering` 统一，强行统一其余流程会降低可读性

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

- **单次请求共享 executor 是刻意设计** — `requestWithCache()`、普通请求和相关执行路径复用同一个 `NtkNetworkExecutor`，以共享冻结的请求配置和 cache provider；每条执行路径拥有独立的 `NtkInterceptorContext`，拦截器修改不会通过 executor 的可变请求状态互相覆盖
- **请求修改是显式 interceptor 能力** — 基础 `iNtkInterceptor` 不提供默认修改方法；只有 `iNtkRequestModifyingInterceptor` 参与 `execute()`、`loadCache()`、`hasCacheData()` 的请求构建阶段，同 priority 保持注册顺序

## 请求 key 不变量

- **缓存配置与请求 key 策略分离** — `NtkCacheConfiguration` 只控制缓存启用、时长和写入资格，不改变请求 key；`NtkRequestIdentityPolicy` 专门筛选或转换 Header/参数。请求级非 `nil` policy 完整替换冻结的全局 policy，字段级 `.include`/`.exclude` 优先于 policy；Header 名按 HTTP 语义大小写不敏感，参数名精确区分大小写。
- **请求 key 构建失败是优化降级，不是 `NtkError`** — 不支持的值或字段转换闭包失败只禁用该路径的缓存与共享执行，网络仍继续；这样内部 key 实现细节不会变成业务错误契约。
- **去重键保持执行语义隔离** — `NtkDeduplicationKey` 使用 `ObjectIdentifier(ResponseData.self)` 区分响应类型，并以结构化字段纳入已解析的 effective timeout 与 namespace，避免字符串拼接和不同执行流水线误共享。

## 目录与模块归属原则

- **按职责分层，不按临时实现堆叠** — 协议、模型、解析器、后端适配层应各自收敛，不把长期边界建立在一次性搬迁步骤上
- **核心模块优先承载跨后端通用能力** — 解析流水线、拦截器链、错误模型等应留在核心层；具体 client 差异由适配层吸收

## 其他

- **缓存过期用时间戳比较** — `timeIntervalSince1970` 是 UTC 秒数，与时区无关，性能优于创建 Date 对象
- **NtkLogger 日志级别** — `log()` 方法已实现级别检查，所有便捷方法均经过检查，无绕过调用
- **NtkCacheMeta 用 NSSecureCoding 不用 Codable** — 设计定位为接口缓存，NSSecureCoding 满足 OC 组件存储需求，Codable 非核心需求
- **缓存数据白名单必须包含 `NSNull`，且写入侧与解档侧共用同一份定义** — 后端 JSON 的 `null` 会以 `NSNull` 进入响应字典。白名单缺席 `NSNull` 时，写入侧完全正常，读取侧却会被 `NSKeyedUnarchiver` 判为非法类：默认策略（`.setErrorAndReturn`）下整个 `data` 静默变 `nil`，`.raiseException` 策略下抛 `NSInvalidUnarchiveOperationException`（OC 异常，Swift 的 `try?`/`do-catch` 捕获不到，直接终止进程）。因此白名单收敛为 `NtkCacheMeta.allowedDataClasses` 单一常量，`canEncode(_:)` 与 `init?(coder:)` 共用。
- **缓存写入前用 `canEncode(_:)` 递归校验，而非依赖归档成功** — 归档成功不等于能解回：`URL`、`Date`、自定义 Sendable 结构体都能编码，但不在解档白名单内，放任写入会留下「写成功、读不出」的脏缓存。校验必须递归，因为 `[String: Sendable]` 的元素可以是这类值。`save` 与 `NtkCacheInterceptor` 都会在调用 storage 前拦截，前者保证不落盘，后者用 warning 日志说明原因。
- **`data` 解不出来时整个 `NtkCacheMeta` 返回 `nil`，不构造 `data` 为 `nil` 的伪命中** — 用 `coder.containsValue(forKey: "data")` 区分「键不存在」（合法：写入侧只在 `data` 非 nil 时编码）与「键存在但解不出白名单类型」（脏缓存或损坏）。后者若退化成 `data=nil`，缓存会永久失效且没有任何错误信号，比解档失败更难排查。
- **容器内的 `Bool` 与 `Float` 往返后可能退化为 `NSNumber` 桥接形态** — 顶层 `Bool`/`Float` 能保持原类型，但字典或数组里的 `NSNumber` 无法区分 `Bool`、`Int`、`Double` 的原始 Swift 类型：实测数组 `[true, 1]` 读出为 `[Double(1.0), Double(1.0)]`，容器内 `Float` 读出为 `Double`（数值精度不变）。这是 `NSSecureCoding` 的固有行为，不视为缺陷；需要精确类型契约时应直接使用顶层标量或 `Data`。
- **`Error?` / `any Error` 持有非 Sendable 是可接受的 `@unchecked Sendable` 用法** — `Error` 协议不要求 `Sendable` 是 Swift 类型系统的已知限制；实际传入的 `URLError`/`AFError` 都是 Sendable 的，`@unchecked Sendable` 是标准做法，不应作为 review 问题提出（如 `NtkError.Client.ExternalContext`）
- **协议方法数量不作为 review 问题** — 适配层协议（如 `iAFRequest`）的方法数量由后端能力决定，不是代码质量问题
- **`NtkReturnCode` 两个 init 是刻意设计** — `init(_ value: Any?)` failable 用于 `JSONSerialization` 解析入口，`init(_ value: Sendable?)` non-failable 用于通用构造，语义不同不应合并
- **`NtkResponseDecoder` 中 `NtkCodingKeys(stringValue:)!` 是安全的** — 任何字符串都是合法 `CodingKey`，不可能返回 nil

## 代码评审记录

### 2026-04-04 全量评审

**范围**: Sources/ 全部 60 个 Swift 文件（CooNetwork 核心 + AlamofireClient 适配层）

**修复项:**

- **C1** `NtkDefaultResponseParsingPolicy` data-nil 分支先执行 validation 再决定成功或失败 — 业务失败响应缺失 `data` 是合法场景，应优先抛 `Validation.serviceRejected` 保留业务错误码；如果 validation 通过，说明服务端认为请求成功，此时 `data=null` 是合法响应（如删除、更新等操作），应返回 `NtkResponse<ResponseData?>` 而非抛错。`dataMissing` 错误已被移除，因为 "validation 通过但 data 缺失应抛错" 这一设计本身存在逻辑矛盾。
- **H1** 移除 `iNtkCacheStorage.setData` 冗余 `@available(iOS 13.0.0, *)` — Package.swift 已设置 `.iOS(.v13)`
- **H2** `LRUNode.prev` 改为 `weak` — 打破双向链表循环引用，新增 3 个测试覆盖

**确认无需修改:**

- **H3** `NtkNetwork.cancel()` TOCTOU — `cancelRequest` 读取的字段 init 后不可变，实际无竞争
- **H4** `requestWithCache()` 缓存失败 debug 日志 — `noCache` 已在 executor 层单独 catch，debug 只对真正的存储异常触发，级别合理
- **H5** `ExternalContext` 持有非 Sendable `Error?` — 见上方"其他"章节
- **M1** loading key 全局常量 — `Ntk` 前缀 + `internal` 修饰，无冲突风险
- **M2-M5** 见上方"其他"章节对应条目
