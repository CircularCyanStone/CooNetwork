# NtkActor Final Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the last `NtkActor` users with state-owner isolation, make the cache facade transferable, and remove the obsolete global actor from production code, tests, and current documentation.

**Architecture:** `NtkTaskManager` and `NtkRequestIdentifierManager` become independent actors because each owns a separate mutable state machine. Deduplication identifier generation remains `nonisolated` pure computation so task registration gains no new reentrancy point; `NtkNetworkCache` becomes an immutable `Sendable` facade and awaits only the identifier actor and cache storage. `NtkNetwork` keeps its short synchronous lock because its builder interface is intentionally synchronous.

**Tech Stack:** Swift 6.1 strict concurrency, Swift actors and global actors, Swift Testing, Swift Package Manager, CryptoKit

---

**Out of Scope:** Loading/Toast callback `MainActor` policy is a separate UI contract decision. Those production types no longer reference `NtkActor`, so this plan only removes obsolete test annotations and does not change callback execution semantics.

## File Map

- `Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift`: own the cache-key LRU in an independent actor; expose deduplication hashing as nonisolated pure computation; remove the unused `requestCache` dictionary.
- `Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift`: become an immutable `Sendable` facade and await cache-key generation.
- `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`: construct the nonisolated cache facade synchronously.
- `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`: become an independent actor and retain its existing reentrancy/token checks.
- `Sources/CooNetwork/NtkNetwork/utils/NtkActor.swift`: delete after every production and test reference has migrated.
- `Tests/CooNetworkTests/NtkRequestIdentifierManagerTests.swift`: assert independent actor ownership, nonisolated deduplication hashing, and concurrent cache-key consistency.
- `Tests/CooNetworkTests/NtkNetworkCacheTests.swift`: add cache-facade transferability and concurrent-use coverage.
- `Tests/CooNetworkTests/NtkTaskManagerTests.swift`: assert actor ownership and await actor-isolated control operations.
- `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`: remove obsolete global-actor annotations from stateless tests and adapters.
- `Tests/CooNetworkTests/AFToastInterceptorTests.swift`: remove obsolete global-actor annotations from tests and adapters.
- `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`: remove obsolete global-actor annotations.
- `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`: remove obsolete global-actor annotations from tests, factories, protocol witnesses, and stateless adapters.
- `README.md`: replace the global actor execution model and remove outdated interceptor annotations.
- `docs/architecture.md`: document immutable execution snapshots and state-owner isolation.
- `docs/ntk-actor-audit.md`: record the final resolution of the remaining audit findings.
- `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`: remove the deleted symbol from current module guidance.

### Task 1: Give the Identifier LRU Its Own Actor

**Files:**
- Modify: `Tests/CooNetworkTests/NtkRequestIdentifierManagerTests.swift:318-390`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift:104-341`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift:28-70`

- [ ] **Step 1: Add failing isolation-contract tests**

In `NtkRequestIdentifierManagerTests`, remove `@NtkActor` from the three integration tests. Make the two cache-key tests await `getCacheKey`, make the deduplication test synchronous, and add these tests and helper:

```swift
@Test
func request_identifier_manager_owns_actor_isolation() {
    requireActor(NtkRequestIdentifierManager.shared)
}

@Test
func request_identifier_generation_does_not_require_actor_hop() {
    let request = createTestRequest(path: "/api/nonisolated-identifier")

    let identifier = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)

    #expect(identifier.hasPrefix("request_"))
}

@Test
func concurrent_cache_key_requests_return_one_value() async {
    let request = createTestRequest(path: "/api/concurrent-cache-key")
    let config = NtkRequestConfiguration(cacheTime: 3600)

    let keys = await withTaskGroup(of: String.self, returning: [String].self) { group in
        for _ in 0..<100 {
            group.addTask {
                await NtkRequestIdentifierManager.shared.getCacheKey(
                    request: request,
                    cacheConfig: config
                )
            }
        }

        var values: [String] = []
        for await key in group {
            values.append(key)
        }
        return values
    }

    #expect(Set(keys).count == 1)
}

private func requireActor<A: Actor>(_ value: A) {}
```

The existing cache-key assertions must use the following call form:

```swift
let key1 = await NtkRequestIdentifierManager.shared.getCacheKey(
    request: request,
    cacheConfig: config
)
```

- [ ] **Step 2: Run the identifier tests and verify the old design fails to compile**

Run:

```bash
swift test --filter NtkRequestIdentifierManagerTests
```

Expected: compilation fails because `NtkRequestIdentifierManager` does not conform to `Actor`, and the nonisolated test cannot synchronously call the current `@NtkActor`-isolated `getRequestIdentifier`.

- [ ] **Step 3: Convert the identifier manager and remove dead mirrored state**

Apply these declaration changes in `NtkRequestIdentifierManager.swift`:

```diff
-@NtkActor
-public class NtkRequestIdentifierManager {
+public actor NtkRequestIdentifierManager {
```

Delete the unused dictionary and both writes to it:

```diff
-    private var requestCache: [RequestCacheKey: String] = [:]
```

```diff
-                requestCache.removeValue(forKey: removed.key)
                 lruNodeIndex.removeValue(forKey: removed.key)
```

```diff
-        requestCache[requestKey] = cacheKey
         let newNode = lruList.addFirst(key: requestKey, value: cacheKey)
```

Keep `getCacheKey`, `generateHashForCache`, and `buildHashComponents` actor-isolated. Make the pure deduplication path nonisolated:

```diff
-    public func getRequestIdentifier(request: NtkMutableRequest) -> String {
+    public nonisolated func getRequestIdentifier(request: NtkMutableRequest) -> String {
```

```diff
-    private func generateHashForDeduplication(request: NtkMutableRequest) -> Int {
+    private nonisolated func generateHashForDeduplication(request: NtkMutableRequest) -> Int {
```

```diff
-    private func appendFilteredHeaders(
+    private nonisolated func appendFilteredHeaders(
```

```diff
-    private func appendFilteredParameters(
+    private nonisolated func appendFilteredParameters(
```

- [ ] **Step 4: Cross the new actor boundary from the transitional cache facade**

Keep `NtkNetworkCache` on `@NtkActor` for this task, but make cache-key generation asynchronous so the repository compiles after the identifier manager becomes an independent actor:

```swift
private func createCacheKey(for request: NtkMutableRequest) async -> String {
    await NtkRequestIdentifierManager.shared.getCacheKey(
        request: request,
        cacheConfig: request.requestConfiguration
    )
}
```

Use `await createCacheKey(for: request)` in `hasData`, `loadData`, and `save`.

- [ ] **Step 5: Run focused and full compile verification**

Run:

```bash
swift test --filter 'NtkRequestIdentifierManagerTests|NtkRequestIdentifierManagerPerformanceTests'
swift test --filter NtkNetworkExecutorTests
```

Expected: both commands pass; performance tests continue to await `getCacheKey`, and cache behavior remains unchanged.

- [ ] **Step 6: Commit the independent identifier actor**

```bash
git add Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift Tests/CooNetworkTests/NtkRequestIdentifierManagerTests.swift
git commit -m "refactor: isolate request identifier cache"
```

### Task 2: Make the Cache Facade Sendable

**Files:**
- Create: `Tests/CooNetworkTests/NtkNetworkCacheTests.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift:8-72`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift:55-80`

- [ ] **Step 1: Add a failing nonisolated concurrent-use test**

Create `NtkNetworkCacheTests.swift` with:

```swift
import Foundation
import Testing

@testable import CooNetwork

struct NtkNetworkCacheTests {
    @Test
    func cache_can_be_constructed_and_shared_outside_an_actor() async {
        let cache = NtkNetworkCache(storage: NetworkCacheTestStorage())
        let request = NtkMutableRequest(NetworkCacheTestRequest())

        async let first = cache.hasData(for: request)
        async let second = cache.hasData(for: request)

        let (firstResult, secondResult) = await (first, second)
        #expect(firstResult)
        #expect(secondResult)
        requireSendable(cache)
    }
}

private func requireSendable<T: Sendable>(_ value: T) {}

private struct NetworkCacheTestStorage: iNtkCacheStorage {
    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        nil
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }
}

private struct NetworkCacheTestRequest: iNtkRequest {
    let baseURL = URL(string: "https://example.com")
    let path = "/cache/sendable"
    let method: NtkHTTPMethod = .get
    let timeout: TimeInterval = 30
}
```

- [ ] **Step 2: Run the cache test and verify construction is still isolated**

Run:

```bash
swift test --filter NtkNetworkCacheTests
```

Expected: compilation fails because `NtkNetworkCache(storage:)` is still `@NtkActor`-isolated and the test intentionally constructs it without `await`.

- [ ] **Step 3: Make the facade immutable and transferable**

In `NtkNetworkCache.swift`, remove the unused `CryptoKit` import and replace the type declaration:

```diff
-import CryptoKit
```

```diff
-@NtkActor
-public class NtkNetworkCache {
+public final class NtkNetworkCache: Sendable {
```

Keep `storage` as `public let storage: iNtkCacheStorage`; its protocol already refines `Sendable`. Keep the asynchronous cache-key helper introduced in Task 1.

- [ ] **Step 4: Remove obsolete awaits from facade construction**

In all three `NtkCacheInterceptor` methods, use synchronous construction:

```swift
let cache = NtkNetworkCache(storage: storage)
```

Retain `await` or `try await` on `save`, `loadData`, and `hasData`.

- [ ] **Step 5: Run cache and executor regression tests**

Run:

```bash
swift test --filter 'NtkNetworkCacheTests|NtkNetworkExecutorTests|NtkNetworkIntegrationTests'
```

Expected: all selected suites pass, including concurrent sharing of one cache facade.

- [ ] **Step 6: Commit the Sendable cache facade**

```bash
git add Sources/CooNetwork/NtkNetwork/cache/NtkNetworkCache.swift Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift Tests/CooNetworkTests/NtkNetworkCacheTests.swift
git commit -m "refactor: make network cache sendable"
```

### Task 3: Give the Task Registry Its Own Actor

**Files:**
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift:1-730`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift:10-31`

- [ ] **Step 1: Add a failing actor-ownership test**

Add this test to `NtkTaskManagerTests` and add the helper at file scope:

```swift
@Test
func task_manager_owns_actor_isolation() {
    requireActor(NtkTaskManager.shared)
}

private func requireActor<A: Actor>(_ value: A) {}
```

- [ ] **Step 2: Run the task-manager test and verify the global-actor class is rejected**

Run:

```bash
swift test --filter NtkTaskManagerTests.task_manager_owns_actor_isolation
```

Expected: compilation fails because the current global-actor-isolated class does not conform to `Actor`.

- [ ] **Step 3: Convert the registry to an independent actor**

Replace the declaration and update the comment:

```diff
-/// - 基于全局 Actor 串行化对内部状态的读写，避免多线程下字典竞争；
+/// - 由任务管理器自身的 actor 隔离串行化内部状态读写；
```

```diff
-@NtkActor
-final class NtkTaskManager {
+actor NtkTaskManager {
```

Do not add an `await` inside `requestIdentifier(for:)`; Task 1 made `getRequestIdentifier` nonisolated specifically to preserve the synchronous cancellation-check-to-registration segment.

- [ ] **Step 4: Update task-manager tests for the real actor boundary**

Remove all eleven `@NtkActor` test annotations from `NtkTaskManagerTests.swift`.

Prefix every direct `cancelRequest` call with `await`:

```swift
await NtkTaskManager.shared.cancelRequest(request: request)
```

Prefix every direct query with `await`:

```swift
let isActive = await NtkTaskManager.shared.isRequestActive(request: request)
#expect(isActive)
```

For assertions currently containing a direct `NtkTaskManager.shared.isRequestActive` call, bind the result to a local Boolean first and assert the local value. Existing `executeWithDeduplication` calls already use `await` and require no interface change.

- [ ] **Step 5: Run task lifecycle and integration tests**

Run:

```bash
swift test --filter NtkTaskManagerTests
swift test --filter 'NtkNetworkIntegrationTests|NtkNetworkSingleUseTests'
```

Expected: all selected suites pass; owner/follower cancellation, type isolation, timeout cleanup, and non-deduplicated task replacement retain their existing behavior.

- [ ] **Step 6: Commit the task-manager actor**

```bash
git add Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift Tests/CooNetworkTests/NtkTaskManagerTests.swift
git commit -m "refactor: isolate task manager state"
```

### Task 4: Remove Obsolete Test Isolation

**Files:**
- Modify: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/AFToastInterceptorTests.swift`
- Modify: `Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: Remove every remaining test-target `@NtkActor` annotation**

Use `apply_patch` to delete each `@NtkActor` annotation in the four listed files. This includes annotations on test methods, helper factories, stateless test structs, protocol-witness methods, and cache-storage methods. Do not replace them with `@MainActor`; these tests and adapters do not own UI state.

Representative resulting declarations are:

```swift
func alreadyTypedResponsePassesThrough() async throws {
```

```swift
private func makeExecutor(
    client: ExecMockClient,
    interceptors: [any iNtkInterceptor] = [],
    parsingInterceptor: (any iNtkResponseParser)? = ExecMockParsingInterceptor(),
    cacheStorage: (any iNtkCacheStorage)? = nil
) -> NtkNetworkExecutor<Bool> {
```

```swift
private struct ExecMockClient: iNtkClient {
    let result: Result<Void, Error>

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        switch result {
        case .success:
            return NtkClientResponse(
                data: true,
                msg: nil,
                response: true,
                request: request,
                isCache: false
            )
        case .failure(let error):
            throw error
        }
    }
}
```

- [ ] **Step 2: Verify no test still depends on the global actor**

Run:

```bash
rg -n '@NtkActor|NtkActor' Tests/CooNetworkTests -g '*.swift'
```

Expected: no output.

- [ ] **Step 3: Run all affected suites**

Run:

```bash
swift test --filter 'AFDataParsingInterceptorTests|AFToastInterceptorTests|NtkDefaultResponseParsingPolicyTests|NtkNetworkExecutorTests'
```

Expected: all selected suites pass without global-actor test isolation.

- [ ] **Step 4: Commit the test cleanup**

```bash
git add Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift Tests/CooNetworkTests/AFToastInterceptorTests.swift Tests/CooNetworkTests/NtkDefaultResponseParsingPolicyTests.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "test: remove obsolete NtkActor isolation"
```

### Task 5: Delete NtkActor and Align Current Documentation

**Files:**
- Delete: `Sources/CooNetwork/NtkNetwork/utils/NtkActor.swift`
- Modify: `README.md:21-31,347-383`
- Modify: `docs/architecture.md:3-18`
- Modify: `docs/ntk-actor-audit.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md:5-10`

- [ ] **Step 1: Verify production annotations are gone before deleting the declaration**

Run:

```bash
rg -n '@NtkActor' Sources/CooNetwork Sources/AlamofireClient Tests/CooNetworkTests
```

Expected: no output. If the declaration is matched only because the search includes its doc comment or filename, confirm there are no attribute usages before proceeding.

- [ ] **Step 2: Delete the global actor declaration**

Delete `Sources/CooNetwork/NtkNetwork/utils/NtkActor.swift` with `apply_patch`. No replacement type or deprecated alias should be introduced because the approved design allows source-level breaking changes and no common global invariant remains.

- [ ] **Step 3: Rewrite the current concurrency overview**

In `README.md`, replace the Swift 6 feature statement with:

```markdown
✅ **Swift 6 原生支持** — 不可变请求快照与 `Sendable` 值流负责跨并发域传递，共享状态由独立 actor 或短临界区锁按所有权隔离
```

Remove `@NtkActor` from the `LoggingInterceptor` and `CommonParameterInterceptor` examples; keep their async method signatures unchanged.

In `docs/architecture.md`, replace the outdated dual-layer actor description and `@NtkActor` section with:

```markdown
## 核心架构：状态所有权

1. **配置层 (`NtkNetwork`)** — Builder 模式类，使用短临界区锁保护同步配置和请求快照，保留链式调用接口。
2. **执行层 (`NtkNetworkExecutor`)** — 不可变 `Sendable` 执行快照；每次动作从初始请求创建局部值，不共享动作期间的可变状态。
3. **状态所有者** — `NtkTaskManager` 和 `NtkRequestIdentifierManager` 分别使用独立 actor 保护任务表与缓存键 LRU。

actor 隔离按共享可变状态的所有权划分，不按“网络功能”统一调度。无状态模块和只读快照使用 `Sendable`；短小、同步且不跨 `await` 的配置临界区使用锁。
```

In `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`, replace the named-symbol guidance with:

```markdown
链管理器和上下文是普通 `Sendable` 值流，不绑定全局 actor；共享可变状态由具体拦截器或状态所有者自行隔离。
```

Update `docs/ntk-actor-audit.md` so A07, A09, A10, A12, and A13 record the implemented final state: independent task and identifier actors, Sendable cache facade, updated current documentation, and deleted global actor. Preserve the document's audit history and rationale.

- [ ] **Step 4: Verify current code and documentation no longer advertise the deleted model**

Run:

```bash
rg -n 'NtkActor|全局 Actor|全局Actor|Actor 执行层' README.md docs/architecture.md Sources/CooNetwork Sources/AlamofireClient Tests/CooNetworkTests
```

Expected: no output. Historical audit, spec, and implementation-plan documents are intentionally outside this zero-reference check because they record the migration decision.

- [ ] **Step 5: Run strict final verification**

Run:

```bash
swift test
git diff --check
git status --short
```

Expected: the complete test suite passes, `git diff --check` prints nothing, and `git status --short` lists only the Task 5 documentation edits and `NtkActor.swift` deletion before commit.

- [ ] **Step 6: Commit final removal**

```bash
git add README.md docs/architecture.md docs/ntk-actor-audit.md Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md Sources/CooNetwork/NtkNetwork/utils/NtkActor.swift
git commit -m "refactor: remove NtkActor"
```

### Task 6: Post-Commit Verification

**Files:**
- Verify only; no planned modifications

- [ ] **Step 1: Confirm the commit sequence and clean worktree**

Run:

```bash
git log -5 --oneline
git status --short
```

Expected: the five implementation commits appear in order and the worktree is clean.

- [ ] **Step 2: Run the full suite from the committed tree**

Run:

```bash
swift test
```

Expected: all tests pass with no Swift 6 actor-isolation or `Sendable` diagnostics.

- [ ] **Step 3: Confirm only historical documents retain the removed name**

Run:

```bash
rg -l 'NtkActor' . --hidden --glob '!.git/**' --glob '!.build/**'
```

Expected: matches are limited to migration history such as `docs/ntk-actor-audit.md`, `docs/superpowers/specs/`, `docs/superpowers/plans/`, and older historical design/review records. No source file, test file, README, or current architecture guidance appears.
