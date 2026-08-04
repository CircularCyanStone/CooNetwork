//
//  NtkTaskManager.swift
//  CNtk
//

import Foundation

/// 网络请求任务管理器（去重调度中心）。
///
/// 去重 key 只来自执行器已冻结的结果；key 不可用时，每次执行仅使用请求实例隔离。
actor NtkTaskManager {

    private enum RuntimeKey: Hashable, Sendable {
        case shared(NtkDeduplicationKey)
        case isolated(UUID)
    }

    private struct RequestTaskEntry {
        let token: UUID
        let task: Task<Sendable, Error>
        let ownerWaiterTask: Task<Sendable, Error>
        let ownerInstanceId: UUID
        let ownerLogContext: String
        var ownerActive = true
        var followerTasks: [UUID: Task<Sendable, Error>] = [:]
        var followerLogContexts: [UUID: String] = [:]
    }

    private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]

    /// 反向索引是取消和活跃态查询的唯一依据，绝不从可变请求内容重新推导键。
    private var runtimeKeyByInstanceID: [UUID: RuntimeKey] = [:]

    static let shared = NtkTaskManager()

    private init() {}

    func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        deduplicationKey: NtkDeduplicationKey?,
        effectiveTimeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if request.isCancelledRef?.isCancelled == true {
            throw NtkError.requestCancelled
        }

        // 构建失败或功能关闭时没有 deduplicationKey，此时使用每个请求实例自己的 UUID，保证
        // 字典管理、取消与超时逻辑仍走同一条路径，但两个请求永远不会意外共享底层任务。
        let runtimeKey = deduplicationKey.map(RuntimeKey.shared) ?? .isolated(request.instanceIdentifier)
        let timeoutForExecution = deduplicationKey?.effectiveTimeout ?? effectiveTimeout
        let logContext = Self.logContext(for: request, deduplicationKey: deduplicationKey)

        // 只有已经成功建立去重 key 的执行可以查找共享任务；key 缺失必须始终独立执行。
        if deduplicationKey != nil,
           let result: T = try await awaitOngoingResultIfAvailable(
               runtimeKey: runtimeKey,
               request: request,
               logContext: logContext
           ) {
            return result
        }

        return try await executeNewRequestWithTimeout(
            runtimeKey: runtimeKey,
            request: request,
            effectiveTimeout: timeoutForExecution,
            logContext: logContext,
            execution: execution
        )
    }

    func cancelRequest(instanceIdentifier: UUID) {
        guard let runtimeKey = runtimeKeyByInstanceID[instanceIdentifier] else { return }
        cancelWaiter(runtimeKey: runtimeKey, instanceIdentifier: instanceIdentifier)
    }

    func cancelAllRequests() {
        for (runtimeKey, entry) in ongoingRequests {
            if entry.ownerActive {
                logger.debug(
                    "[Deduplication] owner-cancelled \(entry.ownerLogContext)",
                    category: .deduplication
                )
            }
            entry.ownerWaiterTask.cancel()
            for (instanceIdentifier, waiterTask) in entry.followerTasks {
                let logContext = entry.followerLogContexts[instanceIdentifier]
                    ?? "requestID=\(instanceIdentifier.uuidString)"
                logger.debug(
                    "[Deduplication] follower-cancelled \(logContext)",
                    category: .deduplication
                )
                waiterTask.cancel()
            }
            entry.task.cancel()
            removeAllIndexes(for: entry, runtimeKey: runtimeKey)
        }
        ongoingRequests.removeAll()
        runtimeKeyByInstanceID.removeAll()
    }

    func activeRequestCount() -> Int {
        ongoingRequests.count
    }

    func isRequestActive(instanceIdentifier: UUID) -> Bool {
        runtimeKeyByInstanceID[instanceIdentifier] != nil
    }
}

// MARK: - 请求执行
extension NtkTaskManager {

    private static func logContext(
        for request: NtkMutableRequest,
        deduplicationKey: NtkDeduplicationKey?
    ) -> String {
        let requestID = "requestID=\(request.instanceIdentifier.uuidString)"
        guard let deduplicationKey else { return requestID }
        return "\(requestID) identity=\(deduplicationKey.requestIdentity.value)"
    }

    /// 仅接收执行器解析并冻结的超时值；任务管理器不读取全局配置或请求原始超时。
    /// 前置不变量：`NtkRequestTimeoutResolver` 已保证该值有限、为正且不超过最大值，
    /// 因此可安全转换为 `UInt64` 纳秒；这里不重新回退或夹取。
    private static func executeWithTimeout<T: Sendable>(
        effectiveTimeout: TimeInterval,
        logContext: String,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            defer { group.cancelAll() }

            group.addTask {
                if Task.isCancelled { throw NtkError.requestCancelled }
                let result = try await execution()
                if Task.isCancelled { throw NtkError.requestCancelled }
                return result
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                logger.error(
                    "[Deduplication] execution-timeout \(logContext) timeout=\(effectiveTimeout)",
                    category: .deduplication
                )
                throw NtkError.requestTimeout(.framework(timeout: effectiveTimeout))
            }

            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }
            return result
        }
    }

    private static func logFinalExecutionFailure(
        _ error: Error,
        logContext: String
    ) {
        guard !isCancellation(error), !isFrameworkTimeout(error) else { return }
        logger.error(
            "[Deduplication] execution-failed \(logContext) errorType=\(String(reflecting: type(of: error)))",
            category: .deduplication
        )
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        guard let ntkError = error as? NtkError else { return false }
        if case .requestCancelled = ntkError { return true }
        return false
    }

    private static func isFrameworkTimeout(_ error: Error) -> Bool {
        guard let ntkError = error as? NtkError,
              case let .requestTimeout(reason) = ntkError else {
            return false
        }
        return reason.source == "Framework"
    }

    private static func makeCancellableWaiterTask(
        for underlyingTask: Task<Sendable, Error>
    ) -> Task<Sendable, Error> {
        Task {
            let waiter = CancellableTaskValueWaiter()
            Task {
                do {
                    await waiter.complete(.success(try await underlyingTask.value))
                } catch {
                    await waiter.complete(.failure(error))
                }
            }
            return try await withTaskCancellationHandler {
                try await waiter.value()
            } onCancel: {
                Task {
                    await waiter.cancel()
                }
            }
        }
    }

    private func executeNewRequestWithTimeout<T: Sendable>(
        runtimeKey: RuntimeKey,
        request: NtkMutableRequest,
        effectiveTimeout: TimeInterval,
        logContext: String,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let underlyingTask = Task<Sendable, Error> {
            try await Self.executeWithTimeout(
                effectiveTimeout: effectiveTimeout,
                logContext: logContext,
                execution: execution
            )
        }
        let entry = RequestTaskEntry(
            token: UUID(),
            task: underlyingTask,
            ownerWaiterTask: Self.makeCancellableWaiterTask(for: underlyingTask),
            ownerInstanceId: request.instanceIdentifier,
            ownerLogContext: logContext
        )

        // 先完整登记 owner，再第一次 await，保证 cancel 可立即通过实例反向索引定位。
        ongoingRequests[runtimeKey] = entry
        register(request.instanceIdentifier, for: runtimeKey)
        logger.debug(
            "[Deduplication] owner-created \(logContext) timeout=\(effectiveTimeout)",
            category: .deduplication
        )

        defer {
            ownerDidFinish(runtimeKey: runtimeKey, token: entry.token)
        }

        do {
            let result = try await entry.ownerWaiterTask.value
            if request.isCancelledRef?.isCancelled == true {
                throw NtkError.requestCancelled
            }
            guard let typedResult = result as? T else {
                throw NtkError.invalidTypedResponse
            }
            return typedResult
        } catch {
            if request.isCancelledRef?.isCancelled == true {
                throw NtkError.requestCancelled
            }
            Self.logFinalExecutionFailure(error, logContext: logContext)
            throw error
        }
    }

    private func awaitOngoingResultIfAvailable<T: Sendable>(
        runtimeKey: RuntimeKey,
        request: NtkMutableRequest,
        logContext: String
    ) async throws -> T? {
        guard var entry = ongoingRequests[runtimeKey] else { return nil }

        let instanceIdentifier = request.instanceIdentifier
        let underlyingTask = entry.task
        let waiterTask = Self.makeCancellableWaiterTask(for: underlyingTask)

        // follower 的 waiter、entry 和反向索引必须在首次 await 前一起写入。
        entry.followerTasks[instanceIdentifier] = waiterTask
        entry.followerLogContexts[instanceIdentifier] = logContext
        ongoingRequests[runtimeKey] = entry
        register(instanceIdentifier, for: runtimeKey)
        logger.debug(
            "[Deduplication] follower-joined \(logContext)",
            category: .deduplication
        )
        let token = entry.token

        defer {
            followerDidFinish(
                runtimeKey: runtimeKey,
                token: token,
                instanceIdentifier: instanceIdentifier
            )
        }

        do {
            let result = try await waiterTask.value
            if request.isCancelledRef?.isCancelled == true {
                throw NtkError.requestCancelled
            }
            return result as? T
        } catch {
            if request.isCancelledRef?.isCancelled == true {
                throw NtkError.requestCancelled
            }
            throw error
        }
    }
}

private actor CancellableTaskValueWaiter {
    private var result: Result<Sendable, Error>?
    private var continuation: CheckedContinuation<Sendable, Error>?

    func value() async throws -> Sendable {
        if let result {
            return try result.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            if let result {
                continuation.resume(with: result)
            } else {
                self.continuation = continuation
            }
        }
    }

    func complete(_ result: Result<Sendable, Error>) {
        finish(with: result)
    }

    func cancel() {
        finish(with: .failure(NtkError.requestCancelled))
    }

    private func finish(with result: Result<Sendable, Error>) {
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - 生命周期与反向索引
extension NtkTaskManager {

    private func register(_ instanceIdentifier: UUID, for runtimeKey: RuntimeKey) {
        runtimeKeyByInstanceID[instanceIdentifier] = runtimeKey
    }

    private func removeIndex(_ instanceIdentifier: UUID, for runtimeKey: RuntimeKey) {
        guard runtimeKeyByInstanceID[instanceIdentifier] == runtimeKey else { return }
        runtimeKeyByInstanceID.removeValue(forKey: instanceIdentifier)
    }

    private func removeAllIndexes(for entry: RequestTaskEntry, runtimeKey: RuntimeKey) {
        removeIndex(entry.ownerInstanceId, for: runtimeKey)
        for instanceIdentifier in entry.followerTasks.keys {
            removeIndex(instanceIdentifier, for: runtimeKey)
        }
    }

    /// token 防止旧 task 的 defer 清理掉重入后已经登记的新 entry。
    private func ownerDidFinish(runtimeKey: RuntimeKey, token: UUID) {
        guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
        entry.ownerActive = false
        removeIndex(entry.ownerInstanceId, for: runtimeKey)
        removeEntryIfNoWaiters(entry, runtimeKey: runtimeKey)
    }

    private func followerDidFinish(runtimeKey: RuntimeKey, token: UUID, instanceIdentifier: UUID) {
        guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
        entry.followerTasks.removeValue(forKey: instanceIdentifier)
        entry.followerLogContexts.removeValue(forKey: instanceIdentifier)
        removeIndex(instanceIdentifier, for: runtimeKey)
        removeEntryIfNoWaiters(entry, runtimeKey: runtimeKey)
    }

    /// 维护引用计数不变量：没有 owner 或 follower 等待时必须取消底层任务并清理 entry。
    private func removeEntryIfNoWaiters(_ entry: RequestTaskEntry, runtimeKey: RuntimeKey) {
        let hasWaiters = entry.ownerActive || !entry.followerTasks.isEmpty
        if hasWaiters {
            ongoingRequests[runtimeKey] = entry
        } else {
            entry.task.cancel()
            ongoingRequests.removeValue(forKey: runtimeKey)
            logger.debug(
                "[Deduplication] entry-removed \(entry.ownerLogContext) reason=no-waiters",
                category: .deduplication
            )
        }
    }

    private func cancelWaiter(runtimeKey: RuntimeKey, instanceIdentifier: UUID) {
        guard var entry = ongoingRequests[runtimeKey] else {
            removeIndex(instanceIdentifier, for: runtimeKey)
            return
        }

        if entry.ownerInstanceId == instanceIdentifier {
            entry.ownerActive = false
            entry.ownerWaiterTask.cancel()
            removeIndex(instanceIdentifier, for: runtimeKey)
            logger.debug(
                "[Deduplication] owner-cancelled \(entry.ownerLogContext)",
                category: .deduplication
            )
        } else if let waiterTask = entry.followerTasks.removeValue(forKey: instanceIdentifier) {
            waiterTask.cancel()
            removeIndex(instanceIdentifier, for: runtimeKey)
            let logContext = entry.followerLogContexts.removeValue(forKey: instanceIdentifier)
                ?? "requestID=\(instanceIdentifier.uuidString)"
            logger.debug(
                "[Deduplication] follower-cancelled \(logContext)",
                category: .deduplication
            )
        } else {
            removeIndex(instanceIdentifier, for: runtimeKey)
            return
        }

        if entry.ownerActive || !entry.followerTasks.isEmpty {
            ongoingRequests[runtimeKey] = entry
        } else {
            entry.task.cancel()
            removeAllIndexes(for: entry, runtimeKey: runtimeKey)
            ongoingRequests.removeValue(forKey: runtimeKey)
            logger.debug(
                "[Deduplication] entry-removed \(entry.ownerLogContext) reason=no-waiters",
                category: .deduplication
            )
        }
    }
}
