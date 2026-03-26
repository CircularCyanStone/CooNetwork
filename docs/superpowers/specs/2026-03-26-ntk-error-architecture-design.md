# NtkError 错误架构重设计

## 背景

当前 `NtkError` 已开始承载 richer context，例如 `decodeInvalid(DecodeInvalid)` 已能暴露 `underlyingError`、恢复出的结构化 response 和原始值。但整体错误体系仍存在几个结构性问题：

1. 顶层 case 粒度不一致：既有领域级错误，也有具体失败点，也有兜底错误。
2. 参数风格不一致：tuple 参数、struct 参数、单个 `Error`、无上下文 case 混用。
3. 复杂错误上下文没有形成统一规则：`DecodeInvalid` 是局部优化，还没推广为体系。
4. client 扩展虽然已有 `NtkError.AF`，但仍像旁路设计，未成为主架构正式组成部分。

由于该框架尚未大范围使用，本次设计不以兼容现有 API 为目标，优先追求长期扩展性、框架语义清晰度和调用方处理体验。

## 设计目标

1. 所有对外抛出的错误统一收敛为 `NtkError`。
2. 顶层错误分类少而稳定，命名直觉，接近 `AFError` 的使用体验。
3. 复杂错误统一采用 `reason + context` 建模，避免裸参数扩散。
4. 保留并强化 `NtkError.AF` 这类 client 扩展模式，使其成为正式架构机制。
5. 让调用方能够先按顶层领域处理，再按具体 reason 深入处理。

## 非目标

1. 不追求保留现有 `NtkError` case 命名与关联值结构。
2. 不引入协议化 type-erasure 错误系统，避免过度抽象。
3. 不把所有字段收敛为一个万能大 context，避免 optional 泛滥和语义退化。

## 推荐方案

采用“统一根错误 `NtkError` + 稳定顶层分类 + 各领域内 `reason + context` + client 子空间扩展”的双层错误架构。

### 顶层错误域

推荐最终固定为以下 5 类：

- `request`
- `response`
- `serialization`
- `validation`
- `client`

推荐骨架：

```swift
public enum NtkError: Error {
    case request(RequestFailure)
    case response(ResponseFailure)
    case serialization(SerializationFailure)
    case validation(ValidationFailure)
    case client(ClientFailure)
}
```

这 5 类的设计依据如下：

### 1. request

表示请求构建、请求前置条件、请求/返回契约不成立等问题。

适合承载：
- `typeMismatch`
- 未来如 `invalidRequest`、`unsupportedRequestType`

### 2. response

表示请求已执行，但响应本体层面无法继续处理。

适合承载：
- `responseBodyEmpty`
- `requestCancelled`
- `requestTimeout`
- client 返回的无效响应对象等

### 3. serialization

表示响应数据无法被解释为框架期望的结构化内容，是最核心的复杂错误域。

适合承载：
- `jsonInvalid`
- `decodeInvalid`
- `serviceDataEmpty`
- `serviceDataTypeInvalid`

### 4. validation

表示响应结构合法，但业务语义判定失败。

适合承载：
- 当前 `validation(_ request: iNtkRequest, _ response: any iNtkResponse)`

### 5. client

表示具体 client 的扩展错误空间。

适合承载：
- `NtkError.AF`
- 未来其他 client 子空间

## 术语表

- `request`：触发当前错误的请求对象，通常是 `iNtkRequest` 或其子协议实例。
- `clientResponse`：底层 client 返回的原始响应对象，例如 `NtkClientResponse`，承载 status、headers、data、cache 等底层信息。
- `recoveredResponse`：在 serialization 链路中从 payload 恢复出的结构化 envelope，例如 `NtkResponse<NtkDynamicData?>`，并不代表最终 typed response。
- `typedResponse`：最终面向调用方的 `NtkResponse<ResponseData>`。
- `rawPayload`：尚未成功解释为目标结构的原始 payload 或中间 payload 值。
- `underlyingError`：触发当前错误的底层错误，例如 `DecodingError`、`AFError`、`URLError`。

## 参数管理策略

本次重设计的核心不在于增加或删减 case，而在于统一参数语义与承载方式。

### 核心原则

1. 顶层 `NtkError` case 不再直接挂多个裸参数。
2. 复杂错误统一采用 `reason + context`。
3. `underlyingError` 是复杂错误的标准字段。
4. `response` 必须拆成明确语义命名，不再用宽泛总称。
5. 顶层不保留 `other(Error)` 这类垃圾桶 case。

### 推荐模式

```swift
public struct SerializationFailure: Error {
    public let reason: Reason
    public let context: Context
}
```

而不是：

```swift
case decodeInvalid(_ request: iNtkRequest, _ response: any iNtkResponse, _ error: Error)
```

### 通用诊断骨架

复杂错误共享最小诊断骨架思路：

- `request`
- `clientResponse`
- `underlyingError`

这三项是最稳定、跨领域最常见的诊断信息。

### 领域增量上下文

不使用“一个超大万能 context”，而是在共享骨架上按领域补充字段。

#### SerializationFailure.Context

额外建议字段：
- `recoveredResponse`
- `rawPayload`
- `stage`

说明：
- `recoveredResponse` 表示已从 payload 中恢复出的结构化 envelope，例如 `NtkResponse<NtkDynamicData?>`
- `rawPayload` 表示原始 payload / source value
- `stage` 表示失败发生在 JSON、envelope、data、model 哪一段

#### ValidationFailure.Context

额外建议字段：
- `response`

说明：
validation 阶段最重要的是已完成结构化的业务响应，不需要引入 `rawPayload` 或 `recoveredResponse` 等 serialization 专属语义。

#### ResponseFailure.Context

通常只需：
- `request`
- `clientResponse`
- `underlyingError`

#### AF.Context

推荐也遵守同样规则：
- `request`
- `clientResponse`
- `underlyingError`

## 命名调整建议

### `DecodeInvalid.response`

当前 `DecodeInvalid.response` 实际语义是：
- 解析链路中恢复出来的 envelope
- 不是底层 client response
- 也不是最终 typed response

因此不应继续命名为宽泛的 `response`，建议改为：
- `recoveredResponse`

### `rawValue`

当前 `rawValue` 语义偏宽，建议改名为：
- `rawPayload`

如果未来该字段不一定是 payload，也可考虑 `sourceValue`，但对当前解析链路来说 `rawPayload` 更直观。

## 现有错误迁移建议

| 现有 case | 建议去向 | 说明 |
|---|---|---|
| `validation(request, response)` | `validation(.serviceRejected(...))` | 保留语义，参数对象化 |
| `jsonInvalid(request, response)` | `serialization(.invalidJSON(...))` | 并入 serialization 域 |
| `decodeInvalid(DecodeInvalid)` | `serialization(...)` | 升级为 reason + context |
| `responseBodyEmpty(request, response)` | `response(.bodyEmpty(...))` | 并入 response 域 |
| `serviceDataEmpty` | `serialization(.dataMissing(...))` | 属于内容解释失败 |
| `serviceDataTypeInvalid` | `serialization(.dataTypeMismatch(...))` | 属于内容解释失败 |
| `typeMismatch` | `request(.typeMismatch(...))` | 请求/契约层问题 |
| `requestCancelled` | `response(.cancelled(...))` | 请求执行失败 |
| `requestTimeout` | `response(.timedOut(...))` | 请求执行失败 |
| `other(error)` | 删除 | 不再保留顶层垃圾桶 |

## 各错误域的建议 reason

### RequestFailure.Reason

- `typeMismatch`
- `invalidRequest`
- `unsupportedRequestType`

### ResponseFailure.Reason

- `bodyEmpty`
- `invalidResponseType`
- `cancelled`
- `timedOut`
- `transportError`

### SerializationFailure.Reason

- `invalidJSON`
- `envelopeDecodeFailed`
- `dataDecodeFailed`
- `dataMissing`
- `dataTypeMismatch`

### ValidationFailure.Reason

- `serviceRejected`

## `NtkError.AF` 的最终定位

`NtkError.AF` 设计应保留，但本次设计同时明确它的扩展边界：当前目标是支持**框架官方内建的有限 client 子空间**，而不是对任意外部模块开放可无限追加的 client case。

这意味着：

- `client` 域是 `NtkError` 的正式扩展位
- `AF` 是当前已知、正式支持的 client 子空间
- 未来若框架内建新的 client，可在核心层继续扩充 `ClientFailure`
- 本次不设计开放式注册、type-erasure 或任意外部模块动态扩展 client 错误空间的机制

推荐结构方向：

```swift
public enum ClientFailure: Error {
    case af(AF)
}
```

`AF` 本身继续作为 `NtkError` 的内嵌类型，由 AlamofireClient 维护其具体 reason 和 context。这样可以保证：

1. 主框架对外仍统一抛出 `NtkError`
2. 主框架不被 Alamofire 具体错误细节污染
3. AlamofireClient 保持独立错误语义空间
4. 对于官方内建 client，扩展模式稳定且可复制

`NtkError.AF` 内部也应遵守 `reason + context` 原则，不再使用多个裸参数并排的形式。

## 错误归一化边界

由于最终对外 public surface 统一抛出 `NtkError`，因此必须明确“任意底层 Error 何时、由谁、如何收敛”。本次设计约束如下：

### 归一化原则

1. 进入公开网络主链的错误，在离开框架前必须被收敛为 `NtkError`。
2. 顶层不保留 `other(Error)`；未知错误只能落入所属领域内部的 `unknown` / `custom` / `transportError` 等 reason。
3. 不允许公共 API 将裸 `Error` 直接抛给调用方。

### 推荐归一化规则

- `URLError`、底层连接失败、传输中断等进入 `response(.transportError(...))` 或 `response(.timedOut(...))` / `response(.cancelled(...))`
- 无法解释 payload 的错误进入 `serialization(...)`
- 业务成功判定失败进入 `validation(...)`
- request 构建或 request/response 契约不成立进入 `request(...)` 或 `response(...)`
- 已知 client 特定错误进入 `client(...)`
- 其他无法进一步精确分类、但领域已知的错误，进入该领域内部 `unknown` / `custom`

### 当前重点约束

- retry、executor、response parser、client adapter 等公共边界都需要做 `Error -> NtkError` 收敛
- 领域内部可以保留 `underlyingError`，但最终顶层必须是 `NtkError`

## 复杂错误与轻量错误的判定规则

用户已确认“复杂错误统一上下文，简单错误保持轻量”。为避免后续实现再次分裂，明确以下门槛：

### 使用 `reason + context` 的情况

当错误至少满足以下任一条件时，必须使用 `reason + context`：

1. 调用方需要稳定读取诊断信息（request、clientResponse、recoveredResponse、underlyingError、rawPayload 等）
2. 同一领域下存在多个失败原因，且未来可能继续扩展
3. 错误会被日志、埋点、重试、toast、debug UI 等跨层消费

### 使用轻量 reason 的情况

当错误只表达一个稳定、无需额外诊断信息的语义时，可保持轻量：

- `request.typeMismatch`
- `response.cancelled`
- `response.timedOut`
- `serialization.dataMissing`
- `validation.serviceRejected`（若调用方不需要进一步消费上下文，则可轻；若需要读取 response，则仍应是 reason + context）

### 当前实现建议

- `serialization` 默认视为复杂错误域，应统一 `reason + context`
- `validation` 默认使用 `reason + context`
- `response` 允许轻量与富上下文并存，但 transport 相关 reason 至少应可保留 `underlyingError`
- `request` 域大多数 reason 可保持轻量，只有涉及 request 构建失败细节时再引入 context

## request / response 分类矩阵

当前代码中 `typeMismatch` 与“响应类型不符”并不止一种来源，因此需要显式矩阵，避免实现时归类漂移。

| 失败场景 | 当前位置 | 建议归类 | 建议 reason |
|---|---|---|---|
| 解析器期望 `NtkClientResponse`，却拿到其他 `iNtkResponse` | `NtkDataParsingInterceptor.acquire` | `response` | `invalidResponseType` |
| acquire 之后缺失 `request` 或 `clientResponse`，无法继续 prepare | `NtkDataParsingInterceptor.prepare` | `request` | `typeMismatch` |
| payload 顶层结构不满足 normalize 要求 | `NtkPayload.normalize` 路径 | `serialization` | `invalidJSON` / `envelopeDecodeFailed`，视失败点而定 |
| 执行器最终无法 cast 成期望的 typed response | executor 最终交付路径 | `request` | `typeMismatch` |
| client 返回对象形态不满足框架主链契约 | client adapter / parser 入口 | `response` | `invalidResponseType` |

这张矩阵的原则是：

- **请求/结果契约不成立** → `request`
- **底层响应对象形态不合法** → `response`
- **payload / envelope / model 解释失败** → `serialization`

## 判定优先级

当前解析链路里，validation 与 serialization 并不是完全独立的；spec 必须保留现有有效行为，避免重构时回归。

### 优先级规则

1. 若 decode 失败但成功恢复出 header / envelope，则先执行 validation。
2. 若 validation 失败，则优先抛出 `validation`，不再继续向调用方暴露该次 `serialization` 失败。
3. 只有 validation 通过后，才抛出对应的 `serialization` 错误。
4. 在 decoded 成功但 `data == nil` 的路径上，同样先 validation；validation 通过后，才抛 `serialization(.dataMissing)`。
5. 空 body、底层 response 不合法、请求被取消、请求超时等不进入 validation，直接落入 `response`。

### 当前代码对应关系

该优先级直接对应当前 `NtkDefaultResponseParsingPolicy.decide` 的行为，应在重构后保持一致。

## 重试语义映射

当前 `iNtkRetryPolicy` 已依赖旧错误分类，本次重构必须同步定义新错误架构下的默认重试语义。

### 默认策略

- `request.*`：默认不重试
- `validation.*`：默认不重试
- `serialization.*`：默认不重试
- `response.cancelled`：不重试
- `response.timedOut`：可重试
- `response.transportError`：是否重试取决于其 `underlyingError`，若是 `URLError`，沿用当前 `URLError` 映射规则
- `response.invalidResponseType` / `response.bodyEmpty`：默认不重试
- `client.*`：默认不重试，除非该 client 子空间自行定义其 reason 可重试并由 retry 层显式适配

### `URLError` 映射

继续沿用当前 retry 语义：

- `.timedOut`、`.cannotConnectToHost`、`.networkConnectionLost`、`.notConnectedToInternet`、`.dnsLookupFailed` → 可重试
- `.badURL`、`.unsupportedURL`、`.cannotParseResponse`、`.badServerResponse`、`.userCancelledAuthentication`、`.userAuthenticationRequired` → 不重试
- `.cannotLoadFromNetwork`、`.resourceUnavailable` → 可重试
- 其他情况默认不重试

## Objective-C 桥接迁移策略

当前 `NtkError+OC.swift` 提供固定错误码和桥接工厂。本次设计不以兼容现有 Swift API 为目标，但必须明确 OC bridge 的处理方式。

### 设计结论

1. Objective-C bridge **保留**，但视为适配层，不反向约束 Swift 错误架构。
2. Swift 层先完成新 `NtkError` 架构，OC bridge 再做映射调整。
3. 现有错误码不要求一一保留原 case 名，但需要提供稳定映射，避免 Objective-C 使用方无法识别基础错误类别。

### 推荐映射策略

- `request` / `response` / `serialization` / `validation` / `client` 建立新的错误码段
- 若短期需要平滑迁移，可临时保留旧码并将其映射到新领域
- bridge 产生的 `userInfo` 应使用新术语：`request`、`clientResponse`、`recoveredResponse`、`underlyingError`、`rawPayload`

## Sendable 与并发约束

当前 `DecodeInvalid` 已采用 `@unchecked Sendable`。新架构会把 `request`、`clientResponse`、`underlyingError` 等信息进一步系统化，因此必须把并发约束提前写入设计。

### 设计约束

1. 顶层 `NtkError` 及其公开 Failure / Context 类型应尽可能满足 `Sendable`。
2. 若某些 context 字段天然无法静态满足 `Sendable`，应优先缩小暴露面，再评估是否使用 `@unchecked Sendable`。
3. `underlyingError` 是最可能破坏 `Sendable` 的字段，需明确其承载策略；必要时可在 context 层使用 `@unchecked Sendable`，但必须有文档说明原因。
4. 不应为了强行获得 `Sendable` 而丢失必要诊断信息；在安全性与可诊断性冲突时，优先显式记录原因并最小化 `@unchecked` 范围。

## 为什么不推荐顶层 `other(Error)`

顶层 `other(Error)` 会迅速退化成垃圾桶，破坏分类体系，也会让后续新增错误懒于建模。

更优做法是：
- 能落到 `request` / `response` / `serialization` / `validation` 的，必须进入对应领域
- 确实需要未知兜底时，也应在领域内部定义 `unknown` / `custom`
- client 域允许保留更开放的未知分支，但核心框架域应尽量完整建模

## 推荐文件组织

为避免 `NtkError.swift` 继续膨胀，建议按领域拆分：

- `NtkError.swift` —— 只放顶层 enum
- `NtkError+Request.swift`
- `NtkError+Response.swift`
- `NtkError+Serialization.swift`
- `NtkError+Validation.swift`
- `NtkError+Client.swift`

AlamofireClient 继续维护：
- `Sources/AlamofireClient/Error/AFClientError.swift`

### Cache 错误边界

当前 `NtkError.Cache.noCache` 属于缓存子系统的控制流错误，不属于本次“网络请求主链错误架构”重设计范围。本设计固定的 5 个顶层错误域，仅覆盖请求执行、响应处理、解析、校验和 client 扩展，不覆盖 cache 内部错误空间。

## 与当前实现相比的收益

1. 顶层错误域稳定，不再随着细节演进持续膨胀。
2. 参数风格统一，复杂错误都能用一致模式读取。
3. `DecodeInvalid` 的 rich context 能升级为全局架构原则，而不是局部特例。
4. `NtkError.AF` 从附属设计升级为正式扩展机制。
5. 调用方可先按顶层领域处理，再深入到 reason，使用体验更接近 `AFError`。

## 风险与注意事项

1. 避免为了“统一”做出一个包含大量 optional 字段的万能 context。
2. 避免继续保留顶层 `other`，否则新体系会被快速侵蚀。
3. 避免继续使用宽泛的 `response` 命名，必须明确区分 `clientResponse` / `recoveredResponse` / `response`。
4. `serviceDataEmpty` 和 `serviceDataTypeInvalid` 应坚持归入 serialization，而不是 validation。
5. `NtkError.AF` 也必须采用新参数规则，不能在 client 子空间里继续沿用旧式裸参数。

## 建议的后续实现方向

1. 先在 `NtkError` 层重建顶层分类与各领域 Failure 类型。
2. 优先重构 `decodeInvalid` 所在路径，将其改造成 `serialization` 域完整实现。
3. 再调整 `validation` 与 `response` 相关错误抛出点。
4. 最后重构 `AFClientError.swift`，让 `NtkError.AF` 接入新的 `client` 域。
5. 配套补齐针对 reason/context 的测试，确保每个错误域都能稳定暴露应有诊断信息。
