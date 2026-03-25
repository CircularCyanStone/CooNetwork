# Data Parsing Pipeline Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `NtkDataParsingInterceptor` so parser-internal branching is moved into a focused internal policy layer, while preserving the existing `normalize -> transform -> decode` pipeline and verifying the real parser still works through cache and integration paths.

**Architecture:** Keep the real parser flow exactly where it already is: acquire response, normalize payload, run transformers, decode or recover header, then decide final outcome. Introduce only the minimum abstractions needed to centralize decision logic: a small closed `ParsingResult` model plus an internal default policy implementation. Do not add an extra `ParsingOutcome` wrapper, and do not change hook failure semantics in this plan — that is a separate behavior change.

**Tech Stack:** Swift 6.1 / SPM, `@NtkActor`, Swift Testing framework (`import Testing`), existing `CooNetwork` / `AlamofireClient` modules

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift` | Main refactor target. Replace parser-internal branching with `ParsingResult` production + internal policy delegation. Preserve fast-path typed passthrough and current transform/decode ordering. |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseValidation.swift` | Keep protocol, but reposition it as a business-success checker used by policy rather than a parser-owned control point. |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadDecoding.swift` | Clarify that `extractHeader` remains interpretation-only and is not a success signal. |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkPayloadDecoders.swift` | Verify existing decoders still support decode/header-recovery behavior required by the refactor. |
| `Sources/CooNetwork/NtkNetwork/interceptor/` | Add a small `ParsingResult` type and an internal default parsing policy near parser implementation. |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | Primary regression suite. Expand tests around real parser behavior before implementation. |
| `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` | Add at least one real-parser cache-path regression instead of relying only on mock parser. |
| `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift` | Add at least one real-parser integration smoke test if current tests still bypass actual parser. |

### Recommended new files

Prefer the smallest surface area possible:

- `Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift`
- `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift`

Do **not** automatically promote policy into `iNtk/` public protocol space unless implementation proves external customization is genuinely needed.

---

## Reality Checks From Current Code

These are the implementation realities the plan must respect:

1. **Hooks are not final-outcome-only today.**
   - `didDecodeHeader` runs after successful decode: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift:79-85`
   - `willValidate` runs before validation: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift:153-160`
   - `didValidateFail` runs only on validation failure: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift:167-171`
   - `didComplete` runs only on success: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift:97`, `123`
   This plan does **not** change hook failure semantics. It only preserves current observation points while moving branching out of parser.

2. **`nil data` currently has two different outcomes depending on validation.**
   - validation pass → `.serviceDataEmpty`
   - validation fail → `.validation`
   This is already covered by tests and should remain the default-policy behavior.

3. **Decode failure with recovered header is subtle today.**
   In `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift:126-138`, recovered header is used to run validation, but success is still not implied. The default policy should preserve that semantic.

4. **Transformer failure stops before decoder and hooks.**
   This behavior is already covered and should stay unchanged.

5. **Current executor/integration tests mostly bypass the real parser.**
   `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` and `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift` mostly use mock parsing interceptors. This means parser-only tests are not enough; the plan must add minimal real-parser coverage for executor/cache/integration.

---

## Task 1: Expand Real Parser Regression Tests First

**Files:**
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`

- [ ] **Step 1.1: Add missing regression test for decode failure without recovered header**

Append to `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`:

```swift
@Test
@NtkActor
func decodeFailureWithoutRecoveredHeaderThrowsDecodeInvalid() async throws {
    let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
        validation: AFTestPassValidation(),
        decoder: AFTestNoHeaderDecoder()
    )
    let data = try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": ["id": 1, "name": "ok"],
        "retMsg": "ok"
    ])
    let handler = AFTestDataHandler(data: data, request: AFTestRequest())

    do {
        _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
        Issue.record("期望抛出 decodeInvalid")
    } catch let error as NtkError {
        if case .decodeInvalid = error {
            #expect(true)
        } else {
            Issue.record("错误类型不符: \(error)")
        }
    }
}
```

Add helper near existing test doubles:

```swift
private struct AFTestNoHeaderDecoder: iNtkResponsePayloadDecoding {
    func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<AFTestModel, AFTestKeys> {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "expected failure without header extraction")
        )
    }
}
```

- [ ] **Step 1.2: Add a regression test for `NtkNever` hook/validation behavior**

Append:

```swift
@Test
@NtkActor
func ntkNeverStillTriggersWillValidateAndDidComplete() async throws {
    let hook = AFTestRecordingHook()
    let json: [String: Any] = ["retCode": 0, "data": NSNull(), "retMsg": "ok"]
    let data = try JSONSerialization.data(withJSONObject: json)
    let interceptor = NtkDataParsingInterceptor<NtkNever, AFTestKeys>(
        validation: AFTestPassValidation(),
        hooks: [hook]
    )
    let handler = AFTestDataHandler(data: data, request: AFTestRequest())

    _ = try await interceptor.intercept(context: makeAFContext(), next: handler)

    #expect(hook.events.contains("didDecodeHeader"))
    #expect(hook.events.contains("willValidate"))
    #expect(hook.events.contains("didComplete"))
}
```

- [ ] **Step 1.3: Run parser tests to confirm baseline is locked**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: all parser tests PASS, including the new baseline tests.

- [ ] **Step 1.4: Commit baseline tests**

```bash
git add Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift
git commit -m "test: lock real parser baseline behavior"
```

---

## Task 2: Introduce Minimal Internal Parsing Result and Default Policy

**Files:**
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift`
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`

- [ ] **Step 2.1: Create a minimal closed `ParsingResult` model**

Create `Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift`:

```swift
import Foundation

enum NtkParsingResult<ResponseData: Sendable>: Sendable {
    case decoded(
        code: NtkReturnCode,
        msg: String?,
        data: ResponseData?,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )

    case headerRecovered(
        decodeError: DecodingError,
        rawPayload: NtkPayload,
        header: NtkExtractedHeader,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )

    case unrecoverableDecodeFailure(
        decodeError: DecodingError,
        rawPayload: NtkPayload,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )
}
```

Keep it `internal`.

- [ ] **Step 2.2: Create an internal default policy**

Create `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift`.

Its job is to preserve current behavior exactly:

- `.decoded` + `ResponseData == NtkNever.Type` → return `NtkResponse<NtkNever>` after validation
- `.decoded` + `data == nil` → validate optional response, then throw `.serviceDataEmpty` if validation passed
- `.decoded` + normal data → return typed response after validation
- `.headerRecovered` → build `NtkResponse<NtkDynamicData?>`, validate, and if validation passes then throw `.decodeInvalid`
- `.unrecoverableDecodeFailure` → throw `.decodeInvalid`

The API should stay minimal, for example:

```swift
@NtkActor
func decide(
    from result: NtkParsingResult<ResponseData>,
    validation: iNtkResponseValidation,
    context: NtkInterceptorContext
) async throws -> any iNtkResponse
```

Do not pass decoder, transformer, hooks, or next handler into policy.

- [ ] **Step 2.3: Refactor parser to build `ParsingResult` and delegate decisions**

In `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`:

1. Keep typed passthrough at the top
2. Keep `NtkClientResponse` guard
3. Keep `normalize` and `transform`
4. Replace decode/branch/catch logic with:
   - decode success → build `.decoded`
   - decode failure with header → build `.headerRecovered`
   - decode failure without header → build `.unrecoverableDecodeFailure`
5. Delegate final result to `NtkDefaultResponseParsingPolicy`

Important:
- Do **not** add a public policy protocol
- Do **not** change hook failure behavior in this task
- Do **not** change public initializer shape unless truly necessary

- [ ] **Step 2.4: Run parser tests**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS with no externally visible behavior changes.

- [ ] **Step 2.5: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift \
        Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift \
        Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift
git commit -m "refactor: move parser branching into default parsing policy"
```

---

## Task 3: Move Validation Out of Parser and Into Policy

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseValidation.swift`

- [ ] **Step 3.1: Remove parser-owned validation helpers**

In `NtkDataParsingInterceptor.swift`, remove `runValidation(...)` and `validate(...)` once policy fully owns validation calls.

If a tiny helper remains needed for current hook notification only, keep it focused on notification and nothing else.

- [ ] **Step 3.2: Keep validation as a checker, not a parallel decision center**

In `NtkDefaultResponseParsingPolicy.swift`, centralize all calls to `validation.isServiceSuccess(...)`.

Use small private helpers for:
- building typed responses
- running validation
- converting validation failure to `NtkError.validation`

- [ ] **Step 3.3: Update validation comments to reflect its new role**

In `iNtkResponseValidation.swift`, revise comments so the protocol is described as a business-success checker used by parsing policy, not a parser-owned control point.

Do not remove the protocol in this refactor.

- [ ] **Step 3.4: Run parser tests**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS.

- [ ] **Step 3.5: Commit**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift \
        Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift \
        Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseValidation.swift
git commit -m "refactor: centralize validation inside parsing policy"
```

---

## Task 4: Add Real Parser Coverage to Executor/Cache/Integration Paths

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 4.1: Add a dedicated JSON/Data executor test using real parser**

In `NtkNetworkExecutorTests.swift`, add a test that uses the actual parser instead of `ExecMockParsingInterceptor`.

Use a dedicated `Data` payload and keys helper rather than current Bool-direct-return mocks.

Example target:

```swift
@Test
@NtkActor
func loadCacheWithRealParserStillReturnsTypedCachedResponse() async throws {
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

    let parser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(validation: ExecDummyValidation())
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [NtkResponseParserBox(parser), NtkCacheInterceptor(storage: storage)]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    let response = try await executor.loadCache()
    #expect(response?.data == true)
    #expect(response?.isCache == true)
}
```

- [ ] **Step 4.2: Add a dedicated JSON/Data integration smoke test using real parser**

In `NtkNetworkIntegrationTests.swift`, add one network-path test using real parser instead of `IntegMockParsingInterceptor`.

Use a dedicated JSON client stub rather than existing direct-bool client.

Example target:

```swift
@Test
func requestWithRealParserReturnsDecodedBoolResponse() async throws {
    let client = IntegJSONClient(data: try JSONSerialization.data(withJSONObject: [
        "retCode": 0,
        "data": true,
        "retMsg": "ok"
    ]))

    let network = NtkNetwork<Bool>.with(
        client,
        request: IntegDummyRequest(path: "/integration/real-parser"),
        responseParser: NtkDataParsingInterceptor<Bool, IntegTestKeys>(validation: IntegDummyValidation())
    )

    let response = try await network.request()
    #expect(response.data == true)
}
```

- [ ] **Step 4.3: Run executor and integration test subsets**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS.

- [ ] **Step 4.4: Commit**

```bash
git add Tests/CooNetworkTests/NtkNetworkExecutorTests.swift \
        Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift
git commit -m "test: add real parser coverage for executor and integration paths"
```

---

## Task 5: Final Verification

- [ ] **Step 5.1: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 5.2: Run full build**

Run:

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 5.3: Commit final tested refactor**

```bash
git status
```

If there are remaining changes not yet committed in prior tasks, commit them with a focused message matching the actual diff.

---

## Deferred Work (Not In This Plan)

The following are intentionally out of scope for this implementation plan and should be handled in a separate change if still desired:

- changing hook failure semantics to best-effort / observer-only
- changing public hook API shape or method names
- promoting parsing policy into `iNtk/` public protocol space
- updating `docs/design-decisions.md`

---

## Verification Checklist

After all tasks complete, verify:

- [ ] `NtkDataParsingInterceptor` no longer directly branches on `NtkNever`, `nil data`, or decode-fallback outcomes
- [ ] a minimal closed `ParsingResult` model exists with only the states needed by current behavior
- [ ] no extra `ParsingOutcome` wrapper was introduced
- [ ] no public parsing policy protocol was introduced unless implementation proved it necessary
- [ ] `extractHeader` remains decoder-owned interpretation logic and is not treated as implicit success
- [ ] policy does not receive decoder/transformer/hooks/next-handler references
- [ ] current hook failure behavior is unchanged in this plan
- [ ] `validation` is no longer a parser-owned parallel decision path
- [ ] at least one executor/cache test and one integration test exercise the real parser through `Data` payloads
- [ ] `swift build` passes
- [ ] `swift test` passes
