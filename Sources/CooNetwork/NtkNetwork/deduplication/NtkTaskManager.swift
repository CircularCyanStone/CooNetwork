//
//  NtkTaskManager.swift
//  CNtk
//

import Foundation

/// 网络请求任务管理器（去重调度中心）。
///
/// 去重键只来自执行器已冻结的身份；身份不可用时，每次执行仅使用请求实例隔离。
actor NtkTaskManager {

    private enum RuntimeKey: Hashable, Sendable {
        case shared(NtkDeduplicationIdentity)
        case isolated(UUID)
    }

    private struct RequestTaskEntry {
        let token: UUID
        let task: Task<Sendable, Error>
        let ownerInstanceId: UUID
        var ownerActive = true
        var followerTasks: [UUID: Task<Sendable, Error>] = [:]
    }

    private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]

    /// 反向索引是取消和活跃态查询的唯一依据，绝不从可变请求内容重新推导键。
    private var runtimeKeyByInstanceID: [UUID: RuntimeKey] = [:]

    static let shared = NtkTaskManager()

    private init() {}

    func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        identity: NtkDeduplicationIdentity?,
        effectiveTimeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if request.isCancelledRef?.isCancelled == true {
            throw NtkError.requestCancelled
        }

        let runtimeKey = identity.map(RuntimeKey.shared) ?? .isolated(request.instanceIdentifier)
        let timeoutForExecution = identity?.effectiveTimeout ?? effectiveTimeout

        // 只有已经成功建立身份的执行可以共享；身份缺失必须始终独立执行。
        if identity != nil,
           let result: T = try await awaitOngoingResultIfAvailable(
               runtimeKey: runtimeKey,
               request: request
           ) {
            return result
        }

        return try await executeNewRequestWithTimeout(
            runtimeKey: runtimeKey,
            request: request,
            effectiveTimeout: timeoutForExecution,
            execution: execution
        )
    }

    func cancelRequest(instanceIdentifier: UUID) {
        guard let runtimeKey = runtimeKeyByInstanceID[instanceIdentifier] else { return }
        cancelWaiter(runtimeKey: runtimeKey, instanceIdentifier: instanceIdentifier)
    }

    func cancelAllRequests() {
        for (runtimeKey, entry) in ongoingRequests {
            for waiterTask in entry.followerTasks.values {
                waiterTask.cancel()
            }
            entry.task.cancel()
            removeAllIndexes(for: entry, runtimeKey: runtimeKey)
        }
        ongoingRequests.removeAll()
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

    /// 仅接收执行器解析并冻结的超时值；任务管理器不读取全局配置或请求原始超时。
    private static func executeWithTimeout<T: Sendable>(
        effectiveTimeout: TimeInterval,
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
                throw NtkError.requestTimeout(.framework(timeout: effectiveTimeout))
            }

            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }
            return result
        }
    }

    private func executeNewRequestWithTimeout<T: Sendable>(
        runtimeKey: RuntimeKey,
        request: NtkMutableRequest,
        effectiveTimeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let entry = RequestTaskEntry(
            token: UUID(),
            task: Task<Sendable, Error> {
                try await Self.executeWithTimeout(
                    effectiveTimeout: effectiveTimeout,
                    execution: execution
                )
            },
            ownerInstanceId: request.instanceIdentifier
        )

        // 先完整登记 owner，再第一次 await，保证 cancel 可立即通过实例反向索引定位。
        ongoingRequests[runtimeKey] = entry
        register(request.instanceIdentifier, for: runtimeKey)

        defer {
            ownerDidFinish(runtimeKey: runtimeKey, token: entry.token)
        }

        do {
            let result = try await entry.task.value
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
            throw error
        }
    }

    private func awaitOngoingResultIfAvailable<T: Sendable>(
        runtimeKey: RuntimeKey,
        request: NtkMutableRequest
    ) async throws -> T? {
        guard var entry = ongoingRequests[runtimeKey] else { return nil }

        let instanceIdentifier = request.instanceIdentifier
        let underlyingTask = entry.task
        let waiterTask = Task<Sendable, Error> {
            if Task.isCancelled { throw NtkError.requestCancelled }
            let result = try await underlyingTask.value
            if Task.isCancelled { throw NtkError.requestCancelled }
            return result
        }

        // follower 的 waiter、entry 和反向索引必须在首次 await 前一起写入。
        entry.followerTasks[instanceIdentifier] = waiterTask
        ongoingRequests[runtimeKey] = entry
        register(instanceIdentifier, for: runtimeKey)
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
        }
    }

    private func cancelWaiter(runtimeKey: RuntimeKey, instanceIdentifier: UUID) {
        guard var entry = ongoingRequests[runtimeKey] else {
            removeIndex(instanceIdentifier, for: runtimeKey)
            return
        }

        if entry.ownerInstanceId == instanceIdentifier {
            entry.ownerActive = false
            removeIndex(instanceIdentifier, for: runtimeKey)
        } else if let waiterTask = entry.followerTasks.removeValue(forKey: instanceIdentifier) {
            waiterTask.cancel()
            removeIndex(instanceIdentifier, for: runtimeKey)
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
        }
    }
}
