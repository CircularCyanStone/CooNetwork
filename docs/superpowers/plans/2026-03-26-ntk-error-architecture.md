# NtkError AFError-Style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将网络请求主链的公开错误模型从“五域 + Failure(reason:context:)”重构为“公共失败事件 + 独立错误类型”，并保持 parsing / validation / retry / Alamofire / Objective-C bridge 语义不回归。

**Architecture:** 顶层 `NtkError` 只保留稳定公共失败事件，复杂错误下沉到 `NtkResponseSerializationError`、`NtkResponseValidationError`、`NtkClientError`。执行顺序以“先锁边界、再切模型、再迁语义、最后适配与清理”为主线：先用 RED 测试锁死顶层事件边界，再完成错误模型切换闸门，随后按 policy → serialization → executor/retry → AF adapter → bridge 的顺序迁移。任何提交都必须保持仓库可编译、可回退。

**Tech Stack:** Swift 6.1 / Swift Package Manager / Swift Testing / CooNetwork / Alamofire

---

## Scope Lock

本计划只覆盖**网络请求主链**错误架构迁移：

- 顶层 `NtkError` 改为公共失败事件模型
- 新增独立错误类型：`NtkResponseSerializationError` / `NtkResponseValidationError` / `NtkClientError`
- 删除旧五域壳：`RequestFailure` / `ResponseFailure` / `SerializationFailure` / `ValidationFailure` / `ClientFailure`
- parsing / interpretation / executor / dedup / retry / AF adapter / Objective-C bridge / 测试同步迁移
- 同步更新 `docs/design-decisions.md` 中已被本次 spec 替换的结论

明确不包含：

- `NtkError.Cache` 独立子系统统一
- 新的开放式 client plugin 错误机制
- 与本次错误模型无关的目录重构
- 任何兼容层、deprecated 包袱或双轨错误模型

---

## Worktree Note

实现应在独立 worktree 中执行，避免污染当前工作区并方便逐任务 review。当前工作区已有未提交改动，禁止直接在当前工作区按本计划执行。

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/error/NtkError.swift` | 重写顶层 `NtkError` 为公共失败事件模型，保留 `Cache`。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift` | 新增 serialization 独立错误类型。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift` | 新增 validation 独立错误类型。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift` | 新增 client 独立错误类型。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+OC.swift` | 重写 NSError code 与 userInfo 映射，改成新术语。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+Request.swift` | 删除。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+Response.swift` | 删除。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+Serialization.swift` | 删除。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+Validation.swift` | 删除。 |
| `Sources/CooNetwork/NtkNetwork/error/NtkError+Client.swift` | 删除。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkInterpretation.swift` | 显式处理旧 `header` 语义，仅允许作为内部中间态保留；确保不泄漏到新的 public error shape。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift` | 迁移 policy 优先级与错误映射。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift` | payload 入口失败改到 `.responseSerializationFailed(.invalidJSON)`。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift` | 区分 invalidEnvelope / invalidDataPayload 与真正 decode fail。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift` | acquire/prepare 错误改到 `.invalidResponseType` / `.invalidRequest`。 |
| `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift` | 区分 `.dataTypeMismatch` 与 `.dataDecodingFailed`。 |
| `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift` | 最终 typed response 交付失败改成 `.invalidTypedResponse`。 |
| `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift` | cancel / timeout / typed response 迁移到新顶层事件。 |
| `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift` | 改为消费新顶层事件与 `NtkClientError.af`。 |
| `Sources/AlamofireClient/Error/AFClientError.swift` | 只保留 AF → `NtkClientError.af` 映射辅助。 |
| `Sources/AlamofireClient/Client/AFClient.swift` | AF cancel/timeout 优先归一化；其他 AF 错误收口到 `.clientFailed(.af(...))`；unsupported request type 显式映射到 `.unsupportedRequestType`。 |
| `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift` | 改成消费 `requestTimeout` / `clientFailed` / `responseValidationFailed`。 |
| `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift` | 迁移 policy 语义测试。 |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | 迁移 interceptor 场景。 |
| `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift` | 迁移 payload normalize 边界。 |
| `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift` | 迁移 decoder 输入形态与 decode fail 场景。 |
| `Tests/CooNetworkTests/NtkPayloadTransformerTests.swift` | 迁移 transformer 抛错场景。 |
| `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift` | 迁移重试矩阵。 |
| `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` | 迁移 typed response / timeout 断言。 |
| `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift` | 迁移 integration 级别 validation / serialization / timeout 断言。 |
| `Tests/CooNetworkTests/NtkTaskManagerTests.swift` | 迁移 dedup / cancel / timeout / typed response。 |
| `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift` | 迁移链路超时断言。 |
| `Tests/CooNetworkTests/CooNetworkTests.swift` | 迁移顶层 timeout / cancel 断言。 |
| `Tests/CooNetworkTests/AFClientUploadTests.swift` | 验证 upload 路径错误映射。 |
| `Tests/CooNetworkTests/AFUploadRequestTests.swift` | 验证 request 路径错误映射。 |
| `Tests/CooNetworkTests/NtkErrorBridgeTests.swift` | 新增或重写 bridge 测试。 |
| `Tests/CooNetworkTests/AFErrorMappingTests.swift` | 新增 AF 映射 / Toast 消费测试。 |
| `docs/design-decisions.md` | 更新被新 spec 替换的 `NtkError.AF` 决策。 |

---

## Execution Gates

### Gate A — 边界先锁死，再切错误模型
在删除旧五域前，必须先有 RED 测试覆盖以下边界：

- parsing 入口 response 形态错误 → `.invalidResponseType`
- prepare 缺主链上下文 → `.invalidRequest`
- executor / task manager 最终 typed response 交付失败 → `.invalidTypedResponse`
- request type 不受支持 → `.unsupportedRequestType`
- AF cancel / timeout 不得落到 `.clientFailed`

### Gate B — Task 2 是“错误模型切换闸门”
Task 2 不是普通骨架任务，而是全仓 public error shape 切换点。完成后必须满足：

- 仓库可编译
- 新错误模型成为唯一模型
- 五域旧壳已删除
- 允许测试仍失败，但失败只应集中在映射与语义层，不得再有旧类型缺失导致的编译错误

### Gate C — policy 先于 serialization 细节
在迁移 `NtkPayload*` 与 `NtkDynamicData` 前，必须先锁死：

- validation 优先于 serialization
- 空 body 不进入 validation
- `data == nil` 属于 serialization failure
- 无可用于校验的 `recoveredResponse` 时，decode failure 不得伪装成 validation failure

### Gate D — bridge 最后做
Objective-C bridge 只反映最终 Swift public error shape，不得反向约束 Swift 层设计。

---

## Search Sweep

实现前后只在以下范围清理旧模型残留：

- 生产代码：`Sources/**/*.swift`
- 测试代码：`Tests/**/*.swift`

不要把 `docs/` 纳入旧模型代码残留归零搜索范围；但若本次 spec 替换了设计决策记录，需在单独文档任务中同步更新 `docs/design-decisions.md`。

### 第一轮残留清理（Task 2 后，聚焦编译与主语义）

1. `RequestFailure`
2. `ResponseFailure`
3. `SerializationFailure`
4. `ValidationFailure`
5. `ClientFailure`
6. `NtkError\.client\(`
7. `NtkError\.response\(`
8. `NtkError\.serialization\(`
9. `NtkError\.validation\(`
10. `NtkError\.request\(`
11. `Failure\(reason:`

### 第二轮残留清理（最终验收前，全量归零）

1. `case request\(`
2. `case response\(`
3. `case serialization\(`
4. `case validation\(`
5. `case client\(`
6. `RequestFailure`
7. `ResponseFailure`
8. `SerializationFailure`
9. `ValidationFailure`
10. `ClientFailure`
11. `typeMismatch`
12. `transportError`
13. `NtkError\.client\(`
14. `NtkError\.response\(`
15. `NtkError\.serialization\(`
16. `NtkError\.validation\(`
17. `NtkError\.request\(`
18. `NtkError\.AF`
19. `Failure\(reason:`
20. `reason: \.serviceRejected`

---

## Task 1: 先锁顶层公共失败事件边界（RED）

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`
- Modify: `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`
- Modify: `Tests/CooNetworkTests/CooNetworkTests.swift`
- Modify: `Tests/CooNetworkTests/AFClientUploadTests.swift`
- Modify: `Tests/CooNetworkTests/AFUploadRequestTests.swift`
- Create: `Tests/CooNetworkTests/AFErrorMappingTests.swift`
- Modify: `Tests/CooNetworkTests/NtkErrorBridgeTests.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 1.1: 为 parsing 入口 response 形态错误写 RED 测试，锁死 `.invalidResponseType`**
- [ ] **Step 1.2: 为 prepare 缺主链上下文写 RED 测试，锁死 `.invalidRequest`**
- [ ] **Step 1.3: 为 executor / task manager 最终 typed response 失败写 RED 测试，锁死 `.invalidTypedResponse`**
- [ ] **Step 1.4: 为 AF cancel / timeout / generic error 写 RED 测试，锁死 cancel/timeout 优先归一化**
- [ ] **Step 1.5: 为 unsupported request type 写最小 RED 测试，锁死 `.unsupportedRequestType`**
- [ ] **Step 1.6: 运行边界相关测试确认失败**
- [ ] **Step 1.7: 提交 RED 测试 commit**

**Checkpoint:** Task 1 完成后，后续实现不得再自由解释 `invalidRequest` / `invalidResponseType` / `invalidTypedResponse` 的边界。

---

## Task 2: 审计 Sendable 约束并完成错误模型切换闸门（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
- Create: `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift`
- Create: `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift`
- Create: `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/error/NtkError+Request.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/error/NtkError+Response.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/error/NtkError+Serialization.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/error/NtkError+Validation.swift`
- Delete: `Sources/CooNetwork/NtkNetwork/error/NtkError+Client.swift`
- Modify: 直接引用旧五域类型、为保持编译而必须同步迁移的最小入口文件

- [ ] **Step 2.1: 先审计新错误关联值的 Sendable 可行性，并为每类关联值确定“直接保留 / 最小包装 / 降级存储”策略**
- [ ] **Step 2.2: 重写 `NtkError.swift` 顶层骨架，仅保留公共失败事件与 `Cache`**
- [ ] **Step 2.3: 创建 `NtkResponseSerializationError.swift`**
- [ ] **Step 2.4: 创建 `NtkResponseValidationError.swift`**
- [ ] **Step 2.5: 创建 `NtkClientError.swift`**
- [ ] **Step 2.6: 显式删除旧五域壳文件**
- [ ] **Step 2.7: 做最小编译迁移，确保仓库不进入不可编译中间态**
- [ ] **Step 2.8: 运行第一轮残留搜索，清理直接阻塞编译与主语义的旧模型引用**
- [ ] **Step 2.9: 运行聚焦测试，确认仓库已可编译、测试可运行但仍处于语义失败状态**
- [ ] **Step 2.10: 提交“错误模型切换完成且仓库可编译”的 commit**

**必须删除：**
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Request.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Response.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Serialization.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Validation.swift`
- `Sources/CooNetwork/NtkNetwork/error/NtkError+Client.swift`

**Checkpoint:** Task 2 结束后，新错误模型必须已经成为唯一模型；不得继续保留旧五域定义或双轨中间态。

---

## Task 3: 先迁移 parsing policy 与 `NtkInterpretation` 语义中心（GREEN）

**Files:**
- Review/Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkInterpretation.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 3.1: 为 policy 写 RED 测试，锁死 validation 优先级、空 body、decode failure、data missing 的新落点；其中必须单独锁死空 body → `.responseBodyEmpty`，且不进入 validation，也不落到 `responseSerializationFailed`**
- [ ] **Step 3.2: 运行 policy 测试确认失败**
- [ ] **Step 3.3: 显式处理 `NtkInterpretation` 的旧 `header` 语义，确保不泄漏到新的 public error shape**
- [ ] **Step 3.4: 把 `NtkDefaultResponseParsingPolicy` 改成新错误模型**
- [ ] **Step 3.5: 运行 policy / integration 相关测试确认通过**
- [ ] **Step 3.6: 提交 policy 语义迁移 commit**

**Checkpoint:** Task 3 完成后，validation 与 serialization 的优先级边界必须稳定，后续 serialization 子路径不得再改写这套优先级。

---

## Task 4: 迁移 serialization 子路径边界（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift`
- Test: `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`
- Test: `Tests/CooNetworkTests/NtkPayloadTransformerTests.swift`

- [ ] **Step 4.1: 为 `NtkDataParsingInterceptor.acquire` / `prepare` 边界写 RED 测试**
- [ ] **Step 4.2: 为 payload 入口与 decoder 输入形态写 RED 测试，锁死 `invalidJSON` / `invalidEnvelope` / `invalidDataPayload`**
- [ ] **Step 4.3: 为真正 decode fail / dataTypeMismatch 写 RED 测试，锁死 `envelopeDecodingFailed` / `dataDecodingFailed` / `dataTypeMismatch`**
- [ ] **Step 4.4: 运行 serialization 相关测试确认失败**
- [ ] **Step 4.5: 先修改 `NtkDataParsingInterceptor.swift`，稳定 `.invalidResponseType` / `.invalidRequest` 边界**
- [ ] **Step 4.6: 修改 `NtkPayload.swift`**
- [ ] **Step 4.7: 修改 `NtkPayloadDecoders.swift`**
- [ ] **Step 4.8: 修改 `NtkDynamicData.swift`**
- [ ] **Step 4.9: 运行相关测试确认通过**
- [ ] **Step 4.10: 提交 serialization 边界迁移 commit**

**至少锁死：**
- `NtkDataParsingInterceptor.acquire` 拿到非 `NtkClientResponse` → `.invalidResponseType`
- `NtkDataParsingInterceptor.prepare` 缺 `request` / `clientResponse` → `.invalidRequest`
- decoder 输入形态错误不得重新混成真正 decode failure

---

## Task 5: 迁移 executor / dedup / retry 到顶层公共失败事件（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift`
- Test: `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Test: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`
- Test: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`
- Test: `Tests/CooNetworkTests/CooNetworkTests.swift`

- [ ] **Step 5.1: 为 retry 矩阵写 RED 测试，覆盖 `requestTimeout` / `requestCancelled` / `invalidTypedResponse` / `responseSerializationFailed` / `clientFailed(.af(...))`**
- [ ] **Step 5.2: 运行 retry / executor / dedup 测试确认失败**
- [ ] **Step 5.3: 修改 `NtkNetworkExecutor.swift`，锁死最终 typed response 失败 → `.invalidTypedResponse`**
- [ ] **Step 5.4: 修改 `NtkTaskManager.swift`，锁死 cancel / timeout / typed response 的新顶层落点**
- [ ] **Step 5.5: 最后修改 `iNtkRetryPolicy.swift`，消费稳定后的新错误模型**
- [ ] **Step 5.6: 运行相关测试确认通过**
- [ ] **Step 5.7: 提交 executor / dedup / retry 迁移 commit**

**Checkpoint:** retry 必须建立在 executor / task manager 落点已经稳定之后，不得让 retry 反向塑造错误边界。

---

## Task 6: 迁移 Alamofire adapter 与 Toast 消费（GREEN）

**Files:**
- Modify: `Sources/AlamofireClient/Error/AFClientError.swift`
- Modify: `Sources/AlamofireClient/Client/AFClient.swift`
- Modify: `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift`
- Test: `Tests/CooNetworkTests/AFErrorMappingTests.swift`
- Test: `Tests/CooNetworkTests/AFClientUploadTests.swift`
- Test: `Tests/CooNetworkTests/AFUploadRequestTests.swift`

- [ ] **Step 6.1: 为 AF cancel/timeout 优先归一化写 RED 测试**
- [ ] **Step 6.2: 为 unsupported request type 与 generic AF error 写 RED 测试**
- [ ] **Step 6.3: 运行 AF 测试确认失败**
- [ ] **Step 6.4: 修改 `AFClientError.swift` 为纯映射辅助**
- [ ] **Step 6.5: 修改 `AFClient.swift`，锁死 cancel / timeout / unsupported request / generic AF error 的新落点**
- [ ] **Step 6.6: 修改 `AFToastInterceptor.swift`，改为消费新错误模型**
- [ ] **Step 6.7: 运行 AF 相关测试确认通过**
- [ ] **Step 6.8: 提交 AF 子空间迁移 commit**

**Expected:** PASS，且其中包含 unsupported request type 场景通过；cancel/timeout 不得回流进 `.clientFailed`。

---

## Task 7: 最后重写 Objective-C bridge 并同步设计决策记录（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError+OC.swift`
- Test: `Tests/CooNetworkTests/NtkErrorBridgeTests.swift`
- Modify: `docs/design-decisions.md`

- [ ] **Step 7.1: 为 bridge 写 RED 测试，覆盖新的 NSError code 段与 userInfo key**
- [ ] **Step 7.2: 运行 bridge 测试确认失败**
- [ ] **Step 7.3: 重写 `NtkError+OC.swift` code 段**
- [ ] **Step 7.4: 重写 `userInfo` 映射，统一使用 `request` / `clientResponse` / `recoveredResponse` / `response` / `underlyingError` / `rawPayload` / `message`**
- [ ] **Step 7.5: 更新 `docs/design-decisions.md` 中被替换的 `NtkError.AF` 决策**
- [ ] **Step 7.6: 运行 bridge 测试确认通过**
- [ ] **Step 7.7: 提交 bridge + decision record 迁移 commit**

**Checkpoint:** bridge 只能反映最终 Swift 设计，不得为了 bridge 兼容性回退到 request/response 五域 taxonomy。

---

## Task 8: 第二轮残留归零、跑全量测试、做人工验收（GREEN）

**Files:**
- Modify as needed: 全仓残留位置

- [ ] **Step 8.1: 分开搜索生产代码与测试代码的第二轮残留并清理**
- [ ] **Step 8.2: 运行第二轮残留归零检查，确认旧错误模型相关搜索全部为 0 matches**
- [ ] **Step 8.3: 跑全量 `swift test`**
- [ ] **Step 8.4: 按 spec 做人工复核，重点核对顶层事件判定表、validation 优先级、AF 映射优先级、bridge 术语**
- [ ] **Step 8.5: 仅在 Step 8.1–8.4 产生新修改时提交最终清理 commit**

**Run:**

```bash
rg "case request\(|case response\(|case serialization\(|case validation\(|case client\(|RequestFailure|ResponseFailure|SerializationFailure|ValidationFailure|ClientFailure|typeMismatch|transportError|NtkError\.client\(|NtkError\.response\(|NtkError\.serialization\(|NtkError\.validation\(|NtkError\.request\(|NtkError\.AF|Failure\(reason:|reason: \.serviceRejected" Sources && rg "RequestFailure|ResponseFailure|SerializationFailure|ValidationFailure|ClientFailure|typeMismatch|transportError|NtkError\.client\(|NtkError\.response\(|NtkError\.serialization\(|NtkError\.validation\(|NtkError\.request\(|NtkError\.AF|Failure\(reason:|reason: \.serviceRejected" Tests
```

**Expected:** 两条命令都返回 0 matches。

---

## Suggested Commit Sequence

1. `test: lock public error event boundaries`
2. `refactor: switch NtkError to event-based model`
3. `refactor: migrate parsing policy to new error model`
4. `refactor: migrate serialization error boundaries`
5. `refactor: migrate executor retry and task manager errors`
6. `refactor: migrate alamofire error adapter`
7. `refactor: update objc bridge for new error model`
8. `test: remove remaining legacy error references`

---

## Verification Checklist

- [ ] `NtkError` 顶层声明为 `Sendable`
- [ ] 新独立错误类型的 Sendable 风险已审计并落地最小方案
- [ ] `NtkError` 顶层只保留公共失败事件
- [ ] `NtkError.Cache` 仍独立存在
- [ ] `NtkResponseSerializationError` / `NtkResponseValidationError` / `NtkClientError` 已落地
- [ ] 五域旧壳文件已删除
- [ ] `Failure(reason: context:)` 模式已完全删除
- [ ] `typeMismatch` 已完全删除
- [ ] `transportError` 已不再作为公共顶层概念存在
- [ ] payload 输入形态错误与真正 decode 失败已分离
- [ ] acquire/prepare 边界已有测试锁定：非 `NtkClientResponse` → `.invalidResponseType`；缺主链上下文 → `.invalidRequest`
- [ ] `invalidRequest` / `invalidResponseType` / `invalidTypedResponse` 的边界符合 spec
- [ ] `unsupportedRequestType` 已有生产 / bridge / retry 闭环测试
- [ ] validation 优先级未变
- [ ] `responseValidationFailed(.serviceRejected(...))` 中的 `response` 保持为 validation 阶段业务响应对象，不与 `clientResponse` / `recoveredResponse` 混用
- [ ] `NtkInterpretation` 中旧 `header` 语义不会泄漏到新的 public error shape
- [ ] AF cancel / timeout 优先归一化，不会落到 `.clientFailed`
- [ ] `AFToastInterceptor` 能消费新错误模型
- [ ] Objective-C bridge 已改为新术语与新 code 段，并有测试覆盖
- [ ] `docs/design-decisions.md` 已同步更新
- [ ] 第一轮残留清理已完成
- [ ] 第二轮残留清理已完成
- [ ] 旧错误模型搜索结果全部归零
- [ ] `swift test` 全量通过

## Notes for Implementers

- 不要为了“统一”重新引入新的总壳 struct。
- 不要为了兼容旧 API 保留双轨错误模型。
- 不要把 `invalidRequest` 当成兜底垃圾桶。
- 不要把 decoder 输入形态错误重新混进 decode fail。
- 不要让 AF cancel/timeout 回流进 `.clientFailed`。
- 不要改动 cache 错误系统边界。
- 不要在 Task 2 之前删除旧五域定义。
- 不要在 Task 3 完成前调整 serialization 优先级判断。
- 不要让 retry 或 bridge 反向塑造 Swift public error shape。
- 任何 commit 都必须保持仓库可编译、可回退。
