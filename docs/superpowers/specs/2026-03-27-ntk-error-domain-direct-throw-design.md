# NtkError 域错误直抛设计

## 背景

当前错误模型将 `ValidationError`、`SerializationError`、`Client` 通过顶层包装 case 暴露：

- `responseValidationFailed(reason:)`
- `responseSerializationFailed(reason:)`
- `clientFailed(reason:)`

这种设计带来的主要问题是：

1. 真实错误类型需要先包装成 `NtkError`，再由调用方二次拆解。
2. 调用方通常只能先 `catch let error as NtkError`，再写较大的 `switch` 或 `if case`。
3. 顶层包装 case 没有增加新的上下文信息，只是在重复表达子域分类。
4. 当前仓库已经允许 `NtkError.Cache.noCache` 这类嵌套错误直接抛出和捕获，说明“所有错误必须先收敛为顶层 `NtkError`”并不是既有硬约束。

本次调整没有兼容 API 压力，目标是一次性把错误模型收敛到更直接、更一致的形态。

---

## 设计目标

1. 让域错误可以直接抛出与捕获，避免无信息增量的顶层包装。
2. 将 `NtkError` 收敛为**最小顶层错误集合 + 错误命名空间**。
3. 统一所有域错误的建模方式，包括 `ValidationError`、`SerializationError`、`Client`、`Cache`。
4. 让错误类型边界与组件边界一致：谁产生错误，谁直接抛所属域错误。
5. 让调用方可以按具体域优先消费错误，再按顶层通用错误兜底。

---

## 非目标

1. 不保留 `responseValidationFailed(reason:)` / `responseSerializationFailed(reason:)` / `clientFailed(reason:)` 作为过渡兼容层。
2. 不设计新的统一错误分类辅助层（例如 category 映射）。
3. 不要求 `catch let error as NtkError` 继续覆盖所有网络错误。
4. 不在本次重构中新增额外抽象来弥补顶层包装删除后的行为差异。

---

## 核心设计

### 1. `NtkError` 的新定位

`NtkError` 重新定位为：

- 错误命名空间
- 少量顶层通用错误的容器
- 多个域错误嵌套类型的宿主

它不再承担“统一包装所有网络错误”的职责。

### 2. 顶层 `NtkError` 的保留范围

`NtkError` 顶层只保留真正跨域、不可再细分、且已经足够稳定的通用错误：

```swift
public enum NtkError: Error, Sendable {
    case invalidRequest
    case unsupportedRequestType
    case invalidResponseType
    case invalidTypedResponse
    case responseBodyEmpty
    case requestCancelled
    case requestTimeout

    public enum Cache: Error, Sendable {
        case noCache
    }
}
```

### 3. 域错误作为正式可抛出的类型

以下嵌套类型全部作为正式错误边界直接抛出：

- `NtkError.Validation`
- `NtkError.Serialization`
- `NtkError.Client`
- `NtkError.Cache`

其中：

- `Validation` 表示业务响应校验失败
- `Serialization` 表示 payload / decode / data interpretation 失败
- `Client` 表示客户端实现层失败
- `Cache` 表示缓存域失败

---

## 建模规则

### 规则 1：删除所有域错误包装 case

以下 case 全部删除：

```swift
case responseValidationFailed(reason: ValidationError)
case responseSerializationFailed(reason: SerializationError)
case clientFailed(reason: Client)
```

删除后不保留任何兼容层或中间态。

### 规则 2：组件直接抛所属域错误

以后谁产生错误，谁直接抛对应域错误。

#### Validation

```swift
throw NtkError.Validation.serviceRejected(...)
```

#### Serialization

```swift
throw NtkError.Serialization.invalidJSON(...)
throw NtkError.Serialization.invalidEnvelope(...)
throw NtkError.Serialization.dataDecodingFailed(...)
```

#### Client

```swift
throw NtkError.Client.external(...)
throw NtkError.Client.AF.requestFailed
```

#### Cache

```swift
throw NtkError.Cache.noCache
```

### 规则 3：顶层 `NtkError` 只用于真正顶层错误

只有不属于具体域、或本来就是框架层通用失败事件时，才允许直接抛顶层 `NtkError`：

```swift
throw NtkError.invalidRequest
throw NtkError.requestTimeout
```

禁止把域错误重新包装回顶层 `NtkError`。

### 规则 4：统一 catch 顺序

调用方推荐按“具体域优先，顶层兜底”的顺序处理：

```swift
catch let error as NtkError.Validation { ... }
catch let error as NtkError.Serialization { ... }
catch let error as NtkError.Client { ... }
catch let error as NtkError.Cache { ... }
catch let error as NtkError { ... }
```

该顺序是本次设计的明确消费约定。

### 规则 5：测试以真实错误类型为中心

测试不再验证“是否最终包装成顶层事件 case”，而应验证：

1. 是否抛出了正确的域错误类型
2. associated value 是否正确
3. 请求、响应、payload、underlyingError 等上下文是否正确保留

---

## 典型示例

### 旧写法

```swift
throw NtkError.responseSerializationFailed(reason: .invalidJSON(...))
```

```swift
catch let error as NtkError {
    if case let .responseSerializationFailed(reason) = error {
        ...
    }
}
```

### 新写法

```swift
throw NtkError.Serialization.invalidJSON(...)
```

```swift
catch let error as NtkError.Serialization {
    ...
}
```

### 顶层兜底错误

```swift
throw NtkError.invalidTypedResponse
```

```swift
catch let error as NtkError {
    ...
}
```

---

## 落地范围

### 1. 类型定义

核心入口：

- `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`

改造内容：

1. 删除三个包装 case
2. 保留顶层通用错误
3. 保留嵌套域错误命名空间结构

### 2. throw 点迁移

所有原先写成以下形式的代码：

- `NtkError.responseValidationFailed(reason: ...)`
- `NtkError.responseSerializationFailed(reason: ...)`
- `NtkError.clientFailed(reason: ...)`

统一改成直接抛对应域错误。

当前主要集中在：

- `Sources/CooNetwork/NtkNetwork/parsing/`
- `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- `Sources/AlamofireClient/Client/AFClient.swift`

### 3. 消费点迁移

所有依赖顶层包装分类的逻辑必须改成直接按域错误消费。

当前已确认的关键行为点：

- `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift`
- `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift`

### 4. 测试迁移

所有先 `catch as NtkError` 再匹配包装 case 的测试都要改为直接捕获域错误类型。

### 5. 文档与注释同步

至少同步：

- `docs/design-decisions.md`
- 错误模块相关注释
- 仍然引用包装 case 的说明文字

---

## 行为变化

### 1. `catch let error as NtkError` 语义变化

改造完成后：

```swift
catch let error as NtkError
```

只兜底层通用错误，不再自动覆盖：

- `NtkError.Validation`
- `NtkError.Serialization`
- `NtkError.Client`
- `NtkError.Cache`

这是本次重构最重要的行为变化。

### 2. 域错误成为对外稳定边界

域错误不再只是顶层 `NtkError` 的附属 reason，而是正式对外暴露的稳定错误边界。

### 3. 顶层错误不再承担统一分类入口职责

如果少数封装层未来需要统一按大类归类（例如 toast / retry / 埋点），应在消费边界显式按类型做判断，而不是依赖顶层包装 case。

---

## 风险与约束

### 风险 1：遗漏 `catch as NtkError`

如果只改 throw 点、不改消费点，会导致原本以为能抓住域错误的代码失效。

**约束：** 不能只做生产点迁移，必须同步完成消费点迁移。

### 风险 2：测试语义漂移

有些测试原本断言的是“包装层存在”，而不是“真实错误类型正确”。

**约束：** 测试迁移时必须连同断言语义一起迁移，不能只改到能编译。

### 风险 3：文档口径冲突

当前 `docs/design-decisions.md` 的错误架构描述与本方案冲突。

**约束：** 本次改造必须同步更新设计决策文档与相关注释。

---

## 实施建议

推荐顺序：

1. 修改 `NtkError` 类型定义
2. 修改全部 throw 点
3. 修改业务消费点（如 retry / toast）
4. 修改测试
5. 修改文档与注释

该顺序可以先固定模型，再修行为点，最后完成验证与说明层同步。

---

## 验收标准

重构完成后，应满足以下条件：

1. 仓库中不再存在：
   - `responseValidationFailed(`
   - `responseSerializationFailed(`
   - `clientFailed(`
2. `Validation`、`Serialization`、`Client`、`Cache` 都作为可直接抛出的域错误使用。
3. 关键消费点不再依赖顶层包装分类。
4. 测试围绕具体错误类型断言。
5. 文档已明确 `NtkError` 的新定位：最小顶层 + 错误命名空间。
6. 改造完成后，不允许再引入新的“域错误包回顶层”模式。

---

## 最终结论

本次错误模型重构采用：

**最小顶层 `NtkError` + 域错误直抛**

即：

- `NtkError` 只保留少量真正顶层公共错误
- `Validation` / `Serialization` / `Client` / `Cache` 作为 `NtkError` 的嵌套类型直接抛出与捕获
- 删除所有域错误包装 case
- 调用方按“具体域优先，顶层兜底”的顺序消费错误

该方案的价值在于：

- 消除无信息增量的重复包装
- 让错误类型语义与组件边界保持一致
- 改善 `catch` 体验
- 让 `NtkError` 回归命名空间 + 最小顶层错误容器角色
