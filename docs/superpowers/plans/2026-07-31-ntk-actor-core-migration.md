# NtkActor Core Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unjustified `@NtkActor` coupling from the request execution pipeline while making `NtkNetworkExecutor` and per-request context safely transferable across concurrent tasks.

**Architecture:** `NtkNetworkExecutor` becomes an immutable `final class: Sendable`. `NtkInterceptorContext` becomes a per-request value struct without a client reference, and the interceptor chain plus its public async protocols become ordinary `Sendable` async interfaces. Real shared state in `NtkTaskManager`, request-key LRU, and `NtkNetworkCache` remains isolated for the next migration batch.

**Tech Stack:** Swift 6.1 package, Swift Testing, Swift concurrency (`Sendable`, actors, `@MainActor`), existing `NtkUnfairLock`.

---

## File Map

- Modify `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`: replace the actor-isolated reference context with a value context containing only request and chain metadata.
- Modify `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`: make the executor immutable and `Sendable`, and capture the client in final handlers.
- Modify `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift` and `Sources/CooNetwork/NtkNetwork/Ntk.swift`: remove obsolete executor/factory actor wording and type annotations.
- Modify `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorChainManager.swift`: remove global actor isolation from the immutable chain and all handler closures.
- Modify `Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift`, `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift`, `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift`, and `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift`: remove protocol-level `@NtkActor` requirements while retaining `Sendable` and `async`.
- Modify `Sources/CooNetwork/NtkNetwork/iNtk/iNtkClient.swift`, `Sources/CooNetwork/NtkNetwork/iNtk/iNtkCacheProvider.swift`, and `Sources/CooNetwork/NtkNetwork/cache/iNtkCacheStorage.swift`: let each adapter own its synchronization model.
- Modify `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`, `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift`, `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`, `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift`, `Sources/CooNetwork/NtkNetwork/UI/loading/NtkLoadingInterceptor.swift`, and `Sources/AlamofireClient/Client/AFClient.swift`: remove implementation-only global actor annotations and update actor-isolated cache construction where required.
- Modify `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`, `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`, `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`, `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift`, `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`, `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`, and `Tests/CooNetworkTests/AFToastInterceptorTests.swift`: update context construction, remove test-only global actor assumptions, and cover value-flow behavior.
- Modify `docs/ntk-actor-audit.md`: mark A02-A06 complete, mark A07 as protocol-complete but facade-pending, and record remaining stateful actor uses.

## Task 1: Make Context Per-Request Value State

**Files:**
- Modify: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift`
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`, `Tests/CooNetworkTests/AFToastInterceptorTests.swift`, `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`, and `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift` for direct context construction.

- [ ] **Step 1: Add a failing context ownership test.**

Change `ChainContextModifierInterceptor` to mutate a local context copy before passing it to `next`, then add this test below `contextModificationVisibleToNextInterceptor`:

```swift
@Test
@NtkActor
func contextMutationDoesNotWriteBackToSourceContext() async throws {
    let modifier = ChainContextModifierInterceptor(key: "testKey", value: "testValue")
    let capture = ChainValueCapture()
    let reader = ChainContextReaderInterceptor(key: "testKey", capture: capture)
    let manager = NtkInterceptorChainManager(interceptors: [modifier, reader]) { _ in
        ChainDummyResponse(request: ChainDummyRequest())
    }
    let source = makeContext()

    _ = try await manager.execute(context: source)

    #expect(await capture.value() as? String == "testValue")
    #expect(source.extraData["testKey"] == nil)
}
```

The current class context shares the dictionary reference, so the final expectation fails before the value conversion.

- [ ] **Step 2: Run the focused test and verify the failure.**

Run:

```bash
swift test --filter NtkInterceptorChainManagerTests.contextMutationDoesNotWriteBackToSourceContext
```

Expected: the test fails because `source.extraData["testKey"]` contains `"testValue"`.

- [ ] **Step 3: Replace the context implementation.**

Replace the contents of `NtkInterceptorContext.swift` with this shape:

```swift
import Foundation

/// 单次拦截器链的值上下文。
/// request 是构建完成后的只读快照；extraData 沿请求方向显式传给下游。
public struct NtkInterceptorContext: Sendable {
    public let request: NtkMutableRequest
    public var extraData: [String: any Sendable]

    init(
        request: NtkMutableRequest,
        extraData: [String: any Sendable] = [:]
    ) {
        self.request = request
        self.extraData = extraData
    }
}
```

The client is deliberately removed from the context. It is only used by executor final handlers and is captured there instead.

- [ ] **Step 4: Update context construction and value mutation.**

Use `NtkInterceptorContext(request: request)` at every production/test construction. In `NtkNetworkExecutor`, keep the client in a local constant for each final handler:

```swift
let client = config.client
let realChainManager = NtkInterceptorChainManager(interceptors: allInterceptors) { context in
    try await client.execute(context.request)
}
```

In `ChainContextModifierInterceptor`, use:

```swift
var nextContext = context
nextContext.extraData[key] = value
return try await next.handle(context: nextContext)
```

Update `makeAFContext`, `makeConfiguredAFContext`, and `makeSnapshotAFContext` in `AFDataParsingInterceptorTests.swift`; initialize request extra data on `NtkMutableRequest`, and initialize context extra data through a local `var context` before returning it.

- [ ] **Step 5: Update the parsing snapshot test for value semantics.**

Rename `parsingContextRemainsStableWhenSourceExtraDataChanges` to `parsingContextRemainsStableWhenSourceCopyChanges`. Replace the mutation helper with:

```swift
private func mutatedContext(_ source: NtkInterceptorContext) -> NtkInterceptorContext {
    var copy = source
    copy.extraData["context"] = "mutated-context-extra"
    return copy
}
```

The transformer may create and inspect this copy, but the `NtkParsingContext` snapshot must continue reporting `"captured-context-extra"` for both observations.

- [ ] **Step 6: Run context and parsing tests.**

Run:

```bash
swift test --filter 'NtkInterceptorChainManagerTests|AFDataParsingInterceptorTests'
```

Expected: PASS, including the new source-context ownership test and all parsing snapshot tests.

- [ ] **Step 7: Commit the context boundary.**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorContext.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift Tests/CooNetworkTests/AFToastInterceptorTests.swift Tests/CooNetworkTests/NtkRetryInterceptorTests.swift
git commit -m "refactor: make interceptor context value scoped"
```

## Task 2: Make the Executor Immutable and Sendable

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/Ntk.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: Add a concurrent shared-executor regression test.**

Add a test using the existing `ExecIncrementingRequestInterceptor` and cache setup:

```swift
@Test
@NtkActor
func sharedExecutorBuildsIndependentRequestsConcurrently() async throws {
    let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: true)
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/sendable"))
    request.responseType = String(describing: Bool.self)
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            NtkCacheInterceptor(storage: storage),
            ExecIncrementingRequestInterceptor()
        ]
    )
    let executor = NtkNetworkExecutor<Bool>(config: config)

    async let network = executor.execute()
    async let cache = executor.loadCache()
    let (networkResponse, cacheResponse) = try await (network, cache)

    #expect(networkResponse.request.headers?["X-Execution-Count"] == "1")
    #expect(cacheResponse?.request.headers?["X-Execution-Count"] == "1")
}
```

- [ ] **Step 2: Run the regression test before the type change.**

Run:

```bash
swift test --filter NtkNetworkExecutorTests.sharedExecutorBuildsIndependentRequestsConcurrently
```

Expected: PASS; this test locks in A08 behavior before changing the type declaration.

- [ ] **Step 3: Change the executor declarations.**

Apply these declaration changes:

```swift
final class NtkNetworkExecutor<ResponseData: Sendable>: Sendable {
    enum ResponseResult: Sendable {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }

    struct Configuration: Sendable {
        let client: any iNtkClient
        let request: NtkMutableRequest
        let interceptors: [any iNtkInterceptor]
    }
```

Remove the type-level `@NtkActor`, remove `nonisolated` from `init`, and keep all stored properties as `let`. Do not add an independent actor or mutable request field.

- [ ] **Step 4: Resolve transitional actor calls.**

Until Task 3 removes the remaining chain annotation, use explicit `await` for the actor-isolated chain constructor from executor methods. The context constructor is already ordinary after Task 1; request modifiers and the final client call still use their existing protocol isolation until Tasks 3-4.

- [ ] **Step 5: Remove the unused `Ntk` type annotation and stale executor wording.**

In `Ntk.swift`, remove `@NtkActor` and the redundant `nonisolated` before `with`. In `NtkNetwork.swift` and `Sources/CooNetwork/NtkNetwork/CLAUDE.md`, describe the executor as an immutable execution snapshot, not an Actor.

- [ ] **Step 6: Run executor and integration tests.**

Run:

```bash
swift test --filter 'NtkNetworkExecutorTests|NtkNetworkIntegrationTests|NtkNetworkSingleUseTests'
```

Expected: PASS with the executor shared as a `Sendable` reference.

- [ ] **Step 7: Commit the executor migration.**

```bash
git add Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Sources/CooNetwork/NtkNetwork/Ntk.swift Sources/CooNetwork/NtkNetwork/NtkNetwork.swift Sources/CooNetwork/NtkNetwork/CLAUDE.md Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "refactor: make network executor immutable sendable"
```

## Task 3: Remove Global Actor Isolation from the Chain and Interceptor Protocols

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorChainManager.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift`
- Modify: `Tests/CooNetworkTests/NtkRetryInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: Remove protocol-level actor annotations.**

The resulting protocol shapes are:

```swift
public protocol iNtkRequestHandler: Sendable {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse
}

public protocol iNtkInterceptor: Sendable {
    var priority: NtkInterceptorPriority { get }
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse
}

public protocol iNtkResponseParser: Sendable {
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse
}

public protocol iNtkRequestModifyingInterceptor: iNtkInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest
}
```

Remove matching annotations from the default implementations and `NtkResponseParserBox`.

- [ ] **Step 2: Make the chain an ordinary Sendable value.**

Change `NtkInterceptorChainManager` to `struct ...: Sendable`, remove `@NtkActor`, and use:

```swift
private let finalHandler: @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse

init(
    interceptors: [any iNtkInterceptor],
    finalHandler: @escaping @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse
) {
    self.interceptors = interceptors
    self.finalHandler = finalHandler
}
```

`buildChain` and `TempHandler.handler` must use this same nonisolated closure type. The recursive call order remains unchanged.

Update `NtkNetworkExecutor` in the same task to remove the transitional `await` around `NtkInterceptorChainManager(...)` and keep the final handler as the ordinary closure shown above.

- [ ] **Step 3: Remove implementation-only annotations and async log helpers.**

Remove explicit `@NtkActor` from `NtkDataParsingInterceptor.intercept/acquire` and `NtkRetryInterceptor.intercept`. Change these helpers to synchronous functions and remove `await` at their call sites:

```swift
private func recordRetryAttempt(retryCount: Int, delay: TimeInterval, error: Error) {
    logger.debug("[NtkRetry] Retry #\\(retryCount) in \\(delay)s. Error: \\(error)", category: .retry)
}
```

Keep `retryLoop` async because it calls `Task.sleep` and `next.handle`.

- [ ] **Step 4: Update chain tests to exercise ordinary async calls.**

Remove `@NtkActor` from the chain test methods, helper factory, and stateless chain test doubles. Update the context modifier to pass a copy as described in Task 1. Delete `ChainDummyClient` because context no longer carries a client.

Add this value-flow assertion to the existing chain test suite:

```swift
@Test
func ordinaryAsyncChainPreservesOrderWithoutGlobalActor() async throws {
    let counter = ChainCallCounter()
    let manager = NtkInterceptorChainManager(interceptors: [
        ChainRecordingInterceptor(id: "outer", counter: counter),
        ChainRecordingInterceptor(id: "inner", counter: counter)
    ]) { _ in
        await counter.record("final")
        return ChainDummyResponse(request: ChainDummyRequest())
    }

    _ = try await manager.execute(context: makeContext())

    #expect(await counter.log() == [
        "outer-request", "inner-request", "final",
        "inner-response", "outer-response"
    ])
}
```

- [ ] **Step 5: Update retry tests and handlers.**

Remove `@NtkActor` from retry test methods and `Counting*Handler`/`AlwaysFailHandler` where no state requires it. Keep `RetryExecutionCounter` as an independent actor because it owns mutable test state.

- [ ] **Step 6: Run the focused chain, parser, and retry tests.**

Run:

```bash
swift test --filter 'NtkInterceptorChainManagerTests|NtkRetryInterceptorTests|AFDataParsingInterceptorTests|NtkPayloadDecoderTests'
```

Expected: PASS; no chain or parser test needs to enter `NtkActor`.

- [ ] **Step 7: Commit the chain migration.**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkInterceptorChainManager.swift Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkInterceptor.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkRequestModifyingInterceptor.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkInterceptorChainManagerTests.swift Tests/CooNetworkTests/NtkRetryInterceptorTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "refactor: remove global actor from interceptor chain"
```

## Task 4: Remove Global Actor Requirements from Client and Cache Protocols

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkClient.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkCacheProvider.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/iNtkCacheStorage.swift`
- Modify: `Sources/AlamofireClient/Client/AFClient.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: Remove actor requirements from the adapter protocols.**

Use ordinary async requirements:

```swift
public protocol iNtkClient: Sendable {
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse
    func cancel()
}

public protocol iNtkCacheProvider: Sendable {
    func loadCacheData(for request: NtkMutableRequest) async throws -> (any Sendable)?
    func hasCacheData(for request: NtkMutableRequest) async -> Bool
}

public protocol iNtkCacheStorage: Sendable {
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta?
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool
}
```

- [ ] **Step 2: Remove AFClient isolation and correct its comment.**

Remove `@NtkActor` from `AFClient.execute` and `sendRequest`. Delete the comment claiming `sendRequest` is `nonisolated`; the method is now an ordinary async adapter method. Keep Alamofire request construction and serialization unchanged.

- [ ] **Step 3: Make cache interceptor construction explicit during the transitional facade.**

Because `NtkNetworkCache` remains `@NtkActor` until the LRU migration, construct it with `await` from the now ordinary cache interceptor methods:

```swift
public func loadCacheData(for request: NtkMutableRequest) async throws -> (any Sendable)? {
    let cache = await NtkNetworkCache(storage: storage)
    return try await cache.loadData(for: request)
}
```

Apply the same change to `hasCacheData` and the response-saving path in `intercept`.

- [ ] **Step 4: Update adapter test doubles.**

Remove actor annotations from stateless mock client/storage/parser methods in the touched test files. Keep any test actor whose stored state is mutable. Add one actor-backed adapter to `NtkNetworkIntegrationTests.swift`:

```swift
private actor ActorBackedClient: iNtkClient {
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
    }
}
```

Use it in a request test to verify the ordinary async protocol accepts implementation-owned actor isolation.

- [ ] **Step 5: Run adapter and integration tests.**

Run:

```bash
swift test --filter 'NtkNetworkIntegrationTests|NtkNetworkExecutorTests|NtkNetworkSingleUseTests|AFClientUploadTests|AFUploadRequestTests'
```

Expected: PASS; client and storage implementations no longer inherit the library global actor through protocol requirements.

- [ ] **Step 6: Commit the adapter migration.**

```bash
git add Sources/CooNetwork/NtkNetwork/iNtk/iNtkClient.swift Sources/CooNetwork/NtkNetwork/iNtk/iNtkCacheProvider.swift Sources/CooNetwork/NtkNetwork/cache/iNtkCacheStorage.swift Sources/AlamofireClient/Client/AFClient.swift Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "refactor: decouple adapters from global actor"
```

## Task 5: Audit Remaining Isolation and Update the Review Record

**Files:**
- Modify: `docs/ntk-actor-audit.md`
- Modify: `Sources/CooNetwork/NtkNetwork/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`
- Modify: source comments touched by the remaining `rg` inventory

- [ ] **Step 1: Inventory production references.**

Run:

```bash
rg -n -C 2 '@NtkActor|NtkActor' Sources/CooNetwork Sources/AlamofireClient
```

Expected remaining production references are limited to real state owners or transitional facades, primarily `NtkTaskManager`, `NtkRequestIdentifierManager`, `NtkNetworkCache`, and the `NtkActor` declaration itself. Any other result must be classified before removal.

- [ ] **Step 2: Update the audit status.**

In `docs/ntk-actor-audit.md`:

- mark A02, A03, A04, A05, and A06 as 已修正;
- mark A07 as 部分修正, explicitly noting that storage/provider protocols are decoupled while `NtkNetworkCache` still awaits the LRU migration;
- mark A12 as 部分修正 because `Ntk` and pipeline annotations are cleaned while remaining stateful modules still need review;
- leave A09-A11 and A13 pending;
- record that the next step is state-owner migration, not blind deletion of the remaining actor references.

- [ ] **Step 3: Update module comments.**

Replace comments that call `NtkNetworkExecutor` an Actor or describe the interceptor directory as globally actor-isolated. State that the executor is an immutable snapshot and that remaining actor isolation belongs to named state owners.

- [ ] **Step 4: Run the full verification suite.**

Run:

```bash
swift build -Xswiftc -strict-concurrency=complete
swift test
git diff --check
rg -n -C 1 '@NtkActor' Sources/CooNetwork Sources/AlamofireClient
```

Expected: strict build and all tests PASS; the final command prints only the deliberately retained state-owner annotations and the global actor declaration.

- [ ] **Step 5: Commit the audit update.**

```bash
git add docs/ntk-actor-audit.md Sources/CooNetwork/NtkNetwork/CLAUDE.md Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md
git commit -m "docs: record core NtkActor migration"
```

## Plan Self-Review

- A02 is covered by Tasks 1-2: value context, immutable executor, independent network/cache request snapshots.
- A03 is covered by Task 1: per-request value context and explicit downstream propagation.
- A04 and A05 are covered by Task 3: ordinary async protocols and matching chain closures.
- A06 and the protocol half of A07 are covered by Task 4; the `NtkNetworkCache` facade remains intentionally pending.
- A09-A11 are explicitly deferred to the state-owner migration described in Task 5 and the design document.
- A12 is partly covered by Tasks 2-3 and the remaining inventory.
- A13 is not claimed complete; only comments directly made false by this batch are updated.
- The plan contains no new public concept parallel to `iNtkInterceptor`.
