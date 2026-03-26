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

`NtkError.AF` 设计应保留，并从“特例”升级为“正式 client 扩展机制”。

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
4. 未来新 client 可以直接复制该模式

`NtkError.AF` 内部也应遵守 `reason + context` 原则，不再使用多个裸参数并排的形式。

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
