# decodeInvalid Context Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `NtkError.decodeInvalid` 从“宽泛 `Sendable` 上下文”重构为“专用错误载体”，并在存在 recovered `NtkResponse<NtkDynamicData?>` 时直接向开发者暴露该响应。

**Architecture:** 保持现有 parsing pipeline 职责不变：`NtkDataParsingInterceptor` 继续负责 interpret，`NtkDefaultResponseParsingPolicy` 继续负责最终裁决。这次改动只收敛 `decodeInvalid` 的错误建模：在 `NtkError` 内引入嵌套类型 `DecodeInvalid`，统一承载 `underlyingError`、可选 recovered `response`、以及兜底 `rawValue`，并让 policy 在 header 已恢复且 validation 通过时把已构造的 `NtkResponse<NtkDynamicData?>` 一并带出。`rawValue` 的标准语义固定为“原始调用方上下文值”，在 policy 路径中使用 `failure.clientResponse.data`；即使 `response` 存在也继续保留 `rawValue` 作为诊断 fallback，但对外以 `response` 为第一优先级。

**Tech Stack:** Swift 6.1 / Swift Package Manager / Swift Testing / CooNetwork parsing module

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/error/NtkError.swift` | 将 `decodeInvalid` 改为携带嵌套错误载体 `NtkError.DecodeInvalid`，定义字段与初始化器。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift` | 在 decode failure 路径改为构造 `NtkError.DecodeInvalid`；header recovered 且 validation 通过时把 `NtkResponse<NtkDynamicData?>` 填进 `response`。 |
| `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift` | 更新本地 `decodeInvalid` 抛错方式，改为新的错误载体形式，`response` 为 `nil`。 |
| `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift` | 增强 policy 白盒测试：区分 recovered / unrecovered decode failure，断言 `response`/`rawValue` 语义。 |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | 更新对外行为测试，验证 `invalidJsonThrowsDecodeInvalid` 能直接拿到 recovered `NtkResponse<NtkDynamicData?>`。 |
| `Examples/PodExample/PodExample/TestModels.swift` | 将手动抛出的 `.decodeInvalid(...)` 迁移到新载体形式。 |
| `Examples/PodExample/PodExample/ViewController.swift` | 将手动抛出的 `.decodeInvalid(...)` 迁移到新载体形式。 |

### Search Sweep

实现时全仓检索并替换以下调用样式：

1. `decodeInvalid(`
2. `if case .decodeInvalid`
3. `if case let .decodeInvalid(`

验收标准：生产代码中不再残留旧签名 `case decodeInvalid(_ error: Error, _ response: Sendable, _ request: iNtkRequest? = nil)` 的构造或依赖；测试根据新载体断言 `response` 与 `rawValue`。

---

## Task 1: 先锁定新错误模型的 RED 测试

**Files:**
- Modify: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Read if needed: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`

- [ ] **Step 1.1: 在 policy tests 中先写 recovered / unrecovered 两类 decodeInvalid 断言**

先把以下行为写成测试目标：

- decode failure + header recovered + validation pass → 抛 `decodeInvalid`，且 `error.response != nil`
- decode failure + no header → 抛 `decodeInvalid`，且 `error.response == nil`
- decode failure + header recovered + validation fail → 仍然抛 `validation`

推荐把 `decodeFailureWithHeaderValidationPassStillThrowsDecodeInvalid` 改成显式断言：

```swift
if case let .decodeInvalid(error) = ntkError {
    let response = try #require(error.response)
    #expect(response.code.intValue == 999)
    #expect(response.msg == "fail")
}
```

- [ ] **Step 1.2: 在 interceptor 场景测试中先锁定开发者体验目标**

把 `invalidJsonThrowsDecodeInvalid` 改成新语义断言：

```swift
if case let .decodeInvalid(error) = ntkError {
    let response = try #require(error.response)
    #expect(response.code.intValue == 0)
    #expect(response.msg == "ok")
    #expect(response.data?.getString() == "not_an_object")
}
```

同时把以下测试补成新语义：

- `emptyResponseBodyThrowsDecodeInvalid` → `response == nil`
- `decodeFailureWithoutRecoveredHeaderThrowsDecodeInvalid` → `response == nil`

- [ ] **Step 1.3: 运行聚焦测试，确认在旧实现下进入 RED**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
swift test --filter NtkDataParsingInterceptorTests
```

Expected:
- 测试因为旧的 `decodeInvalid` 签名/结构不匹配而失败
- 失败点直接指向错误模型迁移，而不是无关编译错误

- [ ] **Step 1.4: 记录 RED 结果，不做红态提交**

明确记录：
- 红态来自 `decodeInvalid` 错误模型尚未迁移
- 此阶段只用于锁定行为目标
- 不在红态提交 commit

---

## Task 2: 重构 `NtkError.decodeInvalid` 为嵌套错误载体（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`

- [ ] **Step 2.1: 在 `NtkError` 内新增嵌套类型 `DecodeInvalid`**

在 `NtkError.swift` 中新增：

```swift
public struct DecodeInvalid: Error, @unchecked Sendable {
    public let underlyingError: Error
    public let response: NtkResponse<NtkDynamicData?>?
    public let rawValue: Sendable?

    public init(
        underlyingError: Error,
        response: NtkResponse<NtkDynamicData?>? = nil,
        rawValue: Sendable? = nil
    ) {
        self.underlyingError = underlyingError
        self.response = response
        self.rawValue = rawValue
    }
}
```

要求：
- 不新增 `request`
- 不使用 `any iNtkResponse`
- `response` 固定为 `NtkResponse<NtkDynamicData?>?`
- 先按 `@unchecked Sendable` 规划，避免 `underlyingError: Error` 在 Swift 6 下阻塞编译；若实现时确认存在更窄但稳定的类型签名，再单独收敛

- [ ] **Step 2.2: 将 `decodeInvalid` case 改为单参数错误载体**

把：

```swift
case decodeInvalid(_ error: Error, _ response: Sendable, _ request: iNtkRequest? = nil)
```

改为：

```swift
case decodeInvalid(DecodeInvalid)
```

- [ ] **Step 2.3: 更新与 `decodeInvalid` 相关的注释，明确 `response` 的优先语义**

注释必须说明：
- `underlyingError` 表示底层 decode 根因
- `response` 仅在框架已恢复出结构化 envelope 时提供
- `rawValue` 是没有 recovered response 时的兜底上下文

- [ ] **Step 2.4: 运行 policy tests，确认类型层变更可编译并进入下一步失败点**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
```

Expected:
- 若 policy 构造点尚未迁移，失败应推进到调用点
- 不再因 `NtkError` 定义本身阻塞编译

---

## Task 3: 让 parsing policy 在可恢复场景里带出 `NtkResponse`（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`

- [ ] **Step 3.1: 改造 `decodeFailed` 分支的 header recovered 路径**

在 `failure.header != nil` 时，当前代码已经构造：

```swift
let response = NtkResponse<NtkDynamicData?>(...)
```

保留这段构造；在 `validateServiceSuccess(...)` 通过后，抛出：

```swift
throw NtkError.decodeInvalid(
    .init(
        underlyingError: failure.decodeError,
        response: response,
        rawValue: failure.clientResponse.data
    )
)
```

要求：不能再丢弃 recovered `response`。

- [ ] **Step 3.2: 改造 `decodeFailed` 分支的 no-header 路径**

在 `failure.header == nil` 时，抛出：

```swift
throw NtkError.decodeInvalid(
    .init(
        underlyingError: failure.decodeError,
        rawValue: failure.clientResponse.data
    )
)
```

要求：
- `response` 必须为 `nil`
- 不要虚构 `NtkResponse`

- [ ] **Step 3.3: 保持 validation 优先级不变**

确认以下边界不被破坏：

- header recovered + validation fail → 仍抛 `NtkError.validation`
- 只有 validation pass 后，才可能落到 `decodeInvalid(response != nil)`

- [ ] **Step 3.4: 运行 policy tests 验证 GREEN**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
```

Expected:
- `decodeFailureWithHeaderValidationPassStillThrowsDecodeInvalid` 通过
- `decodeFailureWithoutHeaderThrowsDecodeInvalid` 通过
- `decodeFailureWithHeaderValidationFailureThrowsValidation` 仍通过
- hooks 行为保持原样（`didComplete` 不被触发）

- [ ] **Step 3.5: 提交一次聚焦 policy 的 commit**

```bash
git add Sources/CooNetwork/NtkNetwork/error/NtkError.swift Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift
git commit -m "refactor: add structured decodeInvalid context"
```

---

## Task 4: 迁移其他 `decodeInvalid` 构造点并补齐场景测试（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Modify: `Examples/PodExample/PodExample/TestModels.swift`
- Modify: `Examples/PodExample/PodExample/ViewController.swift`

- [ ] **Step 4.1: 更新 `NtkDynamicData` 的本地 decode 失败抛错方式**

把当前：

```swift
throw NtkError.decodeInvalid(..., "解码失败的数据")
```

改成新载体形式：

```swift
throw NtkError.decodeInvalid(
    .init(
        underlyingError: ...,
        rawValue: "解码失败的数据"
    )
)
```

要求：`response` 必须为 `nil`。

- [ ] **Step 4.2: 更新 examples 中所有手动 `.decodeInvalid(...)` 构造点**

统一迁移为：

```swift
throw NtkError.decodeInvalid(
    .init(
        underlyingError: error,
        rawValue: rawData
    )
)
```

若某个 example 只有字符串说明，则填字符串。

- [ ] **Step 4.3: 为 `NtkDynamicData` 本地 decode failure 补一个专门测试**

新增一条最小测试，验证 `NtkDynamicData` 在本地 decode 失败时：

```swift
if case let .decodeInvalid(error) = ntkError {
    #expect(error.response == nil)
    #expect(error.rawValue != nil)
}
```

要求：
- 覆盖 `NtkDynamicData.swift` 中的构造点
- 至少验证 `response == nil`
- 至少验证 `underlyingError` 仍是预期 decode 根因类型

- [ ] **Step 4.4: 更新 interceptor 测试以验证 recovered response 暴露给开发者**

重点测试：
- `invalidJsonThrowsDecodeInvalid`：断言 `response != nil`
- `emptyResponseBodyThrowsDecodeInvalid`：断言 `response == nil`
- `decodeFailureWithoutRecoveredHeaderThrowsDecodeInvalid`：断言 `response == nil`
- `decodeFailureWithHeaderDoesNotTriggerDidDecodeHeaderOrDidComplete`：在保留 hook 断言的同时，增加 `response != nil` 断言

- [ ] **Step 4.5: 运行聚焦场景测试验证 GREEN**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected:
- 上述 decodeInvalid 场景全部通过
- hooks 测试仍保持既有语义
- 没有因 `DecodeInvalid` 新模型导致的模式匹配遗漏

- [ ] **Step 4.6: 提交一次聚焦场景迁移的 commit**

```bash
git add Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift Examples/PodExample/PodExample/TestModels.swift Examples/PodExample/PodExample/ViewController.swift
git commit -m "test: verify recovered response in decodeInvalid"
```

---

## Task 5: 全量验证并清理残留（GREEN）

**Files:**
- Modify as needed: 全仓残留 `decodeInvalid` 调用/断言位置
- Test: 全量相关测试

- [ ] **Step 5.1: 全仓检索旧的 `decodeInvalid` 调用与模式匹配残留**

检索并处理：

```text
decodeInvalid(
if case .decodeInvalid
if case let .decodeInvalid(
```

要求：
- 生产代码不再残留旧构造方式
- 测试断言不再依赖旧的三参数 case 结构

- [ ] **Step 5.2: 运行核心测试集合**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
swift test --filter NtkDataParsingInterceptorTests
swift test
```

Expected:
- 聚焦测试全部 PASS
- 全量测试 PASS
- 若有失败，必须先判断是否为旧签名残留或断言语义需要同步更新

- [ ] **Step 5.3: 人工核对最终语义是否满足目标**

逐项确认：
- 有 recovered `NtkResponse<NtkDynamicData?>` 的 decodeInvalid 场景，`error.response` 非空
- 无 recovered response 的场景，`error.response == nil`
- 开发者不需要重新序列化即可读取 `code/msg/data`
- `validation` 与 `decodeInvalid` 的边界未被打乱

- [ ] **Step 5.4: 提交最终整合 commit**

```bash
git add Sources/CooNetwork/NtkNetwork/error/NtkError.swift Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift Examples/PodExample/PodExample/TestModels.swift Examples/PodExample/PodExample/ViewController.swift
git commit -m "refactor: expose recovered response in decodeInvalid"
```

---

## Verification Checklist

- [ ] `NtkError.decodeInvalid` 已改为单参数错误载体
- [ ] `NtkError.DecodeInvalid.response` 使用具体类型 `NtkResponse<NtkDynamicData?>?`
- [ ] 不保留独立 `request` 字段
- [ ] policy 的 recovered-header 路径会把已构造的 `NtkResponse` 带出
- [ ] no-header / 非 envelope 场景不会伪造 `NtkResponse`
- [ ] `invalidJsonThrowsDecodeInvalid` 直接断言 recovered `response`
- [ ] `NtkDynamicData` 本地 decode failure 断言 `response == nil` 且 `underlyingError` 保持 decode 根因
- [ ] `rawValue` 语义固定为原始调用方上下文值；在 policy recovered-response 路径中保留为辅助诊断字段
- [ ] 全量测试通过

## Notes for Implementers

- 不要把 `any iNtkResponse` 引入 `DecodeInvalid.response`；这会把开发者再次逼回类型转换。
- 不要把 parsing 内部类型（如 `NtkPayload` / `DecodeFailure` / `NtkClientResponse`）暴露进公共错误模型。
- `rawValue` 是 fallback，不是主通道；有 `response` 时优先使用 `response`。
- 不要顺手重构其他错误 case；本次只聚焦 `decodeInvalid` 建模与测试语义。
