# NtkError Nested Types Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有独立错误类型平移为 `NtkError` 嵌套类型，保持现有顶层 `NtkError` case、错误语义边界、抛错位置与消费逻辑不变。

**Architecture:** 本次迁移只做类型归属收口，不做错误模型重构。顶层 `NtkError` 继续承载公共失败事件；`NtkResponseSerializationError`、`NtkResponseValidationError`、`NtkClientError` 平移为 `NtkError.SerializationError`、`NtkError.ValidationError`、`NtkError.Client`，现有 `NtkClientError.AF` 平移为 `NtkError.Client.AF`。所有生产代码、测试代码、桥接与消费侧只更新类型路径，不改变 case 结构与业务语义。

**Tech Stack:** Swift 6.1 / Swift Package Manager / Swift Testing / CooNetwork / Alamofire

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/error/NtkError.swift` | 在 `NtkError` 内新增 `SerializationError` / `ValidationError` / `Client` 嵌套类型，并将顶层关联值类型切换到嵌套类型。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift` | 删除独立顶层定义，改为 `public extension NtkError { enum SerializationError ... }`。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift` | 删除独立顶层定义，改为 `public extension NtkError { enum ValidationError ... }`。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift` | 删除独立顶层定义，改为 `public extension NtkError { enum Client ... }`。 |
| `Sources/AlamofireClient/Error/AFClientError.swift` | `NtkClientError` / `NtkClientError.AF` 改为 `NtkError.Client` / `NtkError.Client.AF`。 |
| `Sources/AlamofireClient/Client/AFClient.swift` | 更新 `clientFailed(reason:)` 的 reason 类型引用到 `NtkError.Client`。 |
| `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift` | 更新 client 错误消费逻辑到 `NtkError.Client` / `NtkError.Client.AF`。 |
| `Sources/CooNetwork/NtkNetwork/parsing/*.swift` | 更新 serialization / validation 嵌套类型引用。 |
| `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift` | 更新 `clientFailed` 子错误类型引用。 |
| `Tests/CooNetworkTests/**/*.swift` | 更新所有断言、catch、pattern matching 的类型路径。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+OC.swift`（如存在） | 若桥接依赖具体类型名，改为嵌套类型名。 |

---

## Task 1: 切换错误类型定义骨架

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift`

- [x] **Step 1.1: 在 `NtkError.swift` 中把顶层关联值切到嵌套类型**
- [x] **Step 1.2: 将 `NtkResponseSerializationError` 改写为 `NtkError.SerializationError`**
- [x] **Step 1.3: 将 `NtkResponseValidationError` 改写为 `NtkError.ValidationError`**
- [x] **Step 1.4: 将 `NtkClientError` 改写为 `NtkError.Client`**
- [x] **Step 1.5: 保持所有 case、关联值、Sendable 策略不变**

**Checkpoint:** 编译层面只允许出现“旧类型名引用未迁移”，不允许出现语义重构。

---

## Task 2: 迁移生产代码引用

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift`
- Modify: `Sources/AlamofireClient/Error/AFClientError.swift`
- Modify: `Sources/AlamofireClient/Client/AFClient.swift`
- Modify: `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift`
- Modify: 其他直接引用旧类型名的生产文件

- [x] **Step 2.1: 把 serialization 相关引用改为 `NtkError.SerializationError`**
- [x] **Step 2.2: 把 validation 相关引用改为 `NtkError.ValidationError`**
- [x] **Step 2.3: 把 client 相关引用改为 `NtkError.Client`**
- [x] **Step 2.4: 把 `NtkClientError.AF` 改为 `NtkError.Client.AF`**
- [x] **Step 2.5: 保持所有 throw / catch / switch 分支位置不变，仅更新类型路径**

---

## Task 3: 迁移测试与桥接引用

**Files:**
- Modify: `Tests/CooNetworkTests/**/*.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError+OC.swift`（如存在）
- Modify: 其他依赖旧类型名字符串或桥接的文件

- [x] **Step 3.1: 更新测试中的类型断言、catch 与 pattern matching**
- [x] **Step 3.2: 更新桥接或错误描述中依赖具体类型名的地方**
- [x] **Step 3.3: 检查不再存在旧类型名的直接引用**

---

## Task 4: 验证与收尾

**Files:**
- Modify as needed: 迁移后暴露问题的文件

- [x] **Step 4.1: 运行关键测试或最小可行验证，确认嵌套类型迁移可编译、可运行**
- [x] **Step 4.2: 修复迁移遗漏的引用或模式匹配问题**
- [x] **Step 4.3: 做全仓收尾检查，确认旧类型名已清理完成**
- [x] **Step 4.4: 输出结果摘要与剩余风险（若有）**

---

## Verification Checklist

- [x] `NtkError` 顶层 case 未改变语义
- [x] `NtkResponseSerializationError` 已平移为 `NtkError.SerializationError`
- [x] `NtkResponseValidationError` 已平移为 `NtkError.ValidationError`
- [x] `NtkClientError` 已平移为 `NtkError.Client`
- [x] `NtkClientError.AF` 已平移为 `NtkError.Client.AF`
- [x] `clientFailed(reason:)` / `responseSerializationFailed(reason:)` / `responseValidationFailed(reason:)` 仍保留原有顶层入口
- [x] 生产代码不再直接引用旧独立类型名
- [x] 测试代码不再直接引用旧独立类型名
- [x] 迁移仅为类型归属整理，不引入新的错误语义变化
