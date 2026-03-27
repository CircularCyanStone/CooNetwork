# NtkError 域错误直抛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `NtkError` 重构为最小顶层错误 + 域错误直抛模型，删除 validation / serialization / client 包装 case，并同步迁移生产代码、消费点、测试与文档。

**Architecture:** `NtkError` 只保留跨域顶层错误，`Validation`、`Serialization`、`Client`、`Cache` 作为嵌套域错误直接抛出与捕获。实现顺序先固定错误类型定义，再迁移 throw 点与 catch 点，最后清理测试和文档，避免新旧模型长期并存。

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing, Alamofire

---

## File Map

### Core error model
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
  - 删除 `responseValidationFailed(reason:)` / `responseSerializationFailed(reason:)` / `clientFailed(reason:)`
  - 将嵌套类型命名从 `ValidationError` / `SerializationError` 改为 `Validation` / `Serialization`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift`
  - 将 `NtkError.ValidationError` 重命名为 `NtkError.Validation`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift`
  - 将 `NtkError.SerializationError` 重命名为 `NtkError.Serialization`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift`
  - 保持 `NtkError.Client` 直抛模型，不再依赖顶层包装 case
- Modify: `Sources/AlamofireClient/Error/AFClientError.swift`
  - 确保 AF 映射继续返回 `NtkError.Client`

### Throw sites
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Modify: `Sources/AlamofireClient/Client/AFClient.swift`

### Catch / policy sites
- Modify: `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift`
- Modify: `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift`
- Verify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
  - `NtkError.Cache.noCache` 已符合目标，仅确认不需要额外调整

### Tests
- Modify: `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift`
- Modify: `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`
- Modify: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`
- Modify: `Tests/CooNetworkTests/NtkPayloadTransformerTests.swift`
- Modify: `Tests/CooNetworkTests/AFErrorMappingTests.swift`
- Verify and update any remaining matches from repo-wide search for `responseValidationFailed(` / `responseSerializationFailed(` / `clientFailed(` / `ValidationError` / `SerializationError`

### Docs
- Modify: `docs/design-decisions.md`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift` doc comments
- Verify: `docs/superpowers/specs/2026-03-27-ntk-error-domain-direct-throw-design.md`

---

### Task 1: 固定错误类型命名与顶层模型

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift`
- Modify: `Sources/AlamofireClient/Error/AFClientError.swift`
- Test: `Tests/CooNetworkTests/AFErrorMappingTests.swift`

- [ ] **Step 1: 写失败测试，锁定新类型名和直抛边界**

```swift
@Test
func afErrorHelperStillReturnsClientDomainError() {
    let mapped = NtkError.Client.fromAFError(
        AFError.explicitlyCancelled,
        request: AFMappingRequest(),
        clientResponse: nil
    )

    if case let .external(reason, request, clientResponse, underlyingError, message) = mapped {
        #expect(request?.path == "/af/mapping")
        #expect(clientResponse == nil)
        #expect(underlyingError != nil)
        #expect(message != nil)
        #expect(reason is NtkError.Client.AF)
    } else {
        Issue.record("错误类型不符: \(mapped)")
    }
}
```

- [ ] **Step 2: 运行测试，确认在重命名前会失败或需联动修改**

Run: `swift test --filter AFErrorMappingTests`
Expected: 现状可通过，但后续重命名 `ValidationError` / `SerializationError` 后需要更新引用并重新通过。

- [ ] **Step 3: 修改错误类型定义，删除包装 case 并重命名嵌套类型**

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

```swift
public extension NtkError {
    enum Validation: Error, Sendable {
        case serviceRejected(
            request: any iNtkRequest,
            response: any iNtkResponse
        )
    }
}
```

```swift
public extension NtkError {
    enum Serialization: Error, Sendable {
        case invalidJSON(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?)
        case invalidEnvelope(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?)
        case invalidDataPayload(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?, recoveredResponse: NtkResponse<NtkDynamicData?>?)
        case dataDecodingFailed(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?, recoveredResponse: NtkResponse<NtkDynamicData?>?, rawPayload: NtkPayload?, underlyingError: Error?)
        case dataMissing(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?, recoveredResponse: NtkResponse<NtkDynamicData?>?)
        case dataTypeMismatch(request: (any iNtkRequest)?, clientResponse: NtkClientResponse?, recoveredResponse: NtkResponse<NtkDynamicData?>?, underlyingError: Error?)
    }
}
```

- [ ] **Step 4: 更新 AF error helper 到新命名体系**

```swift
public extension NtkError.Client {
    enum AF: Error, Sendable {
        case requestFailed
    }

    static func fromAFError(
        _ error: AFError,
        request: iNtkRequest?,
        clientResponse: NtkClientResponse? = nil
    ) -> NtkError.Client {
        .external(
            reason: AF.requestFailed,
            request: request,
            clientResponse: clientResponse,
            underlyingError: error,
            message: error.errorDescription ?? error.localizedDescription
        )
    }
}
```

- [ ] **Step 5: 运行错误模型相关测试，确认类型层完成收敛**

Run: `swift test --filter AFErrorMappingTests`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add Sources/CooNetwork/NtkNetwork/error/NtkError.swift Sources/CooNetwork/NtkNetwork/error/NtkResponseValidationError.swift Sources/CooNetwork/NtkNetwork/error/NtkResponseSerializationError.swift Sources/CooNetwork/NtkNetwork/error/NtkClientError.swift Sources/AlamofireClient/Error/AFClientError.swift Tests/CooNetworkTests/AFErrorMappingTests.swift
git commit -m "refactor: remove ntk error wrapper cases"
```

### Task 2: 迁移 parsing 与 dynamic data 的直抛错误

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Test: `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift`
- Test: `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`
- Test: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 1: 先把 payload / policy / dynamic data 相关测试改成新错误类型断言**

```swift
@Test
func dynamicDataDecodeFailureThrowsStructuredDataDecodeFailed() throws {
    do {
        _ = try NtkDynamicData(from: PayloadTestFailingDecoder())
        Issue.record("期望抛出 serialization.dataDecodingFailed")
    } catch let error as NtkError.Serialization {
        if case let .dataDecodingFailed(request: _, clientResponse: _, recoveredResponse: recoveredResponse, rawPayload: _, underlyingError: underlyingError) = error {
            #expect(recoveredResponse == nil)
            if let decodingError = underlyingError as? DecodingError,
               case .typeMismatch = decodingError {
                #expect(Bool(true))
            } else {
                Issue.record("underlyingError 类型不符: \(String(describing: underlyingError))")
            }
        } else {
            Issue.record("错误类型不符: \(error)")
        }
    }
}
```

```swift
@Test
@NtkActor
func decodedResultWithNilDataAndValidationPassThrowsDataMissing() async throws {
    let hook = PolicyTestRecordingHook()
    let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
        validation: PolicyTestPassValidation(),
        dispatcher: NtkParsingHookDispatcher(hooks: [hook])
    )

    do {
        _ = try await policy.decide(
            from: .decoded(
                .init(
                    code: NtkReturnCode(0),
                    msg: "ok",
                    data: nil,
                    request: PolicyTestRequest(),
                    clientResponse: makePolicyClientResponse(),
                    isCache: false
                )
            ),
            context: makePolicyContext()
        )
        Issue.record("期望抛出 serialization.dataMissing")
    } catch let error as NtkError.Serialization {
        if case .dataMissing = error {
            #expect(hook.events == ["willValidate"])
        } else {
            Issue.record("错误类型不符: \(error)")
        }
    }
}
```

- [ ] **Step 2: 运行这些测试，确认会因旧包装模型而失败**

Run: `swift test --filter "(NtkPayloadNormalizationTests|NtkPayloadDecoderTests|NtkDefaultResponseParsingPolicyTests|NtkDataParsingInterceptorTests)"`
Expected: FAIL，报错集中在仍然抛 `NtkError.responseSerializationFailed(...)` / `responseValidationFailed(...)` 或仍按 `NtkError` 顶层捕获。

- [ ] **Step 3: 将 payload / decoder / policy / dynamic data 的 throw 点改成域错误直抛**

```swift
throw NtkError.Serialization.invalidJSON(
    request: nil,
    clientResponse: nil
)
```

```swift
throw NtkError.Serialization.invalidEnvelope(
    request: nil,
    clientResponse: nil
)
```

```swift
throw NtkError.Serialization.invalidDataPayload(
    request: nil,
    clientResponse: nil,
    recoveredResponse: nil
)
```

```swift
throw NtkError.Serialization.dataMissing(
    request: decoded.request,
    clientResponse: decoded.clientResponse,
    recoveredResponse: nil
)
```

```swift
throw NtkError.Validation.serviceRejected(
    request: request,
    response: response
)
```

```swift
throw NtkError.Serialization.dataTypeMismatch(
    request: nil,
    clientResponse: nil,
    recoveredResponse: nil,
    underlyingError: nil
)
```

- [ ] **Step 4: 将注释同步改为新命名，避免文档继续描述包装 case**

```swift
/// - Throws: 当原始值既不是 `Data`，也不是允许进入 pipeline 的顶层结构时抛出 `NtkError.Serialization.invalidJSON(...)`。
```

- [ ] **Step 5: 重新运行 parsing 与 dynamic data 测试，确认新错误边界工作正常**

Run: `swift test --filter "(NtkPayloadNormalizationTests|NtkPayloadDecoderTests|NtkDefaultResponseParsingPolicyTests|NtkDataParsingInterceptorTests)"`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing/NtkPayload.swift Sources/CooNetwork/NtkNetwork/parsing/NtkPayloadDecoders.swift Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift Tests/CooNetworkTests/NtkPayloadDecoderTests.swift Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "refactor: throw ntk domain parsing errors directly"
```

### Task 3: 迁移 AF client 与错误消费点

**Files:**
- Modify: `Sources/AlamofireClient/Client/AFClient.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift`
- Modify: `Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift`
- Test: `Tests/CooNetworkTests/AFErrorMappingTests.swift`
- Test: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`

- [ ] **Step 1: 写/改失败测试，锁定 client 直抛与消费逻辑**

```swift
@Test
@NtkActor
func testDedupFollowerCancelReceivesRequestCancelledNotNetworkError() async throws {
    let gate = TaskExecutionGate()
    var ownerRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type"))
    ownerRequest.responseType = "String"

    var followerRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type"))
    followerRequest.responseType = "String"
    followerRequest.isCancelledRef = NtkCancellableState()

    let ownerTask = Task {
        do {
            let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: ownerRequest) {
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                throw NtkError.Serialization.dataMissing(
                    request: nil,
                    clientResponse: nil,
                    recoveredResponse: nil
                )
            }
            return Result<String, Error>.success(value)
        } catch {
            return Result<String, Error>.failure(error)
        }
    }

    await gate.waitUntilFirstStarted()

    let followerTask = Task {
        do {
            let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: followerRequest) {
                return "should-not-run"
            }
            return Result<String, Error>.success(value)
        } catch {
            return Result<String, Error>.failure(error)
        }
    }

    try await Task.sleep(nanoseconds: 50_000_000)
    followerRequest.isCancelledRef?.cancel()
    NtkTaskManager.shared.cancelRequest(request: followerRequest)
    await gate.releaseFirst()

    let ownerResult = await ownerTask.value
    let followerResult = await followerTask.value

    if case .failure(let error) = ownerResult {
        if let serialization = error as? NtkError.Serialization,
           case .dataMissing = serialization {
            #expect(Bool(true))
        } else {
            Issue.record("owner 应该收到 serialization.dataMissing，实际收到: \(error)")
        }
    } else {
        Issue.record("owner 应该收到错误")
    }

    if case .failure(let error) = followerResult {
        if let ntkError = error as? NtkError,
           case .requestCancelled = ntkError {
            #expect(Bool(true))
        } else {
            Issue.record("被取消的 follower 应该收到 requestCancelled，实际收到: \(error)")
        }
    } else {
        Issue.record("被取消的 follower 应该收到错误")
    }
}
```

- [ ] **Step 2: 运行受影响测试，确认旧消费逻辑会失败或需要调整**

Run: `swift test --filter "(AFErrorMappingTests|NtkTaskManagerTests)"`
Expected: FAIL 或编译失败，主要因为 `clientFailed` / `responseSerializationFailed` 已删除。

- [ ] **Step 3: 将 AFClient 改为直接抛 `NtkError.Client`**

```swift
if let urlError = error.underlyingError as? URLError {
    if urlError.code == .cancelled {
        throw NtkError.requestCancelled
    }
    if urlError.code == .timedOut {
        throw NtkError.requestTimeout
    }
    throw NtkError.Client.external(
        reason: NtkError.Client.AF.requestFailed,
        request: ntkRequest,
        clientResponse: nil,
        underlyingError: urlError,
        message: urlError.localizedDescription
    )
}
```

```swift
throw NtkError.Client.external(
    reason: NtkError.Client.AF.requestFailed,
    request: ntkRequest,
    clientResponse: NtkClientResponse(
        data: response.data,
        msg: nil,
        response: fixResponse,
        request: ntkRequest,
        isCache: false
    ),
    underlyingError: error,
    message: error.errorDescription ?? error.localizedDescription
)
```

- [ ] **Step 4: 将 retry 与 toast 改为直接消费域错误类型**

```swift
public func shouldRetry(attemptCount: Int, error: Error) -> Bool {
    guard attemptCount <= maxRetryCount else { return false }

    if let ntkError = error as? NtkError {
        switch ntkError {
        case .invalidRequest,
             .unsupportedRequestType,
             .invalidResponseType,
             .invalidTypedResponse,
             .responseBodyEmpty,
             .requestCancelled:
            return false
        case .requestTimeout:
            return true
        }
    }

    if error is NtkError.Validation || error is NtkError.Serialization || error is NtkError.Cache {
        return false
    }

    if let clientError = error as? NtkError.Client {
        switch clientError {
        case let .external(_, _, _, underlyingError, _):
            if let urlError = underlyingError as? URLError {
                return shouldRetryForURLError(urlError)
            }
            return false
        }
    }

    if let urlError = error as? URLError {
        return shouldRetryForURLError(urlError)
    }

    return false
}
```

```swift
public func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
    guard let afRequest = context.mutableRequest.originalRequest as? iAFRequest else {
        return try await next.handle(context: context)
    }
    do {
        return try await next.handle(context: context)
    } catch let error as NtkError.Validation {
        handleValidationError(error, request: afRequest)
        throw error
    } catch let error as NtkError {
        handleTopLevelError(error)
        throw error
    } catch let error as NtkError.Client {
        handleClientError(error)
        throw error
    } catch {
        throw error
    }
}
```

```swift
private func handleValidationError(_ error: NtkError.Validation, request: iAFRequest) {
    if case let .serviceRejected(_, response) = error {
        if ignoreCode.contains(response.code.intValue) {
            return
        }
        if request.toastRetErrorMsg(response.code.stringValue), let msg = response.msg {
            toastHandler(msg)
        }
    }
}

private func handleTopLevelError(_ error: NtkError) {
    if case .requestTimeout = error {
        toastHandler("连接超时~")
    }
}
```

- [ ] **Step 5: 运行 client / retry / task manager 相关测试，确认消费层已完成迁移**

Run: `swift test --filter "(AFErrorMappingTests|NtkTaskManagerTests)"`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add Sources/AlamofireClient/Client/AFClient.swift Sources/CooNetwork/NtkNetwork/retry/iNtkRetryPolicy.swift Sources/AlamofireClient/Interceptor/AFToastInterceptor.swift Tests/CooNetworkTests/AFErrorMappingTests.swift Tests/CooNetworkTests/NtkTaskManagerTests.swift
git commit -m "refactor: consume ntk domain errors directly"
```

### Task 4: 清理剩余测试与设计文档口径

**Files:**
- Modify: `Tests/CooNetworkTests/NtkPayloadTransformerTests.swift`
- Modify: repo-wide remaining test files from search results
- Modify: `docs/design-decisions.md`
- Verify: `docs/superpowers/specs/2026-03-27-ntk-error-domain-direct-throw-design.md`

- [ ] **Step 1: 根据全局搜索把剩余测试全部改成新模型断言**

```swift
@Test
func transformerFailureBubblesAsSerializationDomainError() throws {
    #expect(throws: NtkError.Serialization.self) {
        _ = try failingTransformer.transform(payload)
    }
}
```

对所有仍然出现以下模式的测试统一迁移：

```swift
catch let error as NtkError {
    if case let .responseSerializationFailed(reason) = error {
        ...
    }
}
```

改为：

```swift
catch let error as NtkError.Serialization {
    ...
}
```

- [ ] **Step 2: 运行全局搜索，确认旧包装符号已清空**

Run: `python - <<'PY'
from pathlib import Path
patterns = ["responseValidationFailed(", "responseSerializationFailed(", "clientFailed(", "ValidationError", "SerializationError"]
root = Path(".")
for pattern in patterns:
    hits = [str(p) for p in root.rglob("*.swift") if pattern in p.read_text()]
    print(pattern, len(hits))
    for hit in hits[:20]:
        print("  ", hit)
PY`
Expected: 与本次保留语义无关的旧包装引用为 0；若仍有 `ValidationError` / `SerializationError`，应只出现在已决定保留的历史 spec 中，不应出现在源码或测试源码。

- [ ] **Step 3: 更新设计决策文档到新口径**

```markdown
- **NtkError 使用最小顶层 + 域错误直抛模型** — `NtkError` 只保留跨域公共错误；`NtkError.Validation`、`NtkError.Serialization`、`NtkError.Client`、`NtkError.Cache` 作为正式域错误类型直接抛出与捕获，避免 `responseValidationFailed(reason:)` / `responseSerializationFailed(reason:)` / `clientFailed(reason:)` 这类无信息增量的包装 case。
```

- [ ] **Step 4: 运行全量测试，确认整个仓库已经完全收敛到新模型**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: 提交本任务**

```bash
git add Tests/CooNetworkTests/NtkPayloadTransformerTests.swift Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift Tests/CooNetworkTests/NtkPayloadDecoderTests.swift Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift Tests/CooNetworkTests/NtkTaskManagerTests.swift docs/design-decisions.md
git commit -m "test: update ntk error assertions for domain throws"
```

---

## Self-Review

### Spec coverage
- 最小顶层 `NtkError`：Task 1
- `Validation` / `Serialization` / `Client` / `Cache` 直抛：Task 1-3
- 删除包装 case：Task 1
- throw 点迁移：Task 2-3
- catch 点迁移：Task 3-4
- 测试围绕真实错误类型断言：Task 2-4
- 文档口径同步：Task 2、Task 4

### Placeholder scan
- 未使用 TBD / TODO / “类似 Task N” 等占位描述
- 每个代码步骤都给了具体代码片段
- 每个验证步骤都给了具体命令与期望结果

### Type consistency
- 全计划统一使用 `NtkError.Validation`
- 全计划统一使用 `NtkError.Serialization`
- 全计划统一使用 `NtkError.Client`
- 顶层错误统一保持 `NtkError.invalidRequest` / `requestTimeout` 等最小集合
