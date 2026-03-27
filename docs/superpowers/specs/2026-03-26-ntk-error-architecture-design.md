# NtkError 错误架构重设计（AFError 风格收口版）

## 背景

当前已落地的 `NtkError` 重构方案存在方向性问题，不是实现细节偏差，而是 public API 建模轴线错误：

1. 顶层按 `request / response / serialization / validation / client` 五域切分，暴露的是框架内部处理阶段，而不是调用方真正关心的公共失败事件。
2. `RequestFailure / ResponseFailure / SerializationFailure / ValidationFailure / ClientFailure` 统一采用 `reason + context` 套壳，导致简单错误也被过度对象化。
3. 抛错体验退化为 `NtkError.request(.init(reason: .typeMismatch))` 一类层级深、样板重、可读性差的写法。
4. `typeMismatch` 混杂了多种本质不同的失败场景，已经失去 public API 价值。
5. 当前方案并未真正对齐 Alamofire `AFError` 的设计思想；它只借用了“顶层 + 子类型”的表面形式，没有采用“公共失败事件 + 独立失败原因类型”的建模方式。

本次重设计没有兼容旧 API 的压力，目标是直接按最优 public API 方案重构。

---

## 设计目标

1. 所有对外错误统一由 `NtkError` 作为公共入口暴露。
2. `NtkError` 顶层只表达**公共失败事件**，不表达内部流水线阶段。
3. 简单、稳定、高频的失败直接使用顶层 case。
4. 复杂错误通过独立 `enum XXError: Error` 收敛，而不是统一 `Failure(reason: context:)` 套壳。
5. 调用方既可以 `switch NtkError`，也可以直接基于独立错误类型做更细分处理。
6. 设计风格尽可能向 Alamofire `AFError` 靠拢。
7. 不为了兼容旧命名和旧结构而保留任何中间态设计。

---

## 非目标

1. 不保留现有五域顶层结构。
2. 不保留 `Failure(reason: context:)` 统一模式。
3. 不保留 `typeMismatch` 这类模糊公共语义。
4. 不以内部实现分层（request / response / serialization / validation）作为 public API 的分类依据。
5. 不设计开放式 client plugin 错误注册系统；当前只服务于框架官方维护的 client 子空间。

---

## 与现有设计决策记录的关系

本 spec 会**替换** `docs/design-decisions.md` 中这条既有结论：

- `NtkError.AF 嵌套枚举` — Swift enum 无法在 extension 中加 case，嵌套枚举让每个 client 有独立错误空间，是多来源错误的标准模式

替换原因不是“AF 子空间不该存在”，而是原决策把 client 子空间错误地绑定到了旧的五域顶层结构上。新设计保留官方 client 子空间，但改成：

```swift
NtkError.clientFailed(reason: .af(...))
```

也就是：

- 保留 AF 作为官方维护的 client 子空间
- 放弃 `NtkError.client(...)` / `ClientFailure` 这套旧的顶层领域壳
- 让顶层 API 回到“公共失败事件”语义

---

## 核心设计

### 1. 顶层 `NtkError` 改为“公共失败事件入口”

推荐骨架：

```swift
public enum NtkError: Error, Sendable {
    case invalidRequest
    case unsupportedRequestType
    case invalidResponseType
    case invalidTypedResponse
    case responseBodyEmpty
    case requestCancelled
    case requestTimeout

    case responseValidationFailed(reason: NtkResponseValidationError)
    case responseSerializationFailed(reason: NtkResponseSerializationError)
    case clientFailed(reason: NtkClientError)

    enum Cache: Error, Sendable {
        case noCache
    }
}
```

### 设计原则

- 顶层 case 名必须是**对外失败事件**，而不是内部处理阶段。
- 顶层只保留无需进一步对象化即可理解的稳定语义。
- 复杂错误下沉到独立错误类型，而不是在顶层保留一个“领域桶”再二次 reason/context 拆解。

### 为什么不是五域顶层

以下写法是本次明确放弃的旧方向：

```swift
public enum NtkError: Error {
    case request(RequestFailure)
    case response(ResponseFailure)
    case serialization(SerializationFailure)
    case validation(ValidationFailure)
    case client(ClientFailure)
}
```

原因：

- `request / response / serialization / validation / client` 是框架内部分类，不是最佳 public API。
- 调用方首先接触到的是失败事件，而不是框架流水线分层。
- 该模型天然鼓励“所有错误都先分桶，再造壳”，最终导致 API 膨胀和使用体验恶化。

---

## 独立错误类型设计

### 2. `NtkResponseSerializationError`

这是最核心的复杂错误类型，承载解析、解码、数据解释过程中的失败。

推荐定义：

```swift
public enum NtkResponseSerializationError: Error, Sendable {
    case invalidJSON(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?
    )

    case invalidEnvelope(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?
    )

    case invalidDataPayload(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?
    )

    case dataDecodingFailed(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?,
        rawPayload: NtkPayload?,
        underlyingError: Error?
    )

    case dataMissing(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?
    )

    case dataTypeMismatch(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?,
        underlyingError: Error?
    )
}
```

### 设计要点

- 不再保留 `SerializationFailure(reason: context:)`。
- 不再保留 `stage` 作为核心 public API 字段；失败点直接通过 case 名表达。
- `recoveredResponse` 只在真正需要时出现，不做所有错误共享的大 context。
- 仅 `dataDecodingFailed` 保留 `rawPayload`，且类型为 `NtkPayload?`，表示真正进入 decoder 的失败输入。
- `invalidJSON` / `invalidEnvelope` 不再携带 `rawPayload`；这两类错误要么发生在 `NtkPayload` 尚未形成之前，要么 payload 本身不具备独立保留价值。
- **严格区分“输入形态不合法”和“真正发生解码失败”**：
  - `invalidEnvelope` / `invalidDataPayload` 表示前置输入根本不满足 decoder 期望
  - `dataDecodingFailed` 表示 decoder 真正抛错

这条区分是本次重构必须锁死的规则，不能再把旧 `typeMismatch` 换皮后重新混入 decode failure。

---

### 3. `NtkResponseValidationError`

业务层校验失败使用独立错误类型承载。

推荐定义：

```swift
public enum NtkResponseValidationError: Error, Sendable {
    case serviceRejected(
        request: iNtkRequest,
        response: any iNtkResponse
    )
}
```

### 术语约束

- validation 阶段的 `response` 指的是**已恢复出的业务响应对象**，也就是已经可以参与业务校验的 `any iNtkResponse`。
- 这个 `response` 不等于底层 `clientResponse`。
- 这个 `response` 在 decode failure 路径里，代表“从 payload 恢复出的可校验业务响应”，不是最终 typed response。

为避免混淆：

- `clientResponse`：底层客户端响应
- `recoveredResponse`：serialization 路径中的恢复性 envelope
- `response`：validation 阶段真正用于业务判断的业务响应

---

### 4. `NtkClientError`

官方维护的 client 子空间使用独立错误类型承载。

推荐定义：

```swift
public enum NtkClientError: Error, Sendable {
    case af(
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        underlyingError: Error?,
        message: String?
    )
}
```

### 设计要点

- 保留 AF 作为官方内建 client 子空间，但不再把它建模成五域之一。
- 顶层对外暴露为：

```swift
NtkError.clientFailed(reason: .af(...))
```

而不是：

```swift
NtkError.client(.af(...))
```

- `AFClientError.swift` 只负责 AF 到 `NtkClientError.af(...)` 的映射，不拥有公共错误模型定义权。

### 关于“贴近 AFError”的精确定义

本 spec 中“贴近 AFError”的含义是：

1. 顶层使用公共失败事件命名
2. 复杂错误下沉到独立错误类型
3. 放弃内部五域顶层分类

它**不意味着** `NtkClientError` 必须完整镜像 `AFError` 的全部子分类。

对 `NtkClientError` 的当前定位是：

- 它是**官方 client 子空间透传错误**
- 它不是通用网络错误 taxonomy
- 它当前不追求把 AF 内部错误再做一轮完整公共建模

因此 `NtkClientError.af(...)` 是刻意保留的 opaque client passthrough，而不是“设计未完成的中间态”。

---

## 必删旧结构

以下类型和文件代表的是已确认错误的抽象方向，应整体删除：

- `RequestFailure`
- `ResponseFailure`
- `SerializationFailure`
- `ValidationFailure`
- `ClientFailure`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Request.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Response.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Serialization.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Validation.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Client.swift`

本次不是对这些结构做修补，而是彻底替换掉。

---

## 顶层事件判定表

以下矩阵用于钉死最容易漂移的顶层 case 边界。

| 发生点 | 失败本质 | 对外语义 | 禁止替代项 |
|---|---|---|---|
| 主链前置条件缺失，导致当前阶段无法继续 | 请求构建前置条件或 prepare 阶段必需上下文不成立 | `.invalidRequest` | 不得落到 `.invalidResponseType` / `.invalidTypedResponse` |
| 请求对象不是当前 client 支持的请求类型 | 请求类型不受支持 | `.unsupportedRequestType` | 不得落到 `.invalidRequest` |
| parsing 入口收到的底层响应对象不是 `NtkClientResponse` | 底层响应对象形态非法 | `.invalidResponseType` | 不得落到 `.invalidTypedResponse` / `.invalidRequest` |
| executor / task manager 最终交付给调用方时，typed response cast 失败 | 框架最终产物与调用方期望的 typed response 不匹配 | `.invalidTypedResponse` | 不得落到 `.invalidResponseType` / `.invalidRequest` |
| 响应体为空，无法进入正常解析 | 响应内容缺失 | `.responseBodyEmpty` | 不得落到 serialization error |
| 任务被取消 | 请求执行被取消 | `.requestCancelled` | 不得落到 `.clientFailed` |
| 请求超时 | 请求执行超时 | `.requestTimeout` | 不得落到 `.clientFailed` |

额外规则：

- `invalidRequest`：只用于两类场景：1）请求构建前置条件缺失；2）parsing prepare 阶段缺 `request` / `clientResponse` 等主链必需上下文。
- `invalidResponseType`：只用于 parsing 入口的底层 response 对象形态不合法。
- `invalidTypedResponse`：只用于 executor / task manager 最终 typed response 交付失败。
- 若失败发生在底层 response 对象形态判定，必须落到 `invalidResponseType`；若失败发生在最终 typed response 交付，必须落到 `invalidTypedResponse`；不得以“上下文不成立”为由回退到 `invalidRequest`。

---

## 错误映射矩阵

### 5. 顶层简单错误

| 当前已落地语义 | 新方案 | 说明 |
|---|---|---|
| `invalidRequest` | `.invalidRequest` | 直接顶层化 |
| `unsupportedRequestType` | `.unsupportedRequestType` | 直接顶层化 |
| `invalidResponseType` | `.invalidResponseType` | 底层响应对象形态错误 |
| `responseBodyEmpty` | `.responseBodyEmpty` | 高频稳定失败事件 |
| `cancelled` | `.requestCancelled` | 保持公共失败事件命名 |
| `timedOut` | `.requestTimeout` | 保持公共失败事件命名 |

### 6. `typeMismatch` 的彻底拆解

`typeMismatch` 过于模糊，必须从 public API 中彻底移除。

| 旧场景 | 当前位置 | 新方案 |
|---|---|---|
| parser 入口拿到的 response 不是 `NtkClientResponse` | `NtkDataParsingInterceptor.acquire` | `.invalidResponseType` |
| prepare 阶段缺 request / clientResponse | `NtkDataParsingInterceptor.prepare` | `.invalidRequest` |
| executor 最终 typed response cast 失败 | `NtkNetworkExecutor` | `.invalidTypedResponse` |
| task manager owner/follower typed cast 失败 | `NtkTaskManager` | `.invalidTypedResponse` |
| payload decoder 输入形态不匹配 | `NtkPayloadDecoders` | `.responseSerializationFailed(reason: ...)` |

结论：`typeMismatch` 这个名字应完全消失。

---

### 7. 解析路径映射

#### `NtkPayload.normalize`

顶层 payload 不合法：

```swift
NtkError.responseSerializationFailed(reason: .invalidJSON(...))
```

#### `NtkJSONObjectPayloadDecoder`

输入不是 `.dynamic`：

```swift
NtkError.responseSerializationFailed(reason: .invalidEnvelope(...))
```

输入形态成立，但 decoder 真抛错：

```swift
NtkError.responseSerializationFailed(reason: .dataDecodingFailed(...))
```

#### `NtkDataPayloadDecoder`

输入不是 `.data`：

```swift
NtkError.responseSerializationFailed(reason: .invalidDataPayload(...))
```

输入形态成立，但 decoder 真抛错：

```swift
NtkError.responseSerializationFailed(reason: .dataDecodingFailed(...))
```

#### `NtkDynamicData`

- 纯类型转换不成立 → `.responseSerializationFailed(reason: .dataTypeMismatch(...))`
- decoder 真正抛错 → `.responseSerializationFailed(reason: .dataDecodingFailed(...))`

---

### 8. parsing policy 优先级

本节不再使用 `header` 术语，统一沿用 `recoveredResponse / response`。除流程名外，不再使用 `parsing error` 作为对外错误术语。

必须保留当前真正正确的判定优先级，但换成新的 public error shape。

#### 空 body

```swift
throw NtkError.responseBodyEmpty
```

#### decode failure + recoveredResponse 可形成可校验业务 response + validation fail

```swift
throw NtkError.responseValidationFailed(reason: .serviceRejected(...))
```

#### decode failure + recoveredResponse 可形成可校验业务 response + validation pass

```swift
throw NtkError.responseSerializationFailed(reason: .dataDecodingFailed(...))
```

#### decode failure + 无可用于校验的 recoveredResponse

```swift
throw NtkError.responseSerializationFailed(reason: .dataDecodingFailed(...))
```

#### decoded 成功但 `data == nil`

validation 通过后：

```swift
throw NtkError.responseSerializationFailed(reason: .dataMissing(...))
```

### 固定原则

1. validation 优先级高于 serialization。
2. 空 body 不进入 validation。
3. 无可用于校验的 `recoveredResponse` 时，decode failure 直接视为 serialization failure。
4. `data == nil` 不是 validation failure，而是 serialization failure。

---

### 9. validation 映射

业务校验失败统一映射为：

```swift
NtkError.responseValidationFailed(reason: .serviceRejected(...))
```

不再保留：

```swift
ValidationFailure(reason: .serviceRejected, context: ...)
```

---

### 10. AF / client 映射

#### AF 请求取消

```swift
NtkError.requestCancelled
```

#### AF timeout

```swift
NtkError.requestTimeout
```

#### 其他 AFError / AF 侧底层错误

```swift
NtkError.clientFailed(reason: .af(...))
```

### 关键决策

本次不保留 `transportError` 作为公共顶层概念。

原因：

1. `timeout` 与 `cancelled` 已被提炼为更有公共价值的失败事件。
2. 其余客户端/底层网络失败，统一经 `clientFailed(reason: .af(...))` 收口，更贴近 `AFError` 风格。
3. `transportError` 本质仍是内部技术分类，不是最佳 public API 事件命名。

### AF 映射优先级硬约束

AF / client 映射时，`cancelled` 与 `timedOut` 必须先于 `clientFailed` 归一化：

- 一旦命中取消，必须映射为 `.requestCancelled`
- 一旦命中超时，必须映射为 `.requestTimeout`
- 只有未命中上述两类时，AF 错误才允许落到 `.clientFailed(reason: .af(...))`

因此即便 `underlyingError` 最终表现为 `URLError.cancelled` 或 `URLError.timedOut`，也不得继续透传为 `.clientFailed(reason: .af(...))`。

---

## 重试语义

### 默认矩阵

| 错误 | 是否重试 |
|---|---|
| `.invalidRequest` | 否 |
| `.unsupportedRequestType` | 否 |
| `.invalidResponseType` | 否 |
| `.invalidTypedResponse` | 否 |
| `.responseBodyEmpty` | 否 |
| `.requestCancelled` | 否 |
| `.requestTimeout` | 是 |
| `.responseValidationFailed(...)` | 否 |
| `.responseSerializationFailed(...)` | 否 |
| `.clientFailed(reason: .af(...))` | 默认否；若 underlying `URLError` 命中可重试集合，则重试 |

### `URLError` 细分规则

沿用当前有效矩阵：

可重试：
- `.timedOut`
- `.cannotConnectToHost`
- `.networkConnectionLost`
- `.notConnectedToInternet`
- `.dnsLookupFailed`
- `.cannotLoadFromNetwork`
- `.resourceUnavailable`

不可重试：
- `.badURL`
- `.unsupportedURL`
- `.cannotParseResponse`
- `.badServerResponse`
- `.userCancelledAuthentication`
- `.userAuthenticationRequired`

---

## Objective-C Bridge

### 设计原则

1. Objective-C bridge 保留，但仅作为适配层。
2. bridge 不反向塑造 Swift public API。
3. 旧术语和旧错误码兼容不是本次主目标；优先反映新的错误模型。
4. NSError code 段分组仅用于 bridge 与历史消费端识别，不代表 Swift 层继续采用 request/response 五域式 taxonomy。

### 建议 code 段

| 新错误 | NSError code 段 |
|---|---|
| `invalidRequest` / `unsupportedRequestType` | 100xx |
| `invalidResponseType` / `invalidTypedResponse` / `responseBodyEmpty` / `requestCancelled` / `requestTimeout` | 101xx |
| `responseSerializationFailed(...)` | 102xx |
| `responseValidationFailed(...)` | 103xx |
| `clientFailed(...)` | 104xx |

### `userInfo` key

统一使用：

- `request`
- `clientResponse`
- `recoveredResponse`
- `response`
- `underlyingError`
- `rawPayload`
- `message`

其中：

- `response` 只用于 validation 阶段的业务响应
- `recoveredResponse` 只用于 serialization 阶段的恢复性 envelope

---

## 文件组织

推荐新的错误文件结构：

- `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+OC.swift`

说明：

- `NtkError.swift` 只保留顶层公共错误入口。
- 独立错误类型分别放入单独文件。
- 不再使用 `NtkError+Request.swift` 这一类“Failure 壳子文件”。

---

## 逐模块迁移策略

### `NtkPayload.swift`

- payload 入口不合法 → `.responseSerializationFailed(reason: .invalidJSON(...))`

### `NtkPayloadDecoders.swift`

- object decoder 输入不合法 → `.responseSerializationFailed(reason: .invalidEnvelope(...))`
- data decoder 输入不合法 → `.responseSerializationFailed(reason: .invalidDataPayload(...))`
- decoder 真抛错 → `.responseSerializationFailed(reason: .dataDecodingFailed(...))`

### `NtkDynamicData.swift`

- 纯类型不匹配 → `.responseSerializationFailed(reason: .dataTypeMismatch(...))`
- decoder 抛错 → `.responseSerializationFailed(reason: .dataDecodingFailed(...))`

### `NtkDataParsingInterceptor.swift`

- acquire 拿到非法 response → `.invalidResponseType`
- prepare 缺主链上下文 → `.invalidRequest`

### `NtkDefaultResponseParsingPolicy.swift`

- 空 body → `.responseBodyEmpty`
- validation fail → `.responseValidationFailed(reason: .serviceRejected(...))`
- decode fail → `.responseSerializationFailed(reason: .dataDecodingFailed(...))`
- decoded but nil data → `.responseSerializationFailed(reason: .dataMissing(...))`

### `NtkNetworkExecutor.swift`

- 最终 typed response cast fail → `.invalidTypedResponse`

### `NtkTaskManager.swift`

- cancelled → `.requestCancelled`
- timed out → `.requestTimeout`
- owner/follower cast fail → `.invalidTypedResponse`

### `iNtkRetryPolicy.swift`

- 改为消费新顶层错误模型与 `NtkClientError.af` 的 underlying `URLError`

### `AFClient.swift`

- cancelled → `.requestCancelled`
- timeout → `.requestTimeout`
- 其他 AF 失败 → `.clientFailed(reason: .af(...))`

### `AFToastInterceptor.swift`

- `responseValidationFailed(.serviceRejected(...))` → 继续读取业务 msg
- `requestTimeout` → “连接超时~”
- `clientFailed(.af(...))` → 优先展示 message，否则 fallback `localizedDescription`

---

## 测试策略

测试应围绕“公共失败事件 + 独立错误类型”编写，而不是围绕旧五域。

### 顶层错误测试

- `invalidRequest`
- `unsupportedRequestType`
- `invalidResponseType`
- `invalidTypedResponse`
- `responseBodyEmpty`
- `requestCancelled`
- `requestTimeout`

### serialization 测试

- `.invalidJSON`
- `.invalidEnvelope`
- `.invalidDataPayload`
- `.dataDecodingFailed`
- `.dataMissing`
- `.dataTypeMismatch`

### validation 测试

- `.serviceRejected`

### AF 映射测试

- AF timeout → `.requestTimeout`
- AF cancel → `.requestCancelled`
- AF generic error → `.clientFailed(reason: .af(...))`

### retry 测试

- `requestTimeout` 可重试
- `requestCancelled` 不重试
- `invalidTypedResponse` 不重试
- `responseSerializationFailed` 不重试
- `clientFailed(.af(...))` 按 underlying `URLError` 判断

---

## Sendable 约束

### 原则

1. 顶层 `NtkError` 及独立错误类型尽可能满足 `Sendable`。
2. 若 `underlyingError` 或协议 existential 导致静态 `Sendable` 难以成立，应把 `@unchecked Sendable` 收敛在最小辅助结构，而不是重新回到 `Failure/Context` 总壳设计。
3. 不为了追求 `Sendable` 纯洁性而删除关键诊断信息。

### 实现倾向

- 简单顶层 case 保持纯值语义。
- 复杂错误尽量直接关联可控字段。
- 真正需要封装 `@unchecked Sendable` 时，仅在最小局部辅助类型中使用。

---

## 验收标准

最终设计必须满足：

1. 顶层 `NtkError` 不再出现 `request/response/serialization/validation/client` 作为 public case。
2. 不再存在 `RequestFailure / ResponseFailure / SerializationFailure / ValidationFailure / ClientFailure`。
3. 不再存在统一的 `reason + context` 套壳模式。
4. `typeMismatch` 完全消失。
5. 顶层 case 都是公共失败事件，而不是内部处理阶段。
6. 复杂错误都落入独立 `enum XXError: Error`。
7. 除已提升为公共失败事件的取消与超时外，其余 AF 错误统一通过 `clientFailed(reason: .af(...))` 暴露。
8. retry、toast、executor、task manager、policy 都改为消费新模型。
9. Objective-C bridge 术语与 code 段同步更新。
10. `NtkError.Cache` 继续独立存在，不并入本次主链重构。
11. decoder 输入形态错误与 decoder 真正抛错必须分离，不得重新混成新的模糊 decode case。
12. `invalidRequest` / `invalidResponseType` / `invalidTypedResponse` 的边界必须按本 spec 的顶层事件判定表执行，不得自由发挥。

---

## 最终结论

本次最优方案不是在现有五域设计上修补，而是彻底改造 `NtkError` 的 public API 轴线：

- 从“内部错误分类树”
- 改成“公共失败事件入口 + 独立子错误类型”

这才是真正贴近 `AFError` 的设计方式，也最符合当前项目“无兼容压力，直接按最优方案重构”的要求。
