//
//  NtkTaskManager.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 网络请求任务管理器（去重调度中心）
///
/// 设计目的：
/// - 在不改变上层调用方式的前提下，统一承接“去重复用 + 超时兜底 + 取消控制”三类能力；
/// - 将“请求语义”转成“运行时键（runtimeKey）”，让同语义请求共享执行，不同语义请求隔离执行。
///
/// 设计原理：
/// - 基于全局 Actor 串行化对内部状态的读写，避免多线程下字典竞争；
/// - 通过 runtimeKey 编码去重策略：
///   - dedup|\(baseRequestId)：同类请求复用同一 Task；
///   - nodedup|\(baseRequestId)|\(seq)：每次调用获得独立 Task，避免覆盖。
///
/// 产出作用：
/// - 输出稳定的一致性行为：去重开启时复用结果，去重关闭时并发互不干扰；
/// - 对外提供可观测控制面：单请求取消、全量取消、活跃态查询。
@NtkActor
final class NtkTaskManager {

    private typealias RuntimeKey = String

    private struct RequestTaskEntry {
        let token: UUID
        let task: Task<Sendable, Error>
        let ownerRequestInstanceId: UUID
    }

    /// 运行中任务表
    ///
    /// 输入数据：
    /// - Key: runtimeKey（由“基础请求标识 + 去重策略”构造）
    /// - Value: 对应的正在执行 Task
    ///
    /// 作用：
    /// - 作为去重复用与取消控制的唯一事实来源（single source of truth）；
    /// - 通过 Key 语义区分“可复用任务”和“独立任务”。
    private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]
    private var cancelledFollowerWaiters: [RuntimeKey: Set<UUID>] = [:]
    private var followerContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    /// 非去重请求的本地递增序号
    ///
    /// 目的：
    /// - 为 non-dedup 场景生成稳定唯一后缀，确保同一 baseRequestId 的并发调用不发生键覆盖。
    ///
    /// 设计注意：
    /// - 该值不在 cancelAll 时重置，避免旧任务延迟退出时误删新任务映射。
    private var nonDedupSequence: UInt64 = 0

    /// 单例
    static let shared = NtkTaskManager()

    private init() {}

    /// 执行请求（统一入口）
    ///
    /// 输入数据：
    /// - request: 参与去重判定、超时策略、取消匹配的请求语义载体；
    /// - execution: 实际网络执行闭包。
    ///
    /// 设计目标：
    /// - 在同一入口内完成策略分流（去重开启/关闭）；
    /// - 对调用方保持一致的 `async throws -> T` 语义，不泄露内部调度细节。
    ///
    /// 产出作用：
    /// - 去重开启：同请求共享结果并减少重复 IO；
    /// - 去重关闭：请求独立执行但仍保留超时与取消能力。
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
     func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let baseRequestId = requestIdentifier(for: request)
        let deduplicationEnabled = isDeduplicationEnabled(for: request)
        let requestInstanceId = request.instanceIdentifier

        guard deduplicationEnabled else {
            NtkLogger.shared.debug("Request deduplication is disabled, executing with timeout only", category: .deduplication)
            let runtimeKey = makeNonDedupRuntimeKey(baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
            return try await executeNewRequestWithTimeout(
                requestKey: runtimeKey,
                request: request,
                ownerRequestInstanceId: requestInstanceId,
                execution: execution
            )
        }
        let runtimeKey = dedupRuntimeKey(baseRequestId: baseRequestId)
        NtkLogger.shared.debug("请求标识符: \(baseRequestId)", category: .deduplication)

        /// 等待进行的请求的结果
        if let result: T = try await awaitOngoingResultIfAvailable(
            runtimeKey: runtimeKey,
            baseRequestId: baseRequestId,
            requestInstanceId: requestInstanceId
        ) {
            return result
        }

        NtkLogger.shared.debug("创建新请求任务: \(baseRequestId)", category: .deduplication)
        return try await executeNewRequestWithTimeout(
            requestKey: runtimeKey,
            request: request,
            ownerRequestInstanceId: requestInstanceId,
            execution: execution
        )
    }



    /// 取消指定请求
    /// - Parameter request: 要取消的请求
    func cancelRequest(request: NtkMutableRequest) {
        let baseRequestId = requestIdentifier(for: request)
        let requestInstanceId = request.instanceIdentifier
        if isDeduplicationEnabled(for: request) {
            let dedupKey = dedupRuntimeKey(baseRequestId: baseRequestId)
            guard let entry = ongoingRequests[dedupKey] else {
                return
            }
            guard entry.ownerRequestInstanceId == requestInstanceId else {
                markFollowerCancellation(runtimeKey: dedupKey, requestInstanceId: requestInstanceId)
                return
            }
            cancelAndRemoveEntries(keys: [dedupKey])
            return
        }
        let keys = matchingRuntimeKeys(forBaseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
        cancelAndRemoveEntries(keys: keys)
    }

    /// 取消所有正在进行的请求
    func cancelAllRequests() {
        let allKeys = Array(ongoingRequests.keys)
        cancelAndRemoveEntries(keys: allKeys)
        cancelledFollowerWaiters.removeAll()
    }

    /// 获取当前活跃请求数量
    /// - Returns: 正在进行的请求数量
    func activeRequestCount() -> Int {
        return ongoingRequests.count
    }

    /// 检查指定请求是否处于活跃状态
    /// - Parameter request: 要检查的请求
    /// - Returns: 请求是否正在执行中
    func isRequestActive(request: NtkMutableRequest) -> Bool {
        let baseRequestId = requestIdentifier(for: request)
        return hasActiveTask(forBaseRequestId: baseRequestId)
    }
}

// MARK: - Private Methods
extension NtkTaskManager {

    /// 执行带超时控制的请求（通用方法）
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    private func executeWithTimeout<T: Sendable>(
        timeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际请求任务
            group.addTask {
                return try await execution()
            }

            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NtkError.requestTimeout
            }

            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }

            // 取消其他任务
            group.cancelAll()

            return result
        }
    }

    /// 执行新请求并登记到任务表
    ///
    /// 输入数据：
    /// - requestKey: 已编码策略语义的运行时键，用于唯一定位本次执行；
    /// - request: 提供超时配置；
    /// - execution: 实际执行闭包。
    ///
    /// 设计原理：
    /// - 先登记、后等待，并在 `defer` 中按 requestKey 定点清理，保证生命周期收口。
    ///
    /// 产出作用：
    /// - 返回业务结果或错误；
    /// - 无论成功/失败/取消，都回收自身映射，避免悬挂状态。
    /// - Parameters:
    ///   - requestKey: 运行时请求键
    ///   - request: 网络请求对象
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    private func executeNewRequestWithTimeout<T: Sendable>(
        requestKey: RuntimeKey,
        request: NtkMutableRequest,
        ownerRequestInstanceId: UUID,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = request.timeout

        let entry = RequestTaskEntry(token: UUID(), task: Task<Sendable, Error> {
            return try await executeWithTimeout(timeout: timeout, execution: execution)
        }, ownerRequestInstanceId: ownerRequestInstanceId)

        cancelledFollowerWaiters.removeValue(forKey: requestKey)
        ongoingRequests[requestKey] = entry

        defer {
            removeEntryIfTokenMatches(requestKey: requestKey, token: entry.token)
        }

        do {
            let result = try await entry.task.value
            NtkLogger.shared.debug("请求成功完成: \(requestKey)", category: .deduplication)

            if let typedResult = result as? T {
                return typedResult
            } else {
                throw NtkError.typeMismatch
            }
        } catch let error as NtkError {
            if case .requestTimeout = error {
                NtkLogger.shared.warning("请求超时: \(requestKey), 超时时间: \(timeout)秒", category: .deduplication)
            } else {
                NtkLogger.shared.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
            }
            throw error
        } catch {
            NtkLogger.shared.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
            throw error
        }
    }

    /// 构造“可复用”运行时键。
    ///
    /// 输入：baseRequestId（由请求内容计算的稳定标识）。
    /// 输出：dedup 前缀键；相同输入得到相同输出，用于去重命中。
    private func dedupRuntimeKey(baseRequestId: String) -> RuntimeKey {
        "dedup|\(baseRequestId)"
    }

    /// 构造“不可复用”运行时键。
    ///
    /// 输入：baseRequestId。
    /// 输出：附带递增序号的唯一键；相同请求多次调用也不会覆盖。
    private func makeNonDedupRuntimeKey(baseRequestId: String, requestInstanceId: UUID) -> RuntimeKey {
        nonDedupSequence = nonDedupSequence &+ 1
        return "\(nonDedupRuntimePrefix(baseRequestId: baseRequestId, requestInstanceId: requestInstanceId))|\(nonDedupSequence)"
    }

    /// 判断某个基础请求标识是否存在活跃任务。
    ///
    /// 设计原理：
    /// - dedup 场景查单键；
    /// - non-dedup 场景按前缀聚合判断。
    ///
    /// 产出作用：
    /// - 对外提供与策略无关的“请求是否活跃”统一语义。
    private func hasActiveTask(forBaseRequestId baseRequestId: String) -> Bool {
        !matchingRuntimeKeys(forBaseRequestId: baseRequestId).isEmpty
    }

    private func removeEntryIfTokenMatches(requestKey: RuntimeKey, token: UUID) {
        guard let current = ongoingRequests[requestKey], current.token == token else {
            return
        }
        ongoingRequests.removeValue(forKey: requestKey)
        cancelledFollowerWaiters.removeValue(forKey: requestKey)
    }

    private func castTaskResult<T: Sendable>(_ task: Task<Sendable, Error>) async throws -> T {
        let result = try await task.value
        guard let typedResult = result as? T else {
            throw NtkError.typeMismatch
        }
        return typedResult
    }

    private func awaitOngoingResultIfAvailable<T: Sendable>(
        runtimeKey: RuntimeKey,
        baseRequestId: String,
        requestInstanceId: UUID
    ) async throws -> T? {
        guard let ongoingEntry = ongoingRequests[runtimeKey] else {
            return nil
        }
        NtkLogger.shared.info("发现重复请求，等待现有请求完成: \(baseRequestId)", category: .deduplication)
        do {
            let result: T
            if ongoingEntry.ownerRequestInstanceId == requestInstanceId {
                /// 用户使用同一个实例对象，重复发起请求了。
                result = try await castTaskResult(ongoingEntry.task)
            } else {
                /// 用户使用新的实例对象，但是属于同一个接口
                result = try await awaitFollowerResultOrCancellation(
                    runtimeKey: runtimeKey,
                    task: ongoingEntry.task,
                    requestInstanceId: requestInstanceId
                )
            }
            NtkLogger.shared.info("重复请求完成，返回共享结果: \(baseRequestId)", category: .deduplication)
            return result
        } catch NtkError.typeMismatch {
            NtkLogger.shared.warning("共享任务类型不匹配，改为创建新任务: \(baseRequestId)", category: .deduplication)
            return nil
        } catch {
            NtkLogger.shared.warning("现有请求失败，透传错误: \(baseRequestId), 错误: \(error)", category: .deduplication)
            throw error
        }
    }

    private func matchingRuntimeKeys(forBaseRequestId baseRequestId: String) -> [RuntimeKey] {
        let dedupKey = dedupRuntimeKey(baseRequestId: baseRequestId)
        let nonDedupPrefix = "nodedup|\(baseRequestId)|"
        return ongoingRequests.keys.filter { key in
            key == dedupKey || key.hasPrefix(nonDedupPrefix)
        }
    }

    private func matchingRuntimeKeys(forBaseRequestId baseRequestId: String, requestInstanceId: UUID) -> [RuntimeKey] {
        let prefix = nonDedupRuntimePrefix(baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
        return ongoingRequests.keys.filter { $0.hasPrefix(prefix) }
    }

    private func cancelAndRemoveEntries(keys: [RuntimeKey]) {
        for key in keys {
            guard let entry = ongoingRequests[key] else {
                continue
            }
            entry.task.cancel()
            removeEntryIfTokenMatches(requestKey: key, token: entry.token)
        }
    }

    private func awaitFollowerResultOrCancellation<T: Sendable>(
        runtimeKey: RuntimeKey,
        task: Task<Sendable, Error>,
        requestInstanceId: UUID
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await self.castTaskResult(task)
            }
            group.addTask {
                try await self.waitForFollowerCancellation(
                    runtimeKey: runtimeKey,
                    requestInstanceId: requestInstanceId
                )
                throw NtkError.requestCancelled
            }

            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }
            group.cancelAll()
            return result
        }
    }

    private func waitForFollowerCancellation(
        runtimeKey: RuntimeKey,
        requestInstanceId: UUID
    ) async throws {
        defer {
            clearFollowerCancellation(runtimeKey: runtimeKey, requestInstanceId: requestInstanceId)
        }
        
        if isFollowerCancellationMarked(runtimeKey: runtimeKey, requestInstanceId: requestInstanceId) {
            return
        }
        
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if isFollowerCancellationMarked(runtimeKey: runtimeKey, requestInstanceId: requestInstanceId) {
                    continuation.resume()
                    return
                }
                followerContinuations[requestInstanceId] = continuation
            }
        } onCancel: {
            Task { [weak self] in
                await self?.cancelFollowerWait(requestInstanceId: requestInstanceId)
            }
        }
    }

    private func markFollowerCancellation(runtimeKey: RuntimeKey, requestInstanceId: UUID) {
        var cancelledIds = cancelledFollowerWaiters[runtimeKey] ?? []
        cancelledIds.insert(requestInstanceId)
        cancelledFollowerWaiters[runtimeKey] = cancelledIds
        
        if let continuation = followerContinuations.removeValue(forKey: requestInstanceId) {
            continuation.resume()
        }
    }

    private func clearFollowerCancellation(runtimeKey: RuntimeKey, requestInstanceId: UUID) {
        followerContinuations.removeValue(forKey: requestInstanceId)
        
        guard var cancelledIds = cancelledFollowerWaiters[runtimeKey] else {
            return
        }
        cancelledIds.remove(requestInstanceId)
        if cancelledIds.isEmpty {
            cancelledFollowerWaiters.removeValue(forKey: runtimeKey)
        } else {
            cancelledFollowerWaiters[runtimeKey] = cancelledIds
        }
    }

    private func isFollowerCancellationMarked(runtimeKey: RuntimeKey, requestInstanceId: UUID) -> Bool {
        cancelledFollowerWaiters[runtimeKey]?.contains(requestInstanceId) == true
    }

    private func cancelFollowerWait(requestInstanceId: UUID) {
        if let continuation = followerContinuations.removeValue(forKey: requestInstanceId) {
            continuation.resume(throwing: CancellationError())
        }
    }

    private func requestIdentifier(for request: NtkMutableRequest) -> String {
        NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
    }

    private func isDeduplicationEnabled(for request: NtkMutableRequest) -> Bool {
        NtkDeduplicationConfig.shared.isGloballyEnabled && request.isDeduplicationEnabled
    }

    private func nonDedupRuntimePrefix(baseRequestId: String, requestInstanceId: UUID) -> RuntimeKey {
        "nodedup|\(baseRequestId)|\(requestInstanceId.uuidString)"
    }
}
