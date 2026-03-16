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
///   - nodedup|\(baseRequestId)|\(requestInstanceId)：同实例请求独立执行。
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
    }

    /// 运行中任务表
    private var ongoingRequests: [RuntimeKey: RequestTaskEntry] = [:]

    /// 单例
    static let shared = NtkTaskManager()

    private init() {}

    /// 执行请求（统一入口）
    func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
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
                baseRequestId: baseRequestId
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

    /// 取消指定请求
    func cancelRequest(request: NtkMutableRequest) {
        let baseRequestId = requestIdentifier(for: request)

        let runtimeKey: RuntimeKey
        if isDeduplicationEnabled(for: request) {
            if let responseType = request.responseType {
                runtimeKey = dedupRuntimeKey(
                    baseRequestId: baseRequestId, responseType: responseType)
            } else {
                logger.warning("取消请求失败：缺少 ntk_response_type 信息，无法构造去重键", category: .deduplication)
                return
            }
        } else {
            let requestInstanceId = request.instanceIdentifier
            runtimeKey = nonDedupRuntimeKey(
                baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
        }
        cancelTask(with: runtimeKey)
    }

    /// 取消所有正在进行的请求
    func cancelAllRequests() {
        let allKeys = Array(ongoingRequests.keys)
        for key in allKeys {
            cancelTask(with: key)
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

// MARK: - Private Methods
extension NtkTaskManager {

    private func awaitOngoingResultIfAvailable<T: Sendable>(
        runtimeKey: RuntimeKey,
        baseRequestId: String
    ) async throws -> T? {
        guard let ongoingEntry = ongoingRequests[runtimeKey] else {
            return nil
        }
        logger.info("发现重复请求，等待现有请求完成: \(baseRequestId)", category: .deduplication)
        do {
            let result = try await ongoingEntry.task.value
            logger.info("重复请求完成，返回共享结果: \(baseRequestId)", category: .deduplication)
            guard let typedResult = result as? T else {
                logger.warning("共享任务类型不匹配，改为创建新任务: \(baseRequestId)", category: .deduplication)
                return nil
            }
            return typedResult
        } catch {
            logger.warning("现有请求失败，透传错误: \(baseRequestId), 错误: \(error)", category: .deduplication)
            throw error
        }
    }

    /// 执行带超时控制的请求（通用方法）
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    private func executeWithTimeout<T: Sendable>(
        timeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // 校验超时参数有效性，无效时使用默认值 60 秒
        let validTimeout: TimeInterval
        if timeout > 0 && timeout.isFinite {
            // 夹取超时值，防止 UInt64 溢出（上限设为 100 年）
            validTimeout = min(timeout, 3_153_600_000)
        } else {
            logger.warning(
                "无效的超时时间: \(timeout)，使用默认值 60 秒",
                category: .deduplication
            )
            validTimeout = 60.0
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            // 确保退出时取消剩余任务（无论是正常返回还是抛出错误）
            defer { group.cancelAll() }

            // 添加实际请求任务
            group.addTask {
                return try await execution()
            }

            // 添加超时任务
            group.addTask {
                try await Task.sleep(
                    nanoseconds: UInt64(validTimeout * 1_000_000_000)
                )
                throw NtkError.requestTimeout
            }

            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }
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
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = request.timeout

        let entry = RequestTaskEntry(
            token: UUID(),
            task: Task<Sendable, Error> {
                return try await executeWithTimeout(timeout: timeout, execution: execution)
            })

        ongoingRequests[requestKey] = entry

        defer {
            removeEntryIfTokenMatches(requestKey: requestKey, token: entry.token)
        }

        do {
            let result = try await entry.task.value
            logger.debug("请求成功完成: \(requestKey)", category: .deduplication)
            if let typedResult = result as? T {
                return typedResult
            } else {
                throw NtkError.typeMismatch
            }
        } catch let error as NtkError {
            if case .requestTimeout = error {
                logger.warning("请求超时: \(requestKey), 超时时间: \(timeout)秒", category: .deduplication)
            } else {
                logger.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
            }
            throw error
        } catch {
            logger.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
            throw error
        }
    }

    /// 构造“可复用”运行时键。
    ///
    /// 输入：baseRequestId（由请求内容计算的稳定标识）。
    /// 输出：dedup 前缀键；相同输入得到相同输出，用于去重命中。
    private func dedupRuntimeKey(baseRequestId: String, responseType: String) -> RuntimeKey {
        "dedup|\(baseRequestId)|\(responseType)"
    }

    /// 构造“不可复用”运行时键。
    ///
    /// 输入：baseRequestId。
    /// 输出：包含请求实例 ID 的唯一键。
    private func nonDedupRuntimeKey(baseRequestId: String, requestInstanceId: UUID) -> RuntimeKey {
        "\(nonDedupKeyPrefix(baseRequestId: baseRequestId))\(requestInstanceId.uuidString)"
    }

    private func nonDedupKeyPrefix(baseRequestId: String) -> String {
        "nodedup|\(baseRequestId)|"
    }

    /// 判断某个基础请求标识是否存在活跃任务。
    ///
    /// 设计原理：
    /// - dedup 场景查单键；
    /// - non-dedup 场景按前缀聚合判断。
    ///
    /// 产出作用：
    /// - 对外提供与策略无关的“请求是否活跃”统一语义。
    private func hasActiveTask(forBaseRequestId baseRequestId: String, responseType: String? = nil)
        -> Bool
    {
        // 1. 优先检查去重任务
        // 由于 Key 包含类型信息，这里只能通过前缀匹配
        if let type = responseType {
            // 精确匹配
            let dedupKey = dedupRuntimeKey(baseRequestId: baseRequestId, responseType: type)
            if ongoingRequests[dedupKey] != nil { return true }
        } else {
            // 模糊匹配
            let dedupPrefix = "dedup|\(baseRequestId)|"
            if ongoingRequests.keys.contains(where: { $0.hasPrefix(dedupPrefix) }) {
                return true
            }
        }

        // 2. 再遍历检查非去重任务（O(N) 遍历）
        let prefix = nonDedupKeyPrefix(baseRequestId: baseRequestId)
        return ongoingRequests.keys.contains { $0.hasPrefix(prefix) }
    }

    private func cancelTask(with key: RuntimeKey) {
        guard let entry = ongoingRequests[key] else {
            return
        }
        entry.task.cancel()
        removeEntryIfTokenMatches(requestKey: key, token: entry.token)
    }

    private func removeEntryIfTokenMatches(requestKey: RuntimeKey, token: UUID) {
        guard let current = ongoingRequests[requestKey], current.token == token else {
            return
        }
        ongoingRequests.removeValue(forKey: requestKey)
    }

    private func requestIdentifier(for request: NtkMutableRequest) -> String {
        NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
    }

    private func isDeduplicationEnabled(for request: NtkMutableRequest) -> Bool {
        NtkDeduplicationConfig.shared.isGloballyEnabled && request.isDeduplicationEnabled
    }

}
