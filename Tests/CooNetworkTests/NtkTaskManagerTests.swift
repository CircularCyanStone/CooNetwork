import Testing
import Foundation
@testable import CooNetwork

@Suite(.serialized)
struct NtkTaskManagerTests {

    @Test
    @NtkActor
    func testDisabledDeduplicationKeepsLatestTaskMapped() async throws {
        let gate = TaskExecutionGate()

        var firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
        firstRequest.disableDeduplication()

        var secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-count"))
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
    func testCancelRequestCancelsOnlyCurrentDisabledDeduplicationTask() async throws {
        let gate = TaskExecutionGate()

        var firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        firstRequest.disableDeduplication()

        var secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/non-dedup-cancel"))
        secondRequest.disableDeduplication()

        let firstTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: firstRequest) {
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
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: secondRequest) {
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

        let firstRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))
        let secondRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-shared"))

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
        let request = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-cancel-reenter"))

        let firstTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: request) {
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
        NtkTaskManager.shared.cancelRequest(request: request)

        let secondTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: request) {
                await gate.signalSecondStarted()
                await gate.waitForSecondRelease()
                return "second"
            } as String
        }

        await gate.waitUntilSecondStarted()
        #expect(NtkTaskManager.shared.isRequestActive(request: request) == true)

        await gate.releaseFirst()
        _ = await firstTask.value

        #expect(NtkTaskManager.shared.isRequestActive(request: request) == true)

        await gate.releaseSecond()
        let secondValue = try await secondTask.value
        #expect(secondValue == "second")
    }

    @Test
    @NtkActor
    func testDedupFollowerCancelOnlyCancelsOwnWaiting() async throws {
        let gate = TaskExecutionGate()
        let ownerRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        let followerRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        let anotherFollowerRequest = NtkMutableRequest(TaskManagerDummyRequest(path: "/task-manager/test/dedup-follower-cancel"))
        let counter = ExecutionCounter()
        #expect(ownerRequest.instanceIdentifier != followerRequest.instanceIdentifier)

        let ownerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: ownerRequest) {
                await counter.increment()
                await gate.signalFirstStarted()
                await gate.waitForFirstRelease()
                return "shared"
            } as String
        }

        await gate.waitUntilFirstStarted()

        let cancelledFollowerTask = Task {
            do {
                let value: String = try await NtkTaskManager.shared.executeWithDeduplication(request: followerRequest) {
                    await counter.increment()
                    return "should-not-run"
                }
                return Result<String, Error>.success(value)
            } catch {
                return Result<String, Error>.failure(error)
            }
        }

        await Task.yield()
        NtkTaskManager.shared.cancelRequest(request: followerRequest)

        let normalFollowerTask = Task {
            try await NtkTaskManager.shared.executeWithDeduplication(request: anotherFollowerRequest) {
                await counter.increment()
                return "should-not-run"
            } as String
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        await gate.releaseFirst()

        let cancelledFollowerResult = await cancelledFollowerTask.value
        if case .success = cancelledFollowerResult {
            Issue.record("去重 follower 取消后应立即返回取消错误")
        } else if case .failure(let error) = cancelledFollowerResult {
            #expect(isCancellationError(error) == true)
        }
        let ownerValue = try await ownerTask.value
        let normalFollowerValue = try await normalFollowerTask.value
        let executionCount = await counter.value()

        #expect(ownerValue == "shared")
        #expect(normalFollowerValue == "shared")
        #expect(executionCount == 1)
    }

}

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
    if case .requestCancelled = ntkError {
        return true
    }
    return false
}
