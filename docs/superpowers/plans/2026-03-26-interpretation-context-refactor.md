# Interpretation Context Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `NtkInterpretation` 从“多个长参数枚举分支”重构为“少量状态 + 内嵌上下文类型”的模型，降低理解负担，同时保持 parsing 行为与错误语义不变。

**Architecture:** 保持现有 parsing 五阶段职责不变：`NtkDataParsingInterceptor` 继续产出 Interpret 阶段中间模型，`NtkDefaultResponseParsingPolicy` 继续消费该模型并作最终裁决。此次重构只调整 `NtkInterpretation` 的建模方式：把 `decoded` / `decodeFailed` 的关联数据收敛为内嵌类型，并把“是否提取到 header”从独立 case 降为 `DecodeFailure.header` 可选属性。核心建模原则是：`header` 表示 failure context completeness（失败上下文完整度），而不是另一种独立的 interpret result category。

**Tech Stack:** Swift 6.1 / Swift Package Manager / Swift Testing / CooNetwork parsing module

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingResult.swift` | 重构 `NtkInterpretation`：新增内嵌类型 `Decoded` / `DecodeFailure`，收缩枚举 case，改写注释。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift` | 改为构造 `NtkInterpretation.Decoded` / `NtkInterpretation.DecodeFailure`；删除“按 header 选择不同 failure case”的逻辑。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift` | 改为消费 `decoded(Decoded)` / `decodeFailed(DecodeFailure)`；在单一 failure 分支内基于 `failure.header` 处理 fallback。 |
| `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift` | 更新白盒测试 helper、构造方式和测试命名，匹配新 interpretation 结构。 |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | 同步场景测试命名，确认对外行为与 hooks 语义未变。 |

### Expected search sweep

实现时需全仓检索并清理以下符号残留：

1. `decodeFailedWithHeader`
2. `headerRecovered`
3. `unrecoverableDecodeFailure`
4. `NtkParsingResult`
5. `recoverInterpretResult`

清理范围限定为：
- 生产代码
- 当前测试 helper / 测试名 / 当前模块说明注释

不要求强制改写历史 spec / plan / 设计演进文档中的旧术语，避免抹平历史语境。

验收标准：当前实现代码路径中不再残留旧 interpretation 结构名称；测试名允许保留 with/without header 场景语义，但不应继续绑定旧枚举模型。

---

## Task 1: 先锁定现有 failure 语义（RED）

**Files:**
- Modify: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Read if needed: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 1.1: 盘点 interpretation 当前需要保留的不变语义**

在写测试前，先明确这次重构必须保持不变的行为：

- `decoded` 成功路径仍可返回 typed response
- `decoded + nil data + validation pass` 仍抛 `serviceDataEmpty`
- `decoded + nil data + validation fail` 仍抛 `validation`
- `NtkNever` 路径仍成功并触发 `didComplete`
- decode failure + header 仍会先走 validation，再最终抛 `decodeInvalid`
- decode failure + no header 仍直接抛 `decodeInvalid`
- failure 路径仍不会触发 `didComplete`

交付物：把这些语义映射到现有 policy tests 名称，确认没有空白项。

- [ ] **Step 1.2: 先写一个依赖“单一 failure case + 可选 header”新形态的 failing test helper**

在 `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift` 中，把旧 helper 先改造成目标形态，例如：

```swift
private func makeDecodeFailureInterpretation(
    header: NtkExtractedHeader?
) -> NtkInterpretation<PolicyTestModel> {
    .decodeFailed(
        .init(
            decodeError: makePolicyDecodeError(),
            rawPayload: .dynamic(...),
            header: header,
            request: PolicyTestRequest(),
            clientResponse: makePolicyClientResponse(),
            isCache: false
        )
    )
}
```

并让至少一条现有 header / no-header 测试改用该 helper。

- [ ] **Step 1.3: 运行 policy focused tests，验证新 helper 在旧实现下失败**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
```

Expected:
- 在生产代码尚未修改前，测试因旧 interpretation 结构不匹配而失败
- 失败原因必须直接指向本次模型重构，而不是拼写或无关错误

- [ ] **Step 1.4: 记录 RED 结果，不做红态提交**

在执行记录中明确：
- 红态是由 interpretation 模型尚未迁移导致
- 此 RED 仅用于锁定新结构目标
- 不在红态提交 git commit

---

## Task 2: 重构 `NtkInterpretation` 为“状态 + 内嵌上下文类型”（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingResult.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`

- [ ] **Step 2.1: 在 `NtkInterpretation` 内新增 `Decoded` 内嵌类型**

在 `NtkParsingResult.swift` 中新增：

```swift
struct Decoded: Sendable {
    let code: NtkReturnCode
    let msg: String?
    let data: ResponseData?
    let request: iNtkRequest
    let clientResponse: NtkClientResponse
    let isCache: Bool
}
```

- [ ] **Step 2.2: 在 `NtkInterpretation` 内新增 `DecodeFailure` 内嵌类型**

新增：

```swift
struct DecodeFailure: Sendable {
    let decodeError: DecodingError
    let rawPayload: NtkPayload
    let header: NtkExtractedHeader?
    let request: iNtkRequest
    let clientResponse: NtkClientResponse
    let isCache: Bool
}
```

关键要求：`header` 必须是可选，不再通过独立 case 表达。

- [ ] **Step 2.3: 收缩枚举 case 为两类状态**

将旧 case：

```swift
case decoded(...)
case decodeFailedWithHeader(...)
case decodeFailed(...)
```

改为：

```swift
case decoded(Decoded)
case decodeFailed(DecodeFailure)
```

- [ ] **Step 2.4: 缩短并改写类型注释，明确 header 是 failure 上下文，不是独立状态**

注释必须表达：
- `NtkInterpretation` 只描述 Interpret 阶段解释结果，不描述最终裁决
- decode failure 只有一种状态
- `header` 是 `DecodeFailure` 的可选上下文
- 注释优先解释建模原则，而不只是重复字段定义

不要再保留“三类状态”的旧描述，也不要把注释写回长篇设计文档腔。

- [ ] **Step 2.5: 运行 policy tests，确认类型层迁移后可以编译进入下一步**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
```

Expected:
- 如果 interceptor / policy 尚未完全迁移，测试仍可能失败
- 但失败点应推进到消费方代码，而不是类型定义本身

---

## Task 3: 更新 `NtkDataParsingInterceptor` 的 interpretation 产出方式（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 3.1: 把 `decoded` 成功返回改为构造 `NtkInterpretation.Decoded`**

将原先：

```swift
return .decoded(code: ..., msg: ..., data: ..., ...)
```

改为：

```swift
let decoded = NtkInterpretation<ResponseData>.Decoded(...)
return .decoded(decoded)
```

- [ ] **Step 3.2: 把 `makeInterpretFailureResult(...)` 改为统一构造 `DecodeFailure`**

将当前“按 header 选择不同 case”的逻辑改为：

```swift
let failure = NtkInterpretation<ResponseData>.DecodeFailure(
    decodeError: error,
    rawPayload: prepared.payload,
    header: try? decoder.extractHeader(prepared.payload, request: prepared.request),
    request: prepared.request,
    clientResponse: prepared.clientResponse,
    isCache: prepared.clientResponse.isCache
)
return .decodeFailed(failure)
```

- [ ] **Step 3.3: 删除所有旧 failure case 构造分支**

必须完全删除：
- `.decodeFailedWithHeader(...)`
- “if has header then choose another case” 这种分支式建模

保留的逻辑只应是：
- 先尝试提取 header
- 再把 header 作为可选字段塞进 `DecodeFailure`

- [ ] **Step 3.4: 运行 interceptor focused tests，确认 interpretation 生产侧没有行为漂移**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected:
- decode success / validation / nil data / failure hooks 相关行为全部保持不变
- 新旧差异只体现在内部 interpretation 模型，不体现在对外行为

---

## Task 4: 更新 `NtkDefaultResponseParsingPolicy` 的 interpretation 消费方式（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`

- [ ] **Step 4.1: 把 `decoded` 分支改为消费 `Decoded` 对象**

从：

```swift
case let .decoded(code, msg, data, request, clientResponse, isCache):
```

改为：

```swift
case let .decoded(decoded):
```

然后内部统一改读：
- `decoded.code`
- `decoded.msg`
- `decoded.data`
- `decoded.request`
- `decoded.clientResponse`
- `decoded.isCache`

- [ ] **Step 4.2: 合并 failure 分支为单一 `decodeFailed(failure)`**

从两个分支：

```swift
case let .decodeFailedWithHeader(...)
case let .decodeFailed(...)
```

改为：

```swift
case let .decodeFailed(failure):
```

- [ ] **Step 4.3: 在单一 failure 分支内部基于 `failure.header` 处理 fallback**

分支内部应采用如下结构：

```swift
if let header = failure.header {
    let response = ...
    try await validateServiceSuccess(response, request: failure.request, context: context)
}
throw NtkError.decodeInvalid(failure.decodeError, failure.clientResponse.data, failure.request)
```

关键要求：
- 有 header 时保留既有 fallback + validation 行为
- 无 header 时直接抛 `decodeInvalid`
- 不引入新的行为分支

- [ ] **Step 4.4: 运行 policy focused tests，确认消费侧语义完全不变**

Run:

```bash
swift test --filter NtkDefaultResponseParsingPolicyTests
```

Expected:
- decode success / nil data / `NtkNever` / failure with header / failure without header 全部 PASS
- `didComplete` / `didValidateFail` hooks 语义不变

---

## Task 5: 同步测试 helper 与命名，清理旧符号残留（REFACTOR）

**Files:**
- Modify: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Search sweep: whole repo

- [ ] **Step 5.1: 把 policy tests 的 helper 改成新模型构造方式**

建议改成两个 helper：

```swift
private func makeDecodeFailureWithHeaderInterpretation() -> NtkInterpretation<PolicyTestModel>
private func makeDecodeFailureWithoutHeaderInterpretation() -> NtkInterpretation<PolicyTestModel>
```

内部统一使用：

```swift
.decodeFailed(.init(...))
```

- [ ] **Step 5.2: 把测试名从旧 case 语义收敛为场景语义**

例如：
- `decodeFailedWithHeaderValidationFailureThrowsValidation`
- `decodeFailedWithHeaderValidationPassStillThrowsDecodeInvalid`
- `decodeFailedWithoutHeaderThrowsDecodeInvalid`
- `decodeFailureWithHeaderDoesNotTriggerDidComplete`

注意：测试名可以描述 with/without header 场景，但不要继续绑定旧枚举 case 设计。

- [ ] **Step 5.3: 全仓检索并删除旧 interpretation 符号残留**

全仓检索并清理：

```text
decodeFailedWithHeader
headerRecovered
unrecoverableDecodeFailure
NtkParsingResult
recoverInterpretResult
```

验收标准：
- 生产代码不再引用旧模型名
- 测试 helper / 测试名不再泄露旧 case 结构

- [ ] **Step 5.4: 运行 parsing focused tests，确认 refactor 后仍全绿**

Run:

```bash
swift test --filter 'NtkDefaultResponseParsingPolicyTests|NtkDataParsingInterceptorTests'
```

Expected:
- 两个 suite 全部 PASS
- 新旧行为一致，只是内部建模收敛

---

## Task 6: 全量验证与最终收尾

**Files:**
- Verify only: whole repo

- [ ] **Step 6.1: 运行 parsing focused tests 作为最终行为验证**

Run:

```bash
swift test --filter 'NtkDefaultResponseParsingPolicyTests|NtkDataParsingInterceptorTests'
```

Expected: 全部 PASS。

- [ ] **Step 6.2: 运行全量测试**

Run:

```bash
swift test
```

Expected: 全部 PASS。

- [ ] **Step 6.3: 检查工作区状态**

Run:

```bash
git status
```

Expected:
- 只有本次 interpretation 模型重构相关改动
- 没有遗漏的旧 helper、临时断言或半成品命名

- [ ] **Step 6.4: 如需提交，按“模型收敛而非行为变更”撰写 commit message**

建议提交信息：

```bash
git commit -m "refactor: collapse interpretation failure contexts"
```

---

## Deferred Work (Not In This Plan)

以下内容明确不在本计划中：

- 重新设计 `iNtkResponsePayloadDecoding` 协议
- 修改 `NtkExtractedHeader` 结构
- 调整 `NtkDefaultResponseParsingPolicy` 的业务规则
- 改动 `NtkNever` / `serviceDataEmpty` / `decodeInvalid` 语义
- 继续大范围重命名 parsing 模块其他类型
- 把 `NtkParsingResult.swift` 文件名改成 `NtkInterpretation.swift`（本计划明确延期；这是保留的命名债务，不表示问题已解决）

---

## Verification Checklist

实现完成后，必须满足：

- [ ] `NtkInterpretation` 只剩 `decoded` 与 `decodeFailed` 两个 case
- [ ] `NtkInterpretation` 内存在 `Decoded` 与 `DecodeFailure` 两个内嵌类型
- [ ] `DecodeFailure.header` 为 `NtkExtractedHeader?`
- [ ] `NtkDataParsingInterceptor` 不再通过不同 case 表达有/无 header 的 failure
- [ ] `NtkDefaultResponseParsingPolicy` 只消费一个 failure case，并通过 `failure.header` 区分 fallback 行为
- [ ] decode success / nil data / `NtkNever` / failure with header / failure without header 行为不变
- [ ] hooks 语义不变：failure 路径不触发 `didComplete`
- [ ] 当前实现代码路径中不再残留 `decodeFailedWithHeader` / `headerRecovered` / `unrecoverableDecodeFailure` / `NtkParsingResult` / `recoverInterpretResult`
- [ ] 历史 spec / plan 文档若保留旧术语，不影响本次验收
- [ ] parsing focused tests 全部通过
- [ ] 全量 `swift test` 通过
