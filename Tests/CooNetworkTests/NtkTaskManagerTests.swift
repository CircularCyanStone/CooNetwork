import Foundation
import Testing

@testable import CooNetwork

@Suite(.serialized)
struct NtkTaskManagerTests {

    @Test
    func task_manager_owns_actor_isolation() {
        requireActor(NtkTaskManager.shared)
    }

    @Test
    func testDisabledDeduplicationKeepsLatestTaskMapped() async throws {
        let gate = TaskExecutionGate()
        var firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
        firstRequest.disableDeduplication()
        var secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
        secondRequest.disableDeduplication()

        let firstTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: firstRequest, identity: nil, effectiveTimeout: 30
            ) { await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "first" } as String
        }
        await gate.waitUntilFirstStarted()
        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: secondRequest, identity: nil, effectiveTimeout: 30
            ) { await gate.signalSecondStarted(); await gate.waitForSecondRelease(); return "second" } as String
        }
        await gate.waitUntilSecondStarted()
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: firstRequest.instanceIdentifier))
        await gate.releaseFirst()
        #expect(try await firstTask.value == "first")
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: firstRequest.instanceIdentifier) == false)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: secondRequest.instanceIdentifier))
        await gate.releaseSecond()
        #expect(try await secondTask.value == "second")
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: secondRequest.instanceIdentifier) == false)
    }

    @Test
    func testDifferentResponseTypesShouldNotDedup() async throws {
        let counter = ExecutionCounter()
        let gate = TaskExecutionGate()
        let stringRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/type-isolation"))
        let intRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/type-isolation"))
        let stringTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: stringRequest, identity: deduplicationIdentity(String.self), effectiveTimeout: 30
            ) { await counter.increment(); await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "string-result" } as String
        }
        await gate.waitUntilFirstStarted()
        let intTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: intRequest, identity: deduplicationIdentity(Int.self), effectiveTimeout: 30
            ) { await counter.increment(); await gate.signalSecondStarted(); await gate.waitForSecondRelease(); return 42 } as Int
        }
        await gate.waitUntilSecondStarted()
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: stringRequest.instanceIdentifier))
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: intRequest.instanceIdentifier))
        await gate.releaseFirst(); await gate.releaseSecond()
        #expect(try await stringTask.value == "string-result")
        #expect(try await intTask.value == 42)
        #expect(await counter.value() == 2)
    }

    @Test
    func testCancelRequestCancelsOnlyCurrentDisabledDeduplicationTask() async throws {
        let gate = TaskExecutionGate()
        var firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        firstRequest.disableDeduplication(); firstRequest.isCancelledRef = NtkCancellableState()
        var secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        secondRequest.disableDeduplication()
        let firstSnapshot = firstRequest
        let firstTask = Task { () -> Result<String, Error> in
            do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: firstSnapshot, identity: nil, effectiveTimeout: 30) {
                await gate.signalFirstStarted(); try await Task.sleep(nanoseconds: 300_000_000); return "first"
            }) } catch { return .failure(error) }
        }
        let secondTask = Task { () -> Result<String, Error> in
            do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: secondRequest, identity: nil, effectiveTimeout: 30) {
                await gate.signalSecondStarted(); await gate.waitForSecondRelease(); try Task.checkCancellation(); return "second"
            }) } catch { return .failure(error) }
        }
        await gate.waitUntilFirstStarted(); await gate.waitUntilSecondStarted()
        firstRequest.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: firstRequest.instanceIdentifier)
        await gate.releaseSecond()
        if case .failure(let error) = await firstTask.value { #expect(isCancellationError(error)) } else { Issue.record("第一个非去重请求应被取消") }
        if case .failure = await secondTask.value { Issue.record("第二个非去重请求不应被取消") }
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: secondRequest.instanceIdentifier) == false)
    }

    @Test
    func testEnabledDeduplicationSharesSingleExecution() async throws {
        let counter = ExecutionCounter(); let gate = TaskExecutionGate()
        let firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))
        let secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))
        let identity = deduplicationIdentity(String.self)
        let firstTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: firstRequest, identity: identity, effectiveTimeout: 30) {
            await counter.increment(); await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "shared"
        } as String }
        await gate.waitUntilFirstStarted()
        let secondTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: secondRequest, identity: identity, effectiveTimeout: 30) {
            await counter.increment(); return "should-not-run"
        } as String }
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: firstRequest.instanceIdentifier))
        await gate.releaseFirst()
        #expect(try await firstTask.value == "shared")
        #expect(try await secondTask.value == "shared")
        #expect(await counter.value() == 1)
    }

    @Test
    func testCancelAndReenterDedupRequestKeepsNewTaskMapped() async throws {
        let gate = TaskExecutionGate()
        var request = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter"))
        request.isCancelledRef = NtkCancellableState(); let snapshot = request
        let identity = deduplicationIdentity(String.self)
        let firstTask = Task { () -> Result<String, Error> in
            do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: snapshot, identity: identity, effectiveTimeout: 30) {
                await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "cancelled-first"
            }) } catch { return .failure(error) }
        }
        await gate.waitUntilFirstStarted(); request.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: request.instanceIdentifier)
        let newRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter"))
        let secondTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: newRequest, identity: identity, effectiveTimeout: 30) {
            await gate.signalSecondStarted(); await gate.waitForSecondRelease(); return "second"
        } as String }
        await gate.waitUntilSecondStarted()
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: newRequest.instanceIdentifier))
        await gate.releaseFirst(); _ = await firstTask.value
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: newRequest.instanceIdentifier))
        await gate.releaseSecond(); #expect(try await secondTask.value == "second")
    }

    @Test
    func testDedupFollowerCancelDoesNotAffectSharedWaiting() async throws {
        let gate = TaskExecutionGate(); let counter = ExecutionCounter(); let identity = deduplicationIdentity(String.self)
        let owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        var follower = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel")); follower.isCancelledRef = NtkCancellableState(); let followerSnapshot = follower
        let another = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        let ownerTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: owner, identity: identity, effectiveTimeout: 30) {
            await counter.increment(); await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "shared"
        } as String }
        await gate.waitUntilFirstStarted()
        let followerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: followerSnapshot, identity: identity, effectiveTimeout: 30) { await counter.increment(); return "should-not-run" }) } catch { return .failure(error) } }
        try await Task.sleep(nanoseconds: 50_000_000); follower.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier)
        let anotherTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: another, identity: identity, effectiveTimeout: 30) { await counter.increment(); return "should-not-run" } as String }
        try await Task.sleep(nanoseconds: 50_000_000); await gate.releaseFirst()
        #expect(try await ownerTask.value == "shared")
        if case .failure(let error) = await followerTask.value { #expect(isCancellationError(error)) } else { Issue.record("被取消的 follower 应该收到错误") }
        #expect(try await anotherTask.value == "shared"); #expect(await counter.value() == 1)
    }

    @Test
    func testDedupOwnerCancelDoesNotAffectFollower() async throws {
        let gate = TaskExecutionGate(); let counter = ExecutionCounter(); let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel")); owner.isCancelledRef = NtkCancellableState(); let ownerSnapshot = owner
        let follower = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel"))
        let ownerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: ownerSnapshot, identity: identity, effectiveTimeout: 30) { await counter.increment(); await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "shared" }) } catch { return .failure(error) } }
        await gate.waitUntilFirstStarted()
        let followerTask = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: follower, identity: identity, effectiveTimeout: 30) { await counter.increment(); return "should-not-run" } as String }
        try await Task.sleep(nanoseconds: 50_000_000); owner.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier); await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value { #expect(isCancellationError(error)) } else { Issue.record("被取消的 owner 应该收到错误") }
        #expect(try await followerTask.value == "shared"); #expect(await counter.value() == 1)
    }

    @Test
    func testDedupAllWaitersCancelledCancelsUnderlyingTask() async throws {
        let gate = TaskExecutionGate(); let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel")); owner.isCancelledRef = NtkCancellableState(); let ownerSnapshot = owner
        var follower = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel")); follower.isCancelledRef = NtkCancellableState(); let followerSnapshot = follower
        let ownerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: ownerSnapshot, identity: identity, effectiveTimeout: 30) { await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "should-not-complete" }) } catch { return .failure(error) } }
        await gate.waitUntilFirstStarted()
        let followerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: followerSnapshot, identity: identity, effectiveTimeout: 30) { return "should-not-run" }) } catch { return .failure(error) } }
        try await Task.sleep(nanoseconds: 50_000_000); follower.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier)
        owner.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: owner.instanceIdentifier) == false)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: follower.instanceIdentifier) == false)
        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value { #expect(isCancellationError(error)) } else { Issue.record("owner 应该收到取消错误") }
        if case .failure(let error) = await followerTask.value { #expect(isCancellationError(error)) } else { Issue.record("follower 应该收到取消错误") }
    }

    @Test
    func testDedupMultipleFollowersCancelOneByOne() async throws {
        let gate = TaskExecutionGate(); let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")); owner.isCancelledRef = NtkCancellableState(); let ownerSnapshot = owner
        var followerA = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")); followerA.isCancelledRef = NtkCancellableState(); let aSnapshot = followerA
        var followerB = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")); followerB.isCancelledRef = NtkCancellableState(); let bSnapshot = followerB
        let ownerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: ownerSnapshot, identity: identity, effectiveTimeout: 30) { await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "result" }) } catch { return .failure(error) } }
        await gate.waitUntilFirstStarted()
        let aTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: aSnapshot, identity: identity, effectiveTimeout: 30) { return "should-not-run" }) } catch { return .failure(error) } }
        let bTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: bSnapshot, identity: identity, effectiveTimeout: 30) { return "should-not-run" }) } catch { return .failure(error) } }
        try await Task.sleep(nanoseconds: 50_000_000)
        followerA.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: followerA.instanceIdentifier)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: owner.instanceIdentifier))
        followerB.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: followerB.instanceIdentifier)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: owner.instanceIdentifier))
        owner.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: owner.instanceIdentifier) == false)
        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value { #expect(isCancellationError(error)) } else { Issue.record("owner 应该收到取消错误") }
        if case .failure(let error) = await aTask.value { #expect(isCancellationError(error)) } else { Issue.record("followerA 应该收到取消错误") }
        if case .failure(let error) = await bTask.value { #expect(isCancellationError(error)) } else { Issue.record("followerB 应该收到取消错误") }
    }

    @Test
    func testMatchingResponseTypeReturnsResultWithoutInvalidTypedResponse() async throws {
        let request = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/matching-response-type"))
        let result: String = try await NtkTaskManager.shared.executeWithDeduplication(request: request, identity: deduplicationIdentity(String.self), effectiveTimeout: 30) { "fallback-result" }
        #expect(result == "fallback-result")
    }

    @Test
    func testDedupFollowerCancelReceivesRequestCancelledNotNetworkError() async throws {
        let gate = TaskExecutionGate(); let identity = deduplicationIdentity(String.self)
        let owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type"))
        var follower = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type")); follower.isCancelledRef = NtkCancellableState(); let followerSnapshot = follower
        let ownerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: owner, identity: identity, effectiveTimeout: 30) { await gate.signalFirstStarted(); await gate.waitForFirstRelease(); throw NtkError.Serialization.invalidDataPayload(recoveredResponse: nil) }) } catch { return .failure(error) } }
        await gate.waitUntilFirstStarted()
        let followerTask = Task { () -> Result<String, Error> in do { return .success(try await NtkTaskManager.shared.executeWithDeduplication(request: followerSnapshot, identity: identity, effectiveTimeout: 30) { return "should-not-run" }) } catch { return .failure(error) } }
        try await Task.sleep(nanoseconds: 50_000_000); follower.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier); await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value {
            if let serialization = error as? NtkError.Serialization,
               case .invalidDataPayload = serialization {
            } else {
                Issue.record("owner 应收到网络错误")
            }
        } else { Issue.record("owner 应该收到错误") }
        if case .failure(let error) = await followerTask.value { #expect(isCancellationError(error)) } else { Issue.record("follower 应该收到错误") }
    }

    @Test
    func timeoutNamespaceAndMissingIdentityKeepExecutionsIsolated() async throws {
        let base = deduplicationIdentity(String.self)
        try await expectTwoExecutions(first: base, second: deduplicationIdentity(String.self, timeout: 31))
        try await expectTwoExecutions(first: base, second: deduplicationIdentity(String.self, namespace: "secondary"))
        try await expectTwoExecutions(first: nil, second: nil)
    }

    @Test
    func cancellationUsesInstanceIdentifierAfterRequestContentChanges() async {
        let gate = TaskExecutionGate()
        var request = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/instance-index"))
        request.isCancelledRef = NtkCancellableState(); let snapshot = request
        let task = Task { try await NtkTaskManager.shared.executeWithDeduplication(request: snapshot, identity: deduplicationIdentity(String.self), effectiveTimeout: 30) {
            await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "result"
        } as String }
        await gate.waitUntilFirstStarted()
        request.addParameter(key: "stable", value: UUID().uuidString)
        request.isCancelledRef?.cancel(); await NtkTaskManager.shared.cancelRequest(instanceIdentifier: request.instanceIdentifier)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: request.instanceIdentifier) == false)
        await gate.releaseFirst()
        do { _ = try await task.value; Issue.record("期望取消错误") } catch { #expect(isCancellationError(error)) }
    }

    @Test
    func cancelAllRequestsRemovesEveryInstanceIndex() async {
        let gate = TaskExecutionGate(); let identity = deduplicationIdentity(String.self)
        let owner = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/cancel-all"))
        let follower = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/cancel-all"))
        let ownerTask = Task { try? await NtkTaskManager.shared.executeWithDeduplication(request: owner, identity: identity, effectiveTimeout: 30) { await gate.signalFirstStarted(); await gate.waitForFirstRelease(); return "result" } as String }
        await gate.waitUntilFirstStarted()
        let followerTask = Task { try? await NtkTaskManager.shared.executeWithDeduplication(request: follower, identity: identity, effectiveTimeout: 30) { return "should-not-run" } as String }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await NtkTaskManager.shared.cancelAllRequests()
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: owner.instanceIdentifier) == false)
        #expect(await NtkTaskManager.shared.isRequestActive(instanceIdentifier: follower.instanceIdentifier) == false)
        await gate.releaseFirst(); _ = await ownerTask.value; _ = await followerTask.value
    }
}

private func deduplicationIdentity<Response: Sendable>(
    _ type: Response.Type,
    digest: String = "ntk-identity-v2-test",
    timeout: TimeInterval = 30,
    namespace: String = "default"
) -> NtkDeduplicationIdentity {
    NtkDeduplicationIdentity(requestIdentity: NtkRequestIdentity(digest: digest), responseType: ObjectIdentifier(type), effectiveTimeout: timeout, namespace: namespace)
}

private func expectTwoExecutions(first: NtkDeduplicationIdentity?, second: NtkDeduplicationIdentity?) async throws {
    let counter = ExecutionCounter()
    let firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/isolation-matrix"))
    let secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/isolation-matrix"))
    async let firstValue: String = NtkTaskManager.shared.executeWithDeduplication(request: firstRequest, identity: first, effectiveTimeout: first?.effectiveTimeout ?? 30) {
        await counter.increment(); try await Task.sleep(nanoseconds: 20_000_000); return "first"
    }
    async let secondValue: String = NtkTaskManager.shared.executeWithDeduplication(request: secondRequest, identity: second, effectiveTimeout: second?.effectiveTimeout ?? 30) {
        await counter.increment(); return "second"
    }
    _ = try await (firstValue, secondValue)
    #expect(await counter.value() == 2)
}

private struct TaskManagerDummyRequest: iNtkRequest { let path: String }

private actor TaskExecutionGate {
    private var firstStarted = false; private var secondStarted = false
    private var firstReleased = false; private var secondReleased = false
    private var firstStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstReleaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondReleaseWaiters: [CheckedContinuation<Void, Never>] = []
    func signalFirstStarted() { firstStarted = true; let waiters = firstStartWaiters; firstStartWaiters.removeAll(); for waiter in waiters { waiter.resume() } }
    func signalSecondStarted() { secondStarted = true; let waiters = secondStartWaiters; secondStartWaiters.removeAll(); for waiter in waiters { waiter.resume() } }
    func waitUntilFirstStarted() async { if firstStarted { return }; await withCheckedContinuation { firstStartWaiters.append($0) } }
    func waitUntilSecondStarted() async { if secondStarted { return }; await withCheckedContinuation { secondStartWaiters.append($0) } }
    func waitForFirstRelease() async { if firstReleased { return }; await withCheckedContinuation { firstReleaseWaiters.append($0) } }
    func waitForSecondRelease() async { if secondReleased { return }; await withCheckedContinuation { secondReleaseWaiters.append($0) } }
    func releaseFirst() { firstReleased = true; let waiters = firstReleaseWaiters; firstReleaseWaiters.removeAll(); for waiter in waiters { waiter.resume() } }
    func releaseSecond() { secondReleased = true; let waiters = secondReleaseWaiters; secondReleaseWaiters.removeAll(); for waiter in waiters { waiter.resume() } }
}

private actor ExecutionCounter { private var count = 0; func increment() { count += 1 }; func value() -> Int { count } }
private func isCancellationError(_ error: Error) -> Bool { error is CancellationError || ((error as? NtkError).map { if case .requestCancelled = $0 { return true }; return false } ?? false) }
private func requireActor<A: Actor>(_ value: A) {}
