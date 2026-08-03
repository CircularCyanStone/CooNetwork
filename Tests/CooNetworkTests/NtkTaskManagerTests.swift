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
        var firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count")
        )
        firstRequest.disableDeduplication()
        var secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count")
        )
        secondRequest.disableDeduplication()

        let firstTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: firstRequest,
                identity: nil,
                effectiveTimeout: 30
            ) {
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "first"
            } as String
        }
        #expect(await waitUntil("第一个独立请求开始") { await gate.firstStarted() })

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: secondRequest,
                identity: nil,
                effectiveTimeout: 30
            ) {
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return "second"
            } as String
        }
        #expect(await waitUntil("第二个独立请求开始") { await gate.secondStarted() })

        #expect(await isActive(firstRequest))
        await gate.releaseFirst()
        #expect(try await firstTask.value == "first")
        #expect(await isActive(firstRequest) == false)
        #expect(await isActive(secondRequest))

        await gate.releaseSecond()
        #expect(try await secondTask.value == "second")
        #expect(await isActive(secondRequest) == false)
    }

    @Test
    func testDifferentResponseTypesShouldNotDedup() async throws {
        let counter = ExecutionCounter()
        let gate = TaskExecutionGate()
        let stringRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/type-isolation")
        )
        let intRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/type-isolation")
        )

        let stringTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: stringRequest,
                identity: deduplicationIdentity(String.self),
                effectiveTimeout: 30
            ) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "string-result"
            } as String
        }
        #expect(await waitUntil("String 请求开始") { await gate.firstStarted() })

        let intTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: intRequest,
                identity: deduplicationIdentity(Int.self),
                effectiveTimeout: 30
            ) {
                await counter.increment()
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return 42
            } as Int
        }
        #expect(await waitUntil("Int 请求开始") { await gate.secondStarted() })

        #expect(await isActive(stringRequest))
        #expect(await isActive(intRequest))
        await gate.releaseFirst()
        await gate.releaseSecond()
        #expect(try await stringTask.value == "string-result")
        #expect(try await intTask.value == 42)
        #expect(await counter.value() == 2)
    }

    @Test
    func testCancelRequestCancelsOnlyCurrentDisabledDeduplicationTask() async throws {
        let gate = TaskExecutionGate()
        var firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel")
        )
        firstRequest.disableDeduplication()
        firstRequest.isCancelledRef = NtkCancellableState()
        var secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel")
        )
        secondRequest.disableDeduplication()
        let firstSnapshot = firstRequest

        let firstTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: firstSnapshot,
                    identity: nil,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    try await Task.sleep(nanoseconds: 300_000_000)
                    return "first"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        let secondTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: secondRequest,
                    identity: nil,
                    effectiveTimeout: 30
                ) {
                    await gate.signalSecondStarted()
                    await gate.waitForSecondRelease()
                    try Task.checkCancellation()
                    return "second"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("第一个独立取消请求开始") { await gate.firstStarted() })
        #expect(await waitUntil("第二个独立取消请求开始") { await gate.secondStarted() })

        firstRequest.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(
            instanceIdentifier: firstRequest.instanceIdentifier
        )
        await gate.releaseSecond()

        if case .failure(let error) = await firstTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("第一个非去重请求应被取消")
        }
        if case .failure = await secondTask.value {
            Issue.record("第二个非去重请求不应被取消")
        }
        #expect(await isActive(secondRequest) == false)
    }

    @Test
    func testEnabledDeduplicationSharesSingleExecution() async throws {
        let counter = ExecutionCounter()
        let gate = TaskExecutionGate()
        let firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared")
        )
        let secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared")
        )
        let identity = deduplicationIdentity(String.self)

        let firstTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: firstRequest,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "shared"
            } as String
        }
        #expect(await waitUntil("去重 owner 开始") { await gate.firstStarted() })

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: secondRequest,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await counter.increment()
                return "should-not-run"
            } as String
        }
        #expect(await waitUntilActive(secondRequest, description: "去重 follower 已登记"))

        await gate.releaseFirst()
        #expect(try await firstTask.value == "shared")
        #expect(try await secondTask.value == "shared")
        #expect(await counter.value() == 1)
    }

    @Test
    func testCancelAndReenterDedupRequestKeepsNewTaskMapped() async throws {
        let gate = TaskExecutionGate()
        var request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter")
        )
        request.isCancelledRef = NtkCancellableState()
        let snapshot = request
        let identity = deduplicationIdentity(String.self)

        let firstTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: snapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "cancelled-first"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("初始去重请求开始") { await gate.firstStarted() })

        request.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: request.instanceIdentifier)

        let newRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter")
        )
        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: newRequest,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return "second"
            } as String
        }
        #expect(await waitUntil("重入请求开始") { await gate.secondStarted() })
        #expect(await isActive(newRequest))

        await gate.releaseFirst()
        _ = await firstTask.value
        #expect(await isActive(newRequest))
        await gate.releaseSecond()
        #expect(try await secondTask.value == "second")
    }

    // 场景：取消 follower 不影响 owner 和后续 follower。
    @Test
    func testDedupFollowerCancelDoesNotAffectSharedWaiting() async throws {
        let gate = TaskExecutionGate()
        let counter = ExecutionCounter()
        let identity = deduplicationIdentity(String.self)
        let owner = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel")
        )
        var follower = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel")
        )
        follower.isCancelledRef = NtkCancellableState()
        let followerSnapshot = follower
        let another = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel")
        )

        let ownerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: owner,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "shared"
            } as String
        }
        #expect(await waitUntil("owner 开始") { await gate.firstStarted() })

        let followerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await counter.increment()
                    return "should-not-run"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntilActive(follower, description: "待取消 follower 已登记"))

        follower.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier)
        let anotherTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: another,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await counter.increment()
                return "should-not-run"
            } as String
        }
        #expect(await waitUntilActive(another, description: "后续 follower 已登记"))

        await gate.releaseFirst()
        #expect(try await ownerTask.value == "shared")
        if case .failure(let error) = await followerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("被取消的 follower 应该收到取消错误")
        }
        #expect(try await anotherTask.value == "shared")
        #expect(await counter.value() == 1)
    }

    // 场景：取消 owner 不影响已登记 follower。
    @Test
    func testDedupOwnerCancelDoesNotAffectFollower() async throws {
        let gate = TaskExecutionGate()
        let counter = ExecutionCounter()
        let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel")
        )
        owner.isCancelledRef = NtkCancellableState()
        let ownerSnapshot = owner
        let follower = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel")
        )

        let ownerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await counter.increment()
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "shared"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        let ownerCompletion = TaskCompletionSignal()
        Task {
            _ = await ownerTask.value
            await ownerCompletion.signal()
        }
        #expect(await waitUntil("owner 开始") { await gate.firstStarted() })

        let followerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: follower,
                identity: identity,
                effectiveTimeout: 30
            ) {
                await counter.increment()
                return "should-not-run"
            } as String
        }
        #expect(await waitUntilActive(follower, description: "owner 取消前 follower 已登记"))

        owner.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier)

        #expect(await waitUntil("owner 在底层任务未释放前已取消返回") {
            await ownerCompletion.completed()
        })
        #expect(await isActive(follower))
        #expect(await counter.value() == 1)

        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("被取消的 owner 应该收到取消错误")
        }
        #expect(try await followerTask.value == "shared")
        #expect(await counter.value() == 1)
    }

    // 场景：最后一个等待者取消时，底层任务随之取消。
    @Test
    func testDedupAllWaitersCancelledCancelsUnderlyingTask() async throws {
        let gate = TaskExecutionGate()
        let cancellationSignal = TaskCancellationSignal()
        let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel")
        )
        owner.isCancelledRef = NtkCancellableState()
        var follower = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel")
        )
        follower.isCancelledRef = NtkCancellableState()
        let ownerSnapshot = owner
        let followerSnapshot = follower

        let ownerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    return try await withTaskCancellationHandler {
                        await gate.waitForFirstRelease()
                        try Task.checkCancellation()
                        return "should-not-complete"
                    } onCancel: {
                        Task {
                            await cancellationSignal.signal()
                        }
                    }
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("owner 开始") { await gate.firstStarted() })

        let followerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    return "should-not-run"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntilActive(follower, description: "全部取消前 follower 已登记"))

        follower.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier)
        owner.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier)

        #expect(await waitUntil("最后一个 waiter 取消后底层任务收到取消") {
            await cancellationSignal.cancelled()
        })
        #expect(await isActive(owner) == false)
        #expect(await isActive(follower) == false)

        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("owner 应该收到取消错误")
        }
        if case .failure(let error) = await followerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("follower 应该收到取消错误")
        }
    }

    // 场景：多个 follower 逐个取消，只在 owner 取消后终止底层任务。
    @Test
    func testDedupMultipleFollowersCancelOneByOne() async throws {
        let gate = TaskExecutionGate()
        let identity = deduplicationIdentity(String.self)
        var owner = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")
        )
        owner.isCancelledRef = NtkCancellableState()
        var followerA = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")
        )
        followerA.isCancelledRef = NtkCancellableState()
        var followerB = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel")
        )
        followerB.isCancelledRef = NtkCancellableState()
        let ownerSnapshot = owner
        let followerASnapshot = followerA
        let followerBSnapshot = followerB

        let ownerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "result"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("owner 开始") { await gate.firstStarted() })

        let followerATask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerASnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    return "should-not-run"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntilActive(followerA, description: "followerA 已登记"))

        let followerBTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerBSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    return "should-not-run"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntilActive(followerB, description: "followerB 已登记"))

        followerA.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: followerA.instanceIdentifier)
        #expect(await isActive(owner))
        followerB.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: followerB.instanceIdentifier)
        #expect(await isActive(owner))
        owner.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: owner.instanceIdentifier)
        #expect(await isActive(owner) == false)

        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("owner 应该收到取消错误")
        }
        if case .failure(let error) = await followerATask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("followerA 应该收到取消错误")
        }
        if case .failure(let error) = await followerBTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("followerB 应该收到取消错误")
        }
    }

    @Test
    func testMatchingResponseTypeReturnsResultWithoutInvalidTypedResponse() async throws {
        let request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/matching-response-type")
        )
        let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
            request: request,
            identity: deduplicationIdentity(String.self),
            effectiveTimeout: 30
        ) {
            "fallback-result"
        }
        #expect(result == "fallback-result")
    }

    // 场景：已取消 follower 在底层网络失败时仍收到取消错误。
    @Test
    func testDedupFollowerCancelReceivesRequestCancelledNotNetworkError() async throws {
        let gate = TaskExecutionGate()
        let identity = deduplicationIdentity(String.self)
        let owner = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type")
        )
        var follower = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type")
        )
        follower.isCancelledRef = NtkCancellableState()
        let followerSnapshot = follower

        let ownerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: owner,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    throw NtkError.Serialization.invalidDataPayload(recoveredResponse: nil)
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("owner 开始") { await gate.firstStarted() })

        let followerTask = Task { () -> Result<String, Error> in
            do {
                let result: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerSnapshot,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    return "should-not-run"
                }
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntilActive(follower, description: "网络错误前 follower 已登记"))

        follower.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: follower.instanceIdentifier)
        await gate.releaseFirst()
        if case .failure(let error) = await ownerTask.value {
            if let serialization = error as? NtkError.Serialization,
               case .invalidDataPayload = serialization {
            } else {
                Issue.record("owner 应收到网络错误")
            }
        } else {
            Issue.record("owner 应该收到错误")
        }
        if case .failure(let error) = await followerTask.value {
            #expect(isCancellationError(error))
        } else {
            Issue.record("follower 应该收到取消错误")
        }
    }

    @Test
    func timeoutNamespaceAndMissingIdentityKeepExecutionsIsolated() async throws {
        let base = deduplicationIdentity(String.self)
        try await expectTwoExecutions(
            first: base,
            second: deduplicationIdentity(String.self, timeout: 31)
        )
        try await expectTwoExecutions(
            first: base,
            second: deduplicationIdentity(String.self, namespace: "secondary")
        )
        try await expectTwoExecutions(first: nil, second: nil)
    }

    @Test
    func sharedIdentityUsesIdentityEffectiveTimeout() async {
        let gate = TaskExecutionGate()
        let request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/identity-timeout")
        )
        let identity = deduplicationIdentity(String.self, timeout: 0.03)
        let task = Task { () -> Result<String, Error> in
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: request,
                    identity: identity,
                    effectiveTimeout: 1
                ) {
                    await gate.signalFirstStarted()
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    return "unexpected"
                }
                return .success(value)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("identity timeout 执行开始") { await gate.firstStarted() })

        if case .failure(let error) = await task.value {
            #expect(isFrameworkTimeout(error, expected: identity.effectiveTimeout))
        } else {
            Issue.record("identity timeout 应抛出 framework timeout")
        }
    }

    @Test
    func missingIdentityUsesExplicitEffectiveTimeout() async {
        let gate = TaskExecutionGate()
        let request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/explicit-timeout")
        )
        let effectiveTimeout: TimeInterval = 0.03
        let task = Task { () -> Result<String, Error> in
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: request,
                    identity: nil,
                    effectiveTimeout: effectiveTimeout
                ) {
                    await gate.signalFirstStarted()
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    return "unexpected"
                }
                return .success(value)
            } catch {
                return .failure(error)
            }
        }
        #expect(await waitUntil("显式 timeout 执行开始") { await gate.firstStarted() })

        if case .failure(let error) = await task.value {
            #expect(isFrameworkTimeout(error, expected: effectiveTimeout))
        } else {
            Issue.record("显式 timeout 应抛出 framework timeout")
        }
    }

    @Test
    func cancellationUsesInstanceIdentifierAfterRequestContentChanges() async {
        let gate = TaskExecutionGate()
        var request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/instance-index")
        )
        request.isCancelledRef = NtkCancellableState()
        let snapshot = request
        let task = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: snapshot,
                identity: deduplicationIdentity(String.self),
                effectiveTimeout: 30
            ) {
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "result"
            } as String
        }
        #expect(await waitUntil("实例索引请求开始") { await gate.firstStarted() })

        request.addParameter(key: "stable", value: UUID().uuidString)
        request.isCancelledRef?.cancel()
        await NtkTaskManager.shared.cancelRequest(instanceIdentifier: request.instanceIdentifier)
        #expect(await isActive(request) == false)
        await gate.releaseFirst()
        do {
            _ = try await task.value
            Issue.record("期望取消错误")
        } catch {
            #expect(isCancellationError(error))
        }
    }

    @Test
    func cancelAllRequestsRemovesEveryInstanceIndex() async {
        await NtkTaskManagerTestIsolation.shared.withLock {
            let gate = TaskExecutionGate()
            let identity = deduplicationIdentity(String.self)
            let owner = NtkMutableRequest(
                TaskManagerDummyRequest(path: "/task-manager/cancel-all")
            )
            let follower = NtkMutableRequest(
                TaskManagerDummyRequest(path: "/task-manager/cancel-all")
            )
            let ownerTask = Task {
                try? await NtkTaskManager.shared.executeWithDeduplication(
                    request: owner,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "result"
                } as String
            }
            #expect(await waitUntil("cancelAll owner 开始") { await gate.firstStarted() })

            let followerTask = Task {
                try? await NtkTaskManager.shared.executeWithDeduplication(
                    request: follower,
                    identity: identity,
                    effectiveTimeout: 30
                ) {
                    return "should-not-run"
                } as String
            }
            #expect(await waitUntilActive(follower, description: "cancelAll follower 已登记"))

            await NtkTaskManager.shared.cancelAllRequests()
            #expect(await isActive(owner) == false)
            #expect(await isActive(follower) == false)
            await gate.releaseFirst()
            _ = await ownerTask.value
            _ = await followerTask.value
        }
    }
}

private func deduplicationIdentity<Response: Sendable>(
    _ type: Response.Type,
    digest: String = "ntk-identity-v2-test",
    timeout: TimeInterval = 30,
    namespace: String = "default"
) -> NtkDeduplicationIdentity {
    NtkDeduplicationIdentity(
        requestIdentity: NtkRequestIdentity(digest: digest),
        responseType: ObjectIdentifier(type),
        effectiveTimeout: timeout,
        namespace: namespace
    )
}

private func expectTwoExecutions(
    first: NtkDeduplicationIdentity?,
    second: NtkDeduplicationIdentity?
) async throws {
    let counter = ExecutionCounter()
    let gate = TaskExecutionGate()
    let firstRequest = NtkMutableRequest(
        TaskManagerDummyRequest(path: "/task-manager/isolation-matrix")
    )
    let secondRequest = NtkMutableRequest(
        TaskManagerDummyRequest(path: "/task-manager/isolation-matrix")
    )

    let firstTask = Task {
        try await NtkTaskManager.shared.executeWithDeduplication(
            request: firstRequest,
            identity: first,
            effectiveTimeout: first?.effectiveTimeout ?? 30
        ) {
            await counter.increment()
            await gate.signalFirstStarted()
            await gate.waitForFirstRelease()
            return "first"
        } as String
    }
    #expect(await waitUntil("隔离矩阵第一条执行开始") { await gate.firstStarted() })

    let secondTask = Task {
        try await NtkTaskManager.shared.executeWithDeduplication(
            request: secondRequest,
            identity: second,
            effectiveTimeout: second?.effectiveTimeout ?? 30
        ) {
            await counter.increment()
            await gate.signalSecondStarted()
            await gate.waitForSecondRelease()
            return "second"
        } as String
    }
    #expect(await waitUntil("隔离矩阵第二条执行开始") {
        await gate.secondStarted()
    })
    #expect(await waitUntilCount(
        counter,
        expected: 2,
        description: "隔离矩阵两条执行均已开始"
    ))

    await gate.releaseFirst()
    await gate.releaseSecond()
    _ = try await (firstTask.value, secondTask.value)
    #expect(await counter.value() == 2)
}

private func waitUntilActive(
    _ request: NtkMutableRequest,
    description: String
) async -> Bool {
    await waitUntil(description) {
        await NtkTaskManager.shared.isRequestActive(
            instanceIdentifier: request.instanceIdentifier
        )
    }
}

private func waitUntilCount(
    _ counter: ExecutionCounter,
    expected: Int,
    description: String
) async -> Bool {
    await waitUntil(description) {
        await counter.value() == expected
    }
}

private func isActive(_ request: NtkMutableRequest) async -> Bool {
    await NtkTaskManager.shared.isRequestActive(instanceIdentifier: request.instanceIdentifier)
}

private func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let pollingInterval: UInt64 = 10_000_000
    let attempts = Int(timeoutNanoseconds / pollingInterval)
    for _ in 0..<attempts {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: pollingInterval)
    }
    Issue.record("等待超时：\(description)")
    return false
}

private func isFrameworkTimeout(_ error: Error, expected: TimeInterval) -> Bool {
    guard let ntkError = error as? NtkError else {
        return false
    }
    if case let .requestTimeout(reason) = ntkError {
        return reason.source == "Framework" && reason.detail == "\(expected)s"
    }
    return false
}

private struct TaskManagerDummyRequest: iNtkRequest {
    let path: String
}

private actor TaskExecutionGate {
    private var didFirstStart = false
    private var didSecondStart = false
    private var firstReleased = false
    private var secondReleased = false
    private var firstReleaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    func signalFirstStarted() {
        didFirstStart = true
    }

    func signalSecondStarted() {
        didSecondStart = true
    }

    func firstStarted() -> Bool {
        didFirstStart
    }

    func secondStarted() -> Bool {
        didSecondStart
    }

    func waitForFirstRelease() async {
        if firstReleased { return }
        await withCheckedContinuation { continuation in
            firstReleaseWaiters.append(continuation)
        }
    }

    func waitForSecondRelease() async {
        if secondReleased { return }
        await withCheckedContinuation { continuation in
            secondReleaseWaiters.append(continuation)
        }
    }

    func releaseFirst() {
        firstReleased = true
        let waiters = firstReleaseWaiters
        firstReleaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func releaseSecond() {
        secondReleased = true
        let waiters = secondReleaseWaiters
        secondReleaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor ExecutionCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private actor TaskCompletionSignal {
    private var didComplete = false

    func signal() {
        didComplete = true
    }

    func completed() -> Bool {
        didComplete
    }
}

private actor TaskCancellationSignal {
    private var didCancel = false

    func signal() {
        didCancel = true
    }

    func cancelled() -> Bool {
        didCancel
    }
}

private func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }
    guard let ntkError = error as? NtkError else {
        return false
    }
    if case .requestCancelled = ntkError {
        return true
    }
    return false
}

private func requireActor<A: Actor>(_ value: A) {}
