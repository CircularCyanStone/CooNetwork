# Data Parsing Pipeline Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the second-stage parsing refactor by turning hooks into true observer-only notifications, centralizing notification dispatch, and making `NtkDataParsingInterceptor` read as an explicit orchestrator for the main parsing stages without reopening the policy/public-API design.

**Architecture:** Keep the Phase 1 foundation (`NtkParsingResult` + `NtkDefaultResponseParsingPolicy`) intact. Add a single internal `NtkParsingHookDispatcher` that owns all hook fan-out and swallow/log behavior, then refactor parser/policy to depend on it instead of ad-hoc hook loops and closure callbacks. In this Phase 2, the top-level parser should explicitly present the four main execution stages — Acquire / Prepare / Interpret / Decide — while Notify is treated as a cross-cutting observer-dispatch mechanism invoked at well-defined milestones rather than as a separate top-level sequential stage. This plan intentionally keeps the current architecture where policy may trigger observer-only notifications at decision boundaries; it does not attempt to restore the stricter original design rule that policy must be completely notification-free.

**Tech Stack:** Swift 6.1 / Swift Package Manager, `@NtkActor`, Swift Testing (`import Testing`), existing `CooNetwork` parsing module

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift` | Refactor `intercept` into explicit stage helpers and replace direct hook iteration / policy callback wiring with a dispatcher dependency. |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift` | Replace three callback properties with a single hook dispatcher/notifier dependency; keep current decision semantics intact while routing validation/completion notifications through dispatcher. |
| `Sources/CooNetwork/NtkNetwork/parsing/iNtkParsingHooks.swift` | Update contract/comments to match final Phase 2 observer semantics: hooks are read-only notifications and hook errors do not affect outcome. |
| `Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md` | Sync parsing submodule description with the new dispatcher role and observer-only hooks semantics. |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | Add hook-failure regression tests and stage-structure regression tests around real parser behavior. |
| `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` | Add at least one real parser cache-path test proving hook errors do not change cache parse result. |
| `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift` | Add at least one real parser network-path test proving hook errors do not change final parsed result. |

### Recommended new file

- `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift`

This file should stay `internal` and focused on one job: fan out read-only parsing notifications to injected hooks, log failures, and never let hook exceptions rewrite business outcome.

---

## Reality Checks From Current Code

These constraints come from the current implementation and should be preserved unless a step below explicitly changes them:

1. **Decision ownership is already centralized and should stay there.**
   - Parser produces `NtkParsingResult` and delegates to policy: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift:112-142`
   - Policy owns `NtkNever`, `nil data`, validation-failure, and decode-invalid decisions: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift:23-82`

2. **Hook notifications are currently split across parser and policy.**
   - `didDecodeHeader`: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift:104-110`
   - `willValidate` / `didValidateFail` / `didComplete`: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift:85-96`

3. **Current hook contract is only half-tightened.**
   - Docs say hooks are observers, but thrown hook errors still abort the main flow: `Sources/CooNetwork/NtkNetwork/parsing/iNtkParsingHooks.swift:25-29`
   - Phase 2 intentionally changes this behavior.

4. **Tests already lock several important hook timing semantics.**
   - `didComplete` only on success: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift:236-250`
   - `didValidateFail` only on validation failure: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift:252-269`
   - transform failure stops before decode/hooks: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift:217-234`

5. **Phase 2 does not reopen public API expansion.**
   - No `iNtkResponseParsingPolicy`
   - No `ParsingOutcome`
   - No success/failure dual-policy split

6. **Current payload root gate remains a separate parsing type.**
   - `PayloadRootGate.swift` exists at `Sources/CooNetwork/NtkNetwork/parsing/PayloadRootGate.swift`
   - `NtkPayload.swift` continues to use it as the payload entry structure check

7. **Phase 2 intentionally accepts the current policy-notification compromise.**
   - The original design doc argued that policy should not call hooks.
   - This plan does **not** attempt to restore that stricter boundary.
   - Instead, it keeps the current practical architecture: policy may trigger observer-only notifications at decision boundaries, but hook dispatch must remain read-only and must not affect business outcome.

---

## Task 1: Lock the New Hook Observer Contract With Failing Tests First

**Files:**
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 1.1: Add a throwing hook test double to parser tests**

Append helpers near existing test doubles in `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`:

```swift
private enum AFHookThrowPoint: Sendable {
    case didDecodeHeader
    case willValidate
    case didValidateFail
    case didComplete
}

private struct AFHookObserverError: Error, Equatable {
    let point: AFHookThrowPoint
}

private final class AFThrowingHook: iNtkParsingHooks, @unchecked Sendable {
    let throwPoint: AFHookThrowPoint
    var events: [String] = []

    init(throwPoint: AFHookThrowPoint) {
        self.throwPoint = throwPoint
    }

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {
        events.append("didDecodeHeader")
        if throwPoint == .didDecodeHeader { throw AFHookObserverError(point: .didDecodeHeader) }
    }

    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("willValidate")
        if throwPoint == .willValidate { throw AFHookObserverError(point: .willValidate) }
    }

    func didValidateFail(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didValidateFail")
        if throwPoint == .didValidateFail { throw AFHookObserverError(point: .didValidateFail) }
    }

    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didComplete")
        if throwPoint == .didComplete { throw AFHookObserverError(point: .didComplete) }
    }
}
```

- [ ] **Step 1.2: Add failing test for `didDecodeHeader` observer error not aborting success path**

Append:

```swift
@Test
@NtkActor
func didDecodeHeaderHookErrorDoesNotAbortSuccessfulParse() async throws {
    let hook = AFThrowingHook(throwPoint: .didDecodeHeader)
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestPassValidation(),
        hooks: [hook]
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": ["id": 1, "name": "ok"],
        "retMsg": "ok"
    ])

    let result = try await interceptor.intercept(context: makeAFContext(), next: AFTestDataHandler(data: data, request: AFTestRequest()))
    let typed = try #require(result as? NtkResponse<AFTestModel>)
    #expect(typed.data.id == 1)
    #expect(hook.events.contains("didDecodeHeader"))
}
```

Expected today: FAIL because hook error is still propagated.

- [ ] **Step 1.3: Add failing test for `willValidate` observer error not replacing outcome**

Append:

```swift
@Test
@NtkActor
func willValidateHookErrorDoesNotAbortSuccessfulParse() async throws {
    let hook = AFThrowingHook(throwPoint: .willValidate)
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestPassValidation(),
        hooks: [hook]
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": ["id": 1, "name": "ok"],
        "retMsg": "ok"
    ])

    let result = try await interceptor.intercept(context: makeAFContext(), next: AFTestDataHandler(data: data, request: AFTestRequest()))
    let typed = try #require(result as? NtkResponse<AFTestModel>)
    #expect(typed.data.name == "ok")
    #expect(hook.events.contains("willValidate"))
}
```

Expected today: FAIL.

- [ ] **Step 1.4: Add failing test for `didValidateFail` observer error preserving validation failure**

Append:

```swift
@Test
@NtkActor
func didValidateFailHookErrorDoesNotReplaceValidationError() async throws {
    let hook = AFThrowingHook(throwPoint: .didValidateFail)
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestFailValidation(),
        hooks: [hook]
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 999,
        "retMsg": "fail"
    ])

    do {
        _ = try await interceptor.intercept(context: makeAFContext(), next: AFTestDataHandler(data: data, request: AFTestRequest()))
        Issue.record("期望抛出 validation 错误")
    } catch let error as NtkError {
        if case .validation = error {
            #expect(hook.events.contains("didValidateFail"))
        } else {
            Issue.record("错误类型不符: \(error)")
        }
    }
}
```

Expected today: FAIL because hook error wins.

- [ ] **Step 1.5: Add failing test for `didComplete` observer error not breaking final success**

Append:

```swift
@Test
@NtkActor
func didCompleteHookErrorDoesNotReplaceSuccessfulResult() async throws {
    let hook = AFThrowingHook(throwPoint: .didComplete)
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestPassValidation(),
        hooks: [hook]
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": ["id": 1, "name": "ok"],
        "retMsg": "ok"
    ])

    let result = try await interceptor.intercept(context: makeAFContext(), next: AFTestDataHandler(data: data, request: AFTestRequest()))
    let typed = try #require(result as? NtkResponse<AFTestModel>)
    #expect(typed.code.intValue == 0)
    #expect(hook.events.contains("didComplete"))
}
```

Expected today: FAIL.

- [ ] **Step 1.6: Add failing test for one throwing hook not blocking later hooks**

Append:

```swift
@Test
@NtkActor
func throwingHookDoesNotBlockLaterHooksOnSameNotification() async throws {
    let throwingHook = AFThrowingHook(throwPoint: .didComplete)
    let recordingHook = AFTestRecordingHook()
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestPassValidation(),
        hooks: [throwingHook, recordingHook]
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": ["id": 1, "name": "ok"],
        "retMsg": "ok"
    ])

    _ = try await interceptor.intercept(context: makeAFContext(), next: AFTestDataHandler(data: data, request: AFTestRequest()))

    #expect(throwingHook.events.contains("didComplete"))
    #expect(recordingHook.events.contains("didComplete"))
}
```

Expected today: FAIL because iteration stops on the first thrown error.

- [ ] **Step 1.7: Run parser tests to confirm the new observer-contract tests fail first**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: FAIL only on the new hook-error tests; existing parser semantics remain unchanged.

- [ ] **Step 1.8: Commit the red test baseline**

```bash
git add Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "test: lock parsing hook observer contract"
```

---

## Task 2: Introduce a Single Internal Hook Dispatcher

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`

- [ ] **Step 2.1: Create the dispatcher type with one responsibility**

Create `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift` directly in its final intended shape. Do **not** intentionally land an intermediate whole-loop `do/catch` design just to demonstrate why it fails. The dispatcher must isolate each hook invocation independently from the start so one throwing hook cannot prevent later hooks from running.

Create `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift`:

```swift
import Foundation

struct NtkParsingHookDispatcher {
    private let hooks: [any iNtkParsingHooks]

    init(hooks: [any iNtkParsingHooks]) {
        self.hooks = hooks
    }

    @NtkActor
    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkInterceptorContext
    ) async {
        await notify("didDecodeHeader") {
            for hook in hooks {
                try await hook.didDecodeHeader(retCode: retCode, msg: msg, context: context)
            }
        }
    }

    @NtkActor
    func willValidate(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("willValidate") {
            for hook in hooks {
                try await hook.willValidate(response, context: context)
            }
        }
    }

    @NtkActor
    func didValidateFail(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didValidateFail") {
            for hook in hooks {
                try await hook.didValidateFail(response, context: context)
            }
        }
    }

    @NtkActor
    func didComplete(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didComplete") {
            for hook in hooks {
                try await hook.didComplete(response, context: context)
            }
        }
    }

    @NtkActor
    private func notify(
        _ event: String,
        action: () async throws -> Void
    ) async {
        do {
            try await action()
        } catch {
            logger.error("Parsing hook \(event) failed: \(error)", category: .network)
        }
    }
}
```

Then refine it so **each hook invocation is isolated**, not just the whole loop. The final implementation should log and continue per hook.

- [ ] **Step 2.2: Implement per-hook isolation immediately**

Update `NtkParsingHookDispatcher.swift` so each hook call is protected separately. The final structure should behave like:

```swift
@NtkActor
private func forEachHook(
    event: String,
    _ body: (any iNtkParsingHooks) async throws -> Void
) async {
    for hook in hooks {
        do {
            try await body(hook)
        } catch {
            logger.error("Parsing hook \(event) failed: \(error)", category: .network)
        }
    }
}
```

Then route each public notification method through `forEachHook`.

- [ ] **Step 2.3: Replace parser-owned direct hook iteration with dispatcher usage**

In `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`:

1. Replace `private let hooks` with `private let hookDispatcher`
2. Construct `NtkParsingHookDispatcher(hooks: hooks)` in both initializers
3. Remove direct `for hook in hooks` loop in `intercept`
4. Call `await hookDispatcher.didDecodeHeader(...)` instead

- [ ] **Step 2.4: Replace policy callback wiring with dispatcher dependency**

In `Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift`:

1. Replace `notifyWillValidate` / `notifyDidValidateFail` / `notifyDidComplete` properties with a single dispatcher dependency
2. Update `validate(...)` to call:
   - `await hookDispatcher.willValidate(...)`
   - `await hookDispatcher.didValidateFail(...)`
3. Update success paths to call `await hookDispatcher.didComplete(...)`
4. Keep all existing decision semantics exactly the same

- [ ] **Step 2.5: Run parser tests to confirm hook observer contract now passes**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS, including all new hook-error tests.

- [ ] **Step 2.6: Commit dispatcher introduction**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift \
        Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift \
        Sources/CooNetwork/NtkNetwork/parsing/NtkDefaultResponseParsingPolicy.swift \
        Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "refactor: centralize parsing hook dispatch"
```

---

## Task 3: Make the Parser Read as an Explicit Five-Stage Orchestrator

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 3.1: Extract the acquire stage helper**

In `NtkDataParsingInterceptor.swift`, add a focused helper such as:

```swift
private func acquireClientResponse(
    context: NtkInterceptorContext,
    next: iNtkRequestHandler
) async throws -> NtkClientResponse {
    let response = try await next.handle(context: context)

    if let ntkResponse = response as? NtkResponse<ResponseData> {
        throw NtkEarlyParsedResponse(response: ntkResponse)
    }

    guard let clientResponse = response as? NtkClientResponse else {
        throw NtkError.typeMismatch
    }
    return clientResponse
}
```

Typed passthrough must remain an Acquire-stage early return and must not enter Prepare / Interpret / Decide / Notify notifications. If you dislike a sentinel error for typed passthrough, use a small internal enum/result helper instead. The goal is explicit acquire-stage structure, not cleverness.

- [ ] **Step 3.2: Extract the prepare stage helper**

Use a helper such as:

```swift
private func preparePayload(
    from clientResponse: NtkClientResponse,
    context: NtkInterceptorContext
) async throws -> NtkPayload {
    let normalizedPayload = try NtkPayload.normalize(from: clientResponse.data)
    return try await transform(normalizedPayload, context: context)
}
```

- [ ] **Step 3.3: Extract the interpret stage helper**

Use a helper that returns `NtkParsingResult<ResponseData>` and is solely responsible for:

- decode success logging
- `didDecodeHeader` notification through dispatcher
- `headerRecovered` fallback
- `unrecoverableDecodeFailure`

For example:

```swift
private func interpret(
    payload: NtkPayload,
    clientResponse: NtkClientResponse,
    request: iNtkRequest,
    context: NtkInterceptorContext
) async -> NtkParsingResult<ResponseData>
```

This helper should not decide final success/failure.

- [ ] **Step 3.4: Keep decide stage as a thin explicit wrapper**

Add a helper such as:

```swift
private func decide(
    from result: NtkParsingResult<ResponseData>,
    context: NtkInterceptorContext
) async throws -> any iNtkResponse {
    try await policy.decide(from: result, context: context)
}
```

This may look small, but it makes the stage boundary visible in `intercept(...)`.

- [ ] **Step 3.5: Refactor `intercept(...)` to read like the five-stage flow without adding ceremony**

The final top-level function should read roughly like:

```swift
public func intercept(
    context: NtkInterceptorContext,
    next: iNtkRequestHandler
) async throws -> any iNtkResponse {
    let clientResponse = try await acquire...
    let payload = try await prepare...
    let parsingResult = await interpret...
    return try await decide(from: parsingResult, context: context)
}
```

Typed passthrough can remain as an early-return path, but it must stay fully inside Acquire and must not trigger any parsing hook notifications. The happy-path structure must visibly reflect Acquire / Prepare / Interpret / Decide. Notify remains explicit as a cross-cutting dispatcher mechanism invoked at stage milestones rather than as a separate top-level sequential block.

- [ ] **Step 3.6: Add one regression test proving transform failures still stop before interpret notifications**

If the existing `transformErrorStopsBeforeDecodeAndHooks` test still covers this after the refactor, keep it. If not, strengthen it so it explicitly guards the new stage structure.

- [ ] **Step 3.7: Run parser tests after the structural refactor**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS with no behavior changes beyond the Phase 2 hook contract.

- [ ] **Step 3.8: Commit five-stage explicit orchestration**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift \
        Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "refactor: make parsing interceptor stages explicit"
```

---

## Task 4: Update Hook Contract Documentation to Match the New Runtime Behavior

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/iNtkParsingHooks.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md`

- [ ] **Step 4.1: Rewrite `iNtkParsingHooks` comments to the final observer contract**

Update `Sources/CooNetwork/NtkNetwork/parsing/iNtkParsingHooks.swift` so the docs clearly state:

- hooks are read-only parsing lifecycle notifications
- hooks do not participate in parsing policy decisions
- hook failures are logged/observed but do not change final outcome
- if future logic must be outcome-affecting, it should not live in hooks

The top-level comment should end up closer to:

```swift
/// 响应解析拦截器的只读生命周期通知协议。
///
/// 用于在 `NtkDataParsingInterceptor` 的关键里程碑执行旁路副作用，
/// 如日志、埋点、持久化、广播等。hooks 不参与业务裁决，
/// 且 hook 自身错误不会改变主流程的最终 outcome。
```

- [ ] **Step 4.2: Update per-method comments to remove transitional wording**

Specifically remove wording equivalent to:
- “当前实现中抛错会继续传播”
- any hint that callers should rely on thrown hook errors for control flow

- [ ] **Step 4.3: Sync parsing module docs**

Update `Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md` so the module description reflects:

- `iNtkParsingHooks` = observer-only notifications
- `NtkParsingHookDispatcher` = centralized notification fan-out
- parser = orchestrator, policy = decision center

- [ ] **Step 4.4: Run a focused test subset after doc-only updates**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS (sanity check that doc edits didn’t accidentally drift code in nearby files).

- [ ] **Step 4.5: Commit contract documentation updates**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing/iNtkParsingHooks.swift \
        Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md
git commit -m "docs: finalize parsing hook observer contract"
```

---

## Task 5: Verify Observer Semantics Through Real Cache and Integration Paths

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 5.1: Add a throwing hook type for executor/integration tests**

Create small local test doubles in each file (or a shared helper if there is already a test-helper pattern) that implement `iNtkParsingHooks` and throw from one callback.

A minimal example:

```swift
private struct ExecThrowingHook: iNtkParsingHooks {
    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        struct ExecHookError: Error {}
        throw ExecHookError()
    }
}
```

- [ ] **Step 5.2: Add a cache-path regression proving hook errors do not change parsed cache result**

Append to `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`:

```swift
@Test
@NtkActor
func loadCacheWithRealParserIgnoresHookObserverErrors() async throws {
    let storage = ExecMockCacheStorage(
        cacheData: try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ]),
        hasCacheResult: false
    )

    var request = NtkMutableRequest(ExecDummyRequest())
    request.responseType = String(describing: Bool.self)

    let parser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(
        validation: ExecDummyValidation(),
        hooks: [ExecThrowingHook()]
    )
    let executor = NtkNetworkExecutor<Bool>(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [NtkResponseParserBox(parser), NtkCacheInterceptor(storage: storage)]
    ))

    let response = try await executor.loadCache()
    #expect(response?.data == true)
    #expect(response?.isCache == true)
}
```

- [ ] **Step 5.3: Add a network-path regression proving hook errors do not change final parsed response**

Append to `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`:

```swift
@Test
func requestWithRealParserIgnoresHookObserverErrors() async throws {
    let client = IntegJSONClient(data: try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": true,
        "retMsg": "ok"
    ]))

    let network = NtkNetwork<Bool>.with(
        client,
        request: IntegDummyRequest(path: "/integration/hook-observer"),
        responseParser: NtkDataParsingInterceptor<Bool, IntegTestKeys>(
            validation: IntegDummyValidation(),
            hooks: [IntegThrowingHook()]
        )
    )

    let response = try await network.request()
    #expect(response.data == true)
}
```

- [ ] **Step 5.4: Add one validation-failure regression ensuring hook errors do not replace `.validation` on real parser path**

Prefer adding this in `AFDataParsingInterceptorTests.swift` if it is easier to inspect the exact error shape there. If executor/integration coverage makes it clearer, add it there instead — but ensure this scenario is explicitly covered somewhere outside the dispatcher-only unit boundary.

- [ ] **Step 5.5: Run executor and integration subsets**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS.

- [ ] **Step 5.6: Commit end-to-end observer semantics coverage**

```bash
git add Tests/CooNetworkTests/NtkNetworkExecutorTests.swift \
        Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift \
        Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "test: verify parsing hooks are observer-only"
```

---

## Task 6: Final Verification

- [ ] **Step 6.1: Run full parser-related test subsets together**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS.

- [ ] **Step 6.2: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 6.3: Run full build**

Run:

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 6.4: Review git status before final handoff**

Run:

```bash
git status
```

Expected: only the intended Phase 2 changes remain.

- [ ] **Step 6.5: Commit any final verification-only adjustments if needed**

If verification uncovered any small fixes not already committed, stage only those focused files and create a final commit whose message matches the actual diff.

---

## Deferred Work (Not In This Plan)

The following remain intentionally out of scope for Phase 2:

- promoting parsing policy to a public `iNtkResponseParsingPolicy`
- introducing a `ParsingOutcome` wrapper type
- splitting policy into success/failure policies
- redesigning decoder / `extractHeader` ownership
- changing external parser public initializer shape beyond what dispatcher refactor strictly requires
- broad parser API cleanup outside the parsing submodule

---

## Verification Checklist

After all tasks complete, verify:

- [ ] `NtkParsingHookDispatcher` exists and is the only place that fans out parsing hook notifications
- [ ] parser no longer loops over hooks directly in `NtkDataParsingInterceptor.swift`
- [ ] policy no longer carries three parallel notification closures
- [ ] hook errors are logged/observed but do not change final business outcome
- [ ] one throwing hook does not block later hooks on the same notification
- [ ] typed passthrough does not trigger parsing hook notifications
- [ ] parser top-level flow reads as explicit Acquire / Prepare / Interpret / Decide stages
- [ ] Notify is implemented as a cross-cutting dispatcher mechanism at well-defined milestones, not as scattered ad-hoc loops
- [ ] `didComplete` still only runs on success
- [ ] `didValidateFail` still only runs on validation failure
- [ ] transform failures still stop before interpret notifications
- [ ] real parser cache-path and integration-path coverage both confirm observer-only hook behavior
- [ ] `swift test` passes
- [ ] `swift build` passes
