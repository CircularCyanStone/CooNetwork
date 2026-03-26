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
/// - 在不改变上层调用方式的前提下，统一承接"去重复用 + 超时兜底 + 取消控制"三类能力；
/// - 将"请求语义"转成"运行时键（runtimeKey）"，让同语义请求共享执行，不同语义请求隔离执行。
///
/// 设计原理：
/// - 基于全局 Actor 串行化对内部状态的读写，避免多线程下字典竞争；
/// - 通过 runtimeKey 编码去重策略：
///   - dedup|\(baseRequestId)|\(responseType)：同类请求复用同一 Task；
///   - nodedup|\(baseRequestId)|\(requestInstanceId)：同实例请求独立执行。
///
/// 取消隔离设计：
/// - 去重场景下，每个 follower 通过独立的 wrapper Task 等待底层结果；
/// - 取消某个等待者不影响其他等待者和底层执行 Task；
/// - 所有等待者（含 owner）都取消后，底层 Task 也被取消（引用计数归零）。
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
        /// owner 的 instanceIdentifier（用于 owner 取消时的识别）
        let ownerInstanceId: UUID
        /// owner 是否仍在等待
        var ownerActive: Bool = true
        /// follower 的 waiterTask 映射（key = NtkMutableRequest.instanceIdentifier）
        var followerTasks: [UUID: Task<Sendable, Error>] = [:]
    }

    /// 运行中任务表
    private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]

    /// 单例
    static let shared = NtkTaskManager()

    private init() {}

    // MARK: - Public API

    /// 执行请求（统一入口）
    func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // 检查取消状态（解决先取消后执行的可重入问题）
        if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
            logger.warning("请求已取消，终止执行", category: .deduplication)
            throw NtkError.response(.init(reason: .cancelled))
        }

        let baseRequestId = requestIdentifier(for: request)

        if isDeduplicationEnabled(for: request) {
            // NtkNetwork 会在初始化时注入 responseType
            // 如果缺失，说明框架内部逻辑异常（例如未通过 NtkNetwork 初始化而直接调用了 TaskManager）
            guard let responseType = request.responseType else {
                assertionFailure(
                    "Missing responseType in request. This should be injected by NtkNetwork.")
                logger.error("去重失败：请求缺少 responseType，将回退到非去重模式", category: .deduplication)
                // 回退到非去重模式
                return try await executeNonDedupRequest(
                    baseRequestId: baseRequestId,
                    request: request,
                    execution: execution
                )
            }

            let runtimeKey = dedupRuntimeKey(
                baseRequestId: baseRequestId, responseType: responseType)
            logger.debug("请求标识符: \(baseRequestId), 类型: \(responseType)", category: .deduplication)

            /// 等待进行的请求的结果
            if let result: T = try await awaitOngoingResultIfAvailable(
                runtimeKey: runtimeKey,
                baseRequestId: baseRequestId,
                request: request
            ) {
                return result
            }

            logger.debug("创建新请求任务: \(baseRequestId)", category: .deduplication)
            return try await executeNewRequestWithTimeout(
                requestKey: runtimeKey,
                request: request,
                execution: execution
            )
        }

        return try await executeNonDedupRequest(
            baseRequestId: baseRequestId,
            request: request,
            execution: execution
        )
    }

    /// 取消指定请求
    func cancelRequest(request: NtkMutableRequest) {
        let baseRequestId = requestIdentifier(for: request)

        if isDeduplicationEnabled(for: request) {
            guard let responseType = request.responseType else {
                logger.warning("取消请求失败：缺少 ntk_response_type 信息，无法构造去重键", category: .deduplication)
                return
            }
            let runtimeKey = dedupRuntimeKey(
                baseRequestId: baseRequestId, responseType: responseType)
            // 去重场景：只取消对应的等待者，不直接取消底层 Task
            cancelDedupWaiter(runtimeKey: runtimeKey, instanceId: request.instanceIdentifier)
        } else {
            let requestInstanceId = request.instanceIdentifier
            let runtimeKey = nonDedupRuntimeKey(
                baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
            // 非去重场景：直接取消（行为不变）
            cancelTask(with: runtimeKey)
        }
    }

    /// 取消所有正在进行的请求
    func cancelAllRequests() {
        let allKeys = Array(ongoingRequests.keys)
        for key in allKeys {
            guard let entry = ongoingRequests[key] else { continue }
            // 取消所有 follower 的 waiterTask
            for (_, waiterTask) in entry.followerTasks {
                waiterTask.cancel()
            }
            // 取消底层 Task
            entry.task.cancel()
            ongoingRequests.removeValue(forKey: key)
        }
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
        let responseType = request.responseType
        return hasActiveTask(forBaseRequestId: baseRequestId, responseType: responseType)
    }
}

// MARK: - Dedup Follower Path
extension NtkTaskManager {

    /// 等待已有的去重请求结果（follower 路径）
    ///
    /// 每个 follower 通过独立的 wrapper Task 等待底层结果，
    /// 取消 wrapper Task 不影响底层执行 Task 和其他等待者。
    private func awaitOngoingResultIfAvailable<T: Sendable>(
        runtimeKey: RuntimeKey,
        baseRequestId: String,
        request: NtkMutableRequest
    ) async throws -> T? {
        guard var entry = ongoingRequests[runtimeKey] else { return nil }

        logger.info("发现重复请求，等待现有请求完成: \(baseRequestId)", category: .deduplication)

        let instanceId = request.instanceIdentifier
        // 只捕获 task 引用，不捕获整个 entry struct
        // entry.task 是 Task（引用类型），值拷贝后仍指向同一个 Task 实例
        let underlyingTask = entry.task

        // 创建独立的 wrapper Task
        let waiterTask = Task<Sendable, Error> {
            if Task.isCancelled { throw NtkError.response(.init(reason: .cancelled)) }
            let result = try await underlyingTask.value
            if Task.isCancelled { throw NtkError.response(.init(reason: .cancelled)) }
            return result
        }

        // 注册到 entry（从 guard var 到这里无 await，保证原子性）
        entry.followerTasks[instanceId] = waiterTask
        ongoingRequests[runtimeKey] = entry

        let capturedToken = entry.token

        defer {
            followerDidFinish(runtimeKey: runtimeKey, token: capturedToken, instanceId: instanceId)
        }

        do {
            let result = try await waiterTask.value
            // 检查 isCancelledRef（覆盖：底层成功但本实例已被取消）
            if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
                throw NtkError.response(.init(reason: .cancelled))
            }
            logger.info("重复请求完成，返回共享结果: \(baseRequestId)", category: .deduplication)
            guard let typedResult = result as? T else {
                logger.warning("共享任务类型不匹配，改为创建新任务: \(baseRequestId)", category: .deduplication)
                return nil
            }
            return typedResult
        } catch {
            // 如果本实例已被取消，统一抛 requestCancelled（而非底层的网络错误）
            if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
                throw NtkError.response(.init(reason: .cancelled))
            }
            logger.warning("现有请求失败，透传错误: \(baseRequestId), 错误: \(error)", category: .deduplication)
            throw error
        }
    }
}

// MARK: - Owner Path
extension NtkTaskManager {

    /// 执行非去重请求
    private func executeNonDedupRequest<T: Sendable>(
        baseRequestId: String,
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        logger.debug(
            "Request deduplication is disabled, executing with timeout only",
            category: .deduplication)
        let requestInstanceId = request.instanceIdentifier
        let runtimeKey = nonDedupRuntimeKey(
            baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
        return try await executeNewRequestWithTimeout(
            requestKey: runtimeKey,
            request: request,
            execution: execution
        )
    }

    /// 执行带超时控制的请求（通用方法）
    private func executeWithTimeout<T: Sendable>(
        timeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // 校验超时参数有效性，无效时使用全局默认值
        let validTimeout: TimeInterval
        if timeout > 0 && timeout.isFinite {
            // 夹取超时值，防止 UInt64 溢出（上限设为 100 年）
            validTimeout = min(timeout, 3_153_600_000)
        } else {
            let defaultTimeout = NtkConfiguration.current.builder.defaultTimeout
            logger.warning(
                "无效的超时时间: \(timeout)，使用全局默认值 \(defaultTimeout) 秒",
                category: .deduplication
            )
            validTimeout = defaultTimeout
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            // 确保退出时取消剩余任务（无论是正常返回还是抛出错误）
            defer { group.cancelAll() }

            // 添加实际请求任务
            group.addTask {
                if Task.isCancelled { throw NtkError.response(.init(reason: .cancelled)) }
                let result = try await execution()
                if Task.isCancelled { throw NtkError.response(.init(reason: .cancelled)) }
                return result
            }

            // 添加超时任务
            group.addTask {
                try await Task.sleep(
                    nanoseconds: UInt64(validTimeout * 1_000_000_000)
                )
                throw NtkError.response(.init(reason: .timedOut))
            }

            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NtkError.response(.init(reason: .cancelled))
            }
            return result
        }
    }

    /// 执行新请求并登记到任务表（owner 路径）
    ///
    /// 设计原理：
    /// - 先登记、后等待，并在 `defer` 中通过 `ownerDidFinish` 管理生命周期；
    /// - owner 完成后如果还有 follower 在等待，保留 entry；否则清理。
    private func executeNewRequestWithTimeout<T: Sendable>(
        requestKey: RuntimeKey,
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = request.timeout

        let entry = RequestTaskEntry(
            token: UUID(),
            task: Task<Sendable, Error> {
                return try await executeWithTimeout(timeout: timeout, execution: execution)
            },
            ownerInstanceId: request.instanceIdentifier
        )

        ongoingRequests[requestKey] = entry

        defer {
            ownerDidFinish(requestKey: requestKey, token: entry.token)
        }

        do {
            let result = try await entry.task.value
            // owner 拿到结果后检查自身取消状态
            if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
                throw NtkError.response(.init(reason: .cancelled))
            }
            logger.debug("请求成功完成: \(requestKey)", category: .deduplication)
            guard let typedResult = result as? T else {
                throw NtkError.request(.init(reason: .typeMismatch))
            }
            return typedResult
        } catch {
            // 统一检查：如果 owner 已被取消，优先抛 requestCancelled
            if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
                throw NtkError.response(.init(reason: .cancelled))
            }
            if let ntkError = error as? NtkError,
               case let .response(failure) = ntkError,
               failure.reason == .timedOut {
                logger.warning("请求超时: \(requestKey), 超时时间: \(timeout)秒", category: .deduplication)
            } else {
                logger.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
            }
            throw error
        }
    }
}

// MARK: - Lifecycle Management
extension NtkTaskManager {

    /// owner 完成时的清理逻辑
    ///
    /// 不调用 `entry.task.cancel()`，因为 owner 完成意味着底层 Task 已经完成
    /// （owner 是通过 `await entry.task.value` 等待的）。
    private func ownerDidFinish(requestKey: RuntimeKey, token: UUID) {
        guard var entry = ongoingRequests[requestKey], entry.token == token else { return }
        entry.ownerActive = false
        if entry.followerTasks.isEmpty {
            ongoingRequests.removeValue(forKey: requestKey)
        } else {
            ongoingRequests[requestKey] = entry
        }
    }

    /// follower 完成时的清理逻辑
    ///
    /// `entry.task.cancel()` 对已完成的 Task 调用是无害的（no-op）。
    /// 保留 cancel 调用是为了覆盖"owner 被取消 + 所有 follower 也完成/取消"的场景，
    /// 此时底层 Task 可能仍在运行。
    private func followerDidFinish(runtimeKey: RuntimeKey, token: UUID, instanceId: UUID) {
        guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
        entry.followerTasks.removeValue(forKey: instanceId)
        let totalWaiters = (entry.ownerActive ? 1 : 0) + entry.followerTasks.count
        if totalWaiters == 0 {
            entry.task.cancel()
            ongoingRequests.removeValue(forKey: runtimeKey)
        } else {
            ongoingRequests[runtimeKey] = entry
        }
    }

    /// 去重场景下取消指定等待者
    ///
    /// 如果取消的是 owner，标记 ownerActive = false；
    /// 如果取消的是 follower，cancel 其 waiterTask 并从映射中移除。
    /// 所有等待者都取消后，取消底层 Task。
    private func cancelDedupWaiter(runtimeKey: RuntimeKey, instanceId: UUID) {
        guard var entry = ongoingRequests[runtimeKey] else { return }

        if entry.ownerInstanceId == instanceId {
            entry.ownerActive = false
        } else if let waiterTask = entry.followerTasks[instanceId] {
            waiterTask.cancel()
            entry.followerTasks.removeValue(forKey: instanceId)
        } else {
            return
        }

        let totalWaiters = (entry.ownerActive ? 1 : 0) + entry.followerTasks.count
        if totalWaiters == 0 {
            entry.task.cancel()
            ongoingRequests.removeValue(forKey: runtimeKey)
        } else {
            ongoingRequests[runtimeKey] = entry
        }
    }

    /// 非去重场景下直接取消任务
    private func cancelTask(with key: RuntimeKey) {
        guard let entry = ongoingRequests[key] else { return }
        entry.task.cancel()
        ongoingRequests.removeValue(forKey: key)
    }
}

// MARK: - Key Generation & Utilities
extension NtkTaskManager {

    /// 构造"可复用"运行时键。
    private func dedupRuntimeKey(baseRequestId: String, responseType: String) -> RuntimeKey {
        "dedup|\(baseRequestId)|\(responseType)"
    }

    /// 构造"不可复用"运行时键。
    private func nonDedupRuntimeKey(baseRequestId: String, requestInstanceId: UUID) -> RuntimeKey {
        "\(nonDedupKeyPrefix(baseRequestId: baseRequestId))\(requestInstanceId.uuidString)"
    }

    private func nonDedupKeyPrefix(baseRequestId: String) -> String {
        "nodedup|\(baseRequestId)|"
    }

    /// 判断某个基础请求标识是否存在活跃任务。
    private func hasActiveTask(forBaseRequestId baseRequestId: String, responseType: String? = nil)
        -> Bool
    {
        if let type = responseType {
            let dedupKey = dedupRuntimeKey(baseRequestId: baseRequestId, responseType: type)
            if ongoingRequests[dedupKey] != nil { return true }
        } else {
            let dedupPrefix = "dedup|\(baseRequestId)|"
            if ongoingRequests.keys.contains(where: { $0.hasPrefix(dedupPrefix) }) {
                return true
            }
        }

        let prefix = nonDedupKeyPrefix(baseRequestId: baseRequestId)
        return ongoingRequests.keys.contains { $0.hasPrefix(prefix) }
    }

    private func requestIdentifier(for request: NtkMutableRequest) -> String {
        NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
    }

    private func isDeduplicationEnabled(for request: NtkMutableRequest) -> Bool {
        return NtkConfiguration.current.builder.isDeduplicationEnabled && request.isDeduplicationEnabled
    }
}
