import Foundation
import Testing

@testable import CooNetwork

@Suite(.serialized)
struct NtkTaskManagerTests {

    @Test
    @NtkActor
    func testDisabledDeduplicationKeepsLatestTaskMapped() async throws {
        let gate = TaskExecutionGate()

        var firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
        firstRequest.responseType = "String"
        firstRequest.disableDeduplication()

        var secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
        secondRequest.responseType = "String"
        secondRequest.disableDeduplication()

        let firstTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: firstRequest) {
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "first"
            } as String
        }

        await gate.waitUntilFirstStarted()

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: secondRequest) {
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return "second"
            } as String
        }

        await gate.waitUntilSecondStarted()

        let activeBeforeRelease = NtkTaskManager.shared.isRequestActive(request: firstRequest)
        #expect(activeBeforeRelease == true)

        await gate.releaseFirst()
        let firstValue = try await firstTask.value
        #expect(firstValue == "first")

        let activeAfterFirstFinished = NtkTaskManager.shared.isRequestActive(request: firstRequest)
        #expect(activeAfterFirstFinished == true)

        await gate.releaseSecond()
        let secondValue = try await secondTask.value
        #expect(secondValue == "second")

        let activeAfterAllFinished = NtkTaskManager.shared.isRequestActive(request: firstRequest)
        #expect(activeAfterAllFinished == false)
    }

    @Test
    @NtkActor
    func testDifferentResponseTypesShouldNotDedup() async throws {
        let counter = ExecutionCounter()
        let gate = TaskExecutionGate()

        // 两个请求路径相同（baseRequestId 相同），但返回类型不同
        var stringRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/type-isolation"))
        stringRequest.responseType = "String"

        var intRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/type-isolation"))
        intRequest.responseType = "Int"

        // 启动 String 类型的请求，并让它挂起
        let stringTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: stringRequest
            ) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "string-result"
            } as String
        }

        await gate.waitUntilFirstStarted()

        // 启动 Int 类型的请求，它应该不会被去重，而是直接执行
        let intTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: intRequest
            ) {
                await counter.increment()
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return 42
            } as Int
        }

        // 确保第二个任务也启动了（说明没有被阻塞等待第一个任务）
        await gate.waitUntilSecondStarted()

        // 验证两个请求都处于活跃状态
        let stringActive = NtkTaskManager.shared.isRequestActive(request: stringRequest)
        let intActive = NtkTaskManager.shared.isRequestActive(request: intRequest)
        #expect(stringActive == true)
        #expect(intActive == true)

        // 释放所有任务
        await gate.releaseFirst()
        await gate.releaseSecond()

        let stringResult = try await stringTask.value
        let intResult = try await intTask.value
        let executionCount = await counter.value()

        #expect(stringResult == "string-result")
        #expect(intResult == 42)
        // 两个任务都应该执行了闭包
        #expect(executionCount == 2)
    }

    @Test
    @NtkActor
    func testCancelRequestCancelsOnlyCurrentDisabledDeduplicationTask() async throws {
        let gate = TaskExecutionGate()

        var firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        firstRequest.responseType = "String"
        firstRequest.disableDeduplication()

        var secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        secondRequest.responseType = "String"
        secondRequest.disableDeduplication()

        let firstTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: firstRequest
                ) {
                    await gate.signalFirstStarted()
                    try await Task.sleep(nanoseconds: 300_000_000)
                    return "first"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        let secondTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: secondRequest
                ) {
                    await gate.signalSecondStarted()
                    await gate.waitForSecondRelease()
                    try Task.checkCancellation()
                    return "second"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()
        await gate.waitUntilSecondStarted()

        NtkTaskManager.shared.cancelRequest(request: firstRequest)

        await gate.releaseSecond()

        let firstResult = await firstTask.value
        let secondResult = await secondTask.value

        if case .success = firstResult {
            Issue.record("第一个非去重请求应被取消")
        } else if case .failure(let error) = firstResult {
            let isExpectedCancellation = isCancellationError(error)
            #expect(isExpectedCancellation == true)
        }
        if case .failure = secondResult {
            Issue.record("第二个非去重请求不应被取消")
        }

        if case .success(let value) = secondResult {
            #expect(value == "second")
        }

        let activeAfterCancel = NtkTaskManager.shared.isRequestActive(request: secondRequest)
        #expect(activeAfterCancel == false)
    }

    @Test
    @NtkActor
    func testEnabledDeduplicationSharesSingleExecution() async throws {
        let counter = ExecutionCounter()
        let gate = TaskExecutionGate()

        var firstRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))
        firstRequest.responseType = "String"
        var secondRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))
        secondRequest.responseType = "String"

        let firstTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: firstRequest) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "shared"
            } as String
        }

        await gate.waitUntilFirstStarted()

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: secondRequest) {
                await counter.increment()
                return "should-not-run"
            } as String
        }

        let activeDuringDedup = NtkTaskManager.shared.isRequestActive(request: firstRequest)
        #expect(activeDuringDedup == true)

        await gate.releaseFirst()
        let firstValue = try await firstTask.value
        let secondValue = try await secondTask.value
        let executionCount = await counter.value()

        #expect(firstValue == "shared")
        #expect(secondValue == "shared")
        #expect(executionCount == 1)
    }

    @Test
    @NtkActor
    func testCancelAndReenterDedupRequestKeepsNewTaskMapped() async throws {
        let gate = TaskExecutionGate()
        var request = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter"))
        request.responseType = "String"
        request.isCancelledRef = NtkCancellableState()

        let firstTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: request
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "cancelled-first"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()

        // 取消请求：设置 isCancelledRef + cancelRequest
        request.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: request)

        // 创建新的请求实例（模拟重新发起）
        var newRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter"))
        newRequest.responseType = "String"

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: newRequest) {
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return "second"
            } as String
        }

        await gate.waitUntilSecondStarted()
        #expect(NtkTaskManager.shared.isRequestActive(request: newRequest) == true)

        await gate.releaseFirst()
        _ = await firstTask.value

        #expect(NtkTaskManager.shared.isRequestActive(request: newRequest) == true)

        await gate.releaseSecond()
        let secondValue = try await secondTask.value
        #expect(secondValue == "second")
    }

    // MARK: - 取消隔离测试（新增 + 恢复）

    /// 场景 2：follower 取消，owner 和其他 follower 继续正常拿到结果
    @Test
    @NtkActor
    func testDedupFollowerCancelDoesNotAffectSharedWaiting() async throws {
        let gate = TaskExecutionGate()
        let counter = ExecutionCounter()

        var ownerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        ownerRequest.responseType = "String"

        var followerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        followerRequest.responseType = "String"
        followerRequest.isCancelledRef = NtkCancellableState()

        var anotherFollowerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        anotherFollowerRequest.responseType = "String"

        #expect(ownerRequest.instanceIdentifier != followerRequest.instanceIdentifier)

        // owner 发起请求
        let ownerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: ownerRequest) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "shared"
            } as String
        }

        await gate.waitUntilFirstStarted()

        // follower 加入（会被去重）
        let followerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerRequest
                ) {
                    await counter.increment()
                    return "should-not-run"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        // 等待 follower 进入等待状态
        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消 follower
        followerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: followerRequest)

        // 另一个 follower 在取消后加入
        let anotherFollowerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(
                request: anotherFollowerRequest
            ) {
                await counter.increment()
                return "should-not-run"
            } as String
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        // 释放底层任务
        await gate.releaseFirst()

        let ownerValue = try await ownerTask.value
        let followerResult = await followerTask.value
        let anotherFollowerValue = try await anotherFollowerTask.value
        let executionCount = await counter.value()

        // owner 正常拿到结果
        #expect(ownerValue == "shared")
        // 另一个 follower 也正常拿到结果
        #expect(anotherFollowerValue == "shared")
        // 被取消的 follower 应该收到取消错误
        if case .failure(let error) = followerResult {
            #expect(isCancellationError(error))
        } else {
            Issue.record("被取消的 follower 应该收到错误")
        }
        // 只执行了一次闭包
        #expect(executionCount == 1)
    }

    /// 场景 3：owner 取消，follower 继续正常拿到结果
    @Test
    @NtkActor
    func testDedupOwnerCancelDoesNotAffectFollower() async throws {
        let gate = TaskExecutionGate()
        let counter = ExecutionCounter()

        var ownerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel"))
        ownerRequest.responseType = "String"
        ownerRequest.isCancelledRef = NtkCancellableState()

        var followerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-owner-cancel"))
        followerRequest.responseType = "String"

        // owner 发起请求
        let ownerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerRequest
                ) {
                    await counter.increment()
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "shared"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()

        // follower 加入
        let followerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: followerRequest) {
                await counter.increment()
                return "should-not-run"
            } as String
        }

        // 等待 follower 进入等待状态
        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消 owner
        ownerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: ownerRequest)

        // 释放底层任务
        await gate.releaseFirst()

        let ownerResult = await ownerTask.value
        let followerValue = try await followerTask.value
        let executionCount = await counter.value()

        // owner 应该收到取消错误
        if case .failure(let error) = ownerResult {
            #expect(isCancellationError(error))
        } else {
            Issue.record("被取消的 owner 应该收到错误")
        }
        // follower 正常拿到结果
        #expect(followerValue == "shared")
        // 只执行了一次闭包
        #expect(executionCount == 1)
    }

    /// 场景 4：所有等待者取消后，底层 Task 也被取消
    @Test
    @NtkActor
    func testDedupAllWaitersCancelledCancelsUnderlyingTask() async throws {
        let gate = TaskExecutionGate()
        let counter = ExecutionCounter()

        var ownerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel"))
        ownerRequest.responseType = "String"
        ownerRequest.isCancelledRef = NtkCancellableState()

        var followerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-all-cancel"))
        followerRequest.responseType = "String"
        followerRequest.isCancelledRef = NtkCancellableState()

        // owner 发起请求
        let ownerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerRequest
                ) {
                    await counter.increment()
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "should-not-complete"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()

        // follower 加入
        let followerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerRequest
                ) {
                    await counter.increment()
                    return "should-not-run"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消 follower
        followerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: followerRequest)

        // 取消 owner → totalWaiters = 0 → 底层 Task 被 cancel
        ownerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: ownerRequest)

        // entry 应该已被移除
        #expect(NtkTaskManager.shared.isRequestActive(request: ownerRequest) == false)

        // 释放 gate 让底层任务能完成（如果还在运行的话）
        await gate.releaseFirst()

        let ownerResult = await ownerTask.value
        let followerResult = await followerTask.value

        // 两者都应该收到取消错误
        if case .failure(let error) = ownerResult {
            #expect(isCancellationError(error))
        } else {
            Issue.record("owner 应该收到取消错误")
        }
        if case .failure(let error) = followerResult {
            #expect(isCancellationError(error))
        } else {
            Issue.record("follower 应该收到取消错误")
        }
    }

    /// 场景 4 变体：多个 follower 逐个取消，最后一个取消时底层才取消
    @Test
    @NtkActor
    func testDedupMultipleFollowersCancelOneByOne() async throws {
        let gate = TaskExecutionGate()

        var ownerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel"))
        ownerRequest.responseType = "String"
        ownerRequest.isCancelledRef = NtkCancellableState()

        var followerA = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel"))
        followerA.responseType = "String"
        followerA.isCancelledRef = NtkCancellableState()

        var followerB = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-multi-cancel"))
        followerB.responseType = "String"
        followerB.isCancelledRef = NtkCancellableState()

        // owner 发起
        let ownerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerRequest
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    return "result"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()

        // followerA 和 followerB 加入
        let followerATask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerA
                ) { return "should-not-run" }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        let followerBTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerB
                ) { return "should-not-run" }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消 followerA → 底层 Task 不应被取消（还有 owner + followerB）
        followerA.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: followerA)
        #expect(NtkTaskManager.shared.isRequestActive(request: ownerRequest) == true)

        // 取消 followerB → 底层 Task 不应被取消（还有 owner）
        followerB.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: followerB)
        #expect(NtkTaskManager.shared.isRequestActive(request: ownerRequest) == true)

        // 取消 owner → totalWaiters = 0 → 底层 Task 被取消
        ownerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: ownerRequest)
        #expect(NtkTaskManager.shared.isRequestActive(request: ownerRequest) == false)

        // 释放 gate
        await gate.releaseFirst()

        let ownerResult = await ownerTask.value
        let followerAResult = await followerATask.value
        let followerBResult = await followerBTask.value

        if case .success = ownerResult {
            Issue.record("owner 应该收到取消错误")
        }
        if case .success = followerAResult {
            Issue.record("followerA 应该收到取消错误")
        }
        if case .success = followerBResult {
            Issue.record("followerB 应该收到取消错误")
        }
    }

    /// 场景 8：follower 被取消，底层 Task 抛网络错误时，follower 收到 requestCancelled
    @Test
    @NtkActor
    func testDedupFollowerCancelReceivesRequestCancelledNotNetworkError() async throws {
        let gate = TaskExecutionGate()

        var ownerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type"))
        ownerRequest.responseType = "String"

        var followerRequest = NtkMutableRequest(
            TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-error-type"))
        followerRequest.responseType = "String"
        followerRequest.isCancelledRef = NtkCancellableState()

        // owner 发起请求，最终会抛出网络错误
        let ownerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: ownerRequest
                ) {
                    await gate.signalFirstStarted()
                    await gate.waitForFirstRelease()
                    // 模拟网络错误
                    throw NtkError.serialization(.init(reason: .dataMissing, context: .init(stage: .data)))
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await gate.waitUntilFirstStarted()

        // follower 加入
        let followerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(
                    request: followerRequest
                ) {
                    return "should-not-run"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消 follower
        followerRequest.isCancelledRef?.cancel()
        NtkTaskManager.shared.cancelRequest(request: followerRequest)

        // 释放底层任务（会抛 responseBodyEmpty）
        await gate.releaseFirst()

        let ownerResult = await ownerTask.value
        let followerResult = await followerTask.value

        // owner 收到的是网络错误（未被取消）
        if case .failure(let error) = ownerResult {
            if let ntkError = error as? NtkError,
               case let .serialization(failure) = ntkError,
               failure.reason == SerializationFailure.Reason.dataMissing {
                // 预期行为
            } else {
                Issue.record("owner 应该收到 serialization.dataMissing，实际收到: \(error)")
            }
        } else {
            Issue.record("owner 应该收到错误")
        }

        // follower 收到的是 requestCancelled（而非 responseBodyEmpty）
        if case .failure(let error) = followerResult {
            if let ntkError = error as? NtkError,
               case let .response(failure) = ntkError,
               failure.reason == .cancelled {
                // 预期行为：已取消的 follower 收到 response.cancelled
            } else {
                Issue.record("被取消的 follower 应该收到 response.cancelled，实际收到: \(error)")
            }
        } else {
            Issue.record("被取消的 follower 应该收到错误")
        }
    }
}

// MARK: - Test Helpers

private struct TaskManagerDummyRequest: iNtkRequest {
    let path: String
}

private actor TaskExecutionGate {
    private var firstStarted = false
    private var secondStarted = false
    private var firstReleased = false
    private var secondReleased = false
    private var firstStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstReleaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    func signalFirstStarted() {
        firstStarted = true
        let waiters = firstStartWaiters
        firstStartWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func signalSecondStarted() {
        secondStarted = true
        let waiters = secondStartWaiters
        secondStartWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilFirstStarted() async {
        if firstStarted { return }
        await withCheckedContinuation { continuation in
            firstStartWaiters.append(continuation)
        }
    }

    func waitUntilSecondStarted() async {
        if secondStarted { return }
        await withCheckedContinuation { continuation in
            secondStartWaiters.append(continuation)
        }
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

private func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }
    guard let ntkError = error as? NtkError else {
        return false
    }
    if case let .response(failure) = ntkError,
       failure.reason == .cancelled {
        return true
    }
    return false
}
