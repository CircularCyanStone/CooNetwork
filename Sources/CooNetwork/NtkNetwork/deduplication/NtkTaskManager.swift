//
//  NtkTaskManager.swift
//  CNtk
//

import Foundation

/// 网络请求去重调度中心（全局单例 actor）。
///
/// # 职责
/// 多个调用方请求同一资源时，只让第一个调用方（primary）真正执行网络任务，后续命中同一
/// `ExecutionKey` 的调用方（waiter）复用该任务的结果，避免重复发请求。
///
/// # 核心设计
/// - 主表 `inFlightTasks` 按执行键登记进行中的共享任务及所有等待者；`executionKeyByInstanceID`
///   是反向索引，取消时先由请求实例 ID 定位执行键。
/// - 每个调用方（primary 或 waiter）各自持有一个"等待器"（`TaskWaiter`，由 `makeWaiter`
///   创建）：取消任意一个只影响该调用方自己；共享网络任务只会在**没有任何等待者**时才被取消。
/// - 取消必须"立即生效"（不等网络请求返回）：`await 任务.value` 不响应等待者的取消，
///   所以等待一律经过 `TaskWaiter`（挂起在自持的 continuation 上），manager 取消时
///   直接调 `waiter.cancel()` 当场送达 `requestCancelled`。
/// - 两张表的登记与摘除必须成对完成，任何路径都不能只改一边。
actor NtkTaskManager {

    /// 一次共享执行在字典中的键，决定"哪些请求共享同一个底层任务"。
    ///
    /// - `.shared(NtkDeduplicationKey)`：去重键可用。相同 key 意味着同一资源 + 同响应类型 +
    ///   同超时 + 同流水线边界，可以安全共享一次网络执行。
    /// - `.isolated(UUID)`：去重键不可用（构建失败或功能关闭）。用请求实例自己的 UUID 隔离，
    ///   保证永不与他人共享，但仍走同一套登记/取消/超时逻辑。
    private enum ExecutionKey: Hashable, Sendable {
        case shared(NtkDeduplicationKey)
        case isolated(UUID)
    }

    /// 一次共享执行的全部状态：一个真正的网络任务 + 它的所有等待者。
    ///
    /// 引用计数语义：`primaryActive || !waiterTasks.isEmpty` 表示"还有人需要这个任务的结果"。
    /// 只要有人等待，entry 就保留；全部离开后取消 `sharedTask` 并清理 entry。
    private struct SharedTaskEntry {
        /// 本代 entry 的唯一标识。`token` 让旧任务的 defer 清理无法误删同 key 下重入的新 entry。
        let token: UUID
        /// 真正执行网络请求的任务，全程只创建一次，所有等待者共享它的结果。
        let sharedTask: Task<Sendable, Error>
        /// primary 自己的等待器：`value()` 挂起等待；manager 取消时直接调 `cancel()`，
        /// 只会让 primary 立刻退出，不碰 `sharedTask`。
        let primaryWaiter: TaskWaiter
        /// primary 请求实例 ID，用于反向索引和"取消的是谁"的判断。
        let primaryInstanceId: UUID
        /// primary 的日志上下文（requestID + identity），用于去重生命周期日志。
        let primaryLogContext: String
        /// primary 是否仍在等待；置为 false 表示它已离开（完成/失败/被取消）。
        var primaryActive = true
        /// 每个 waiter 请求实例 ID → 它的等待器。
        var waiterTasks: [UUID: TaskWaiter] = [:]
        /// 每个 waiter 请求实例 ID → 日志上下文。
        var waiterLogContexts: [UUID: String] = [:]
    }

    /// 主表：执行键 → 进行中共享执行的登记。有 entry 即代表该 key 下有人正在执行。
    private var inFlightTasks: [ExecutionKey: SharedTaskEntry] = [:]

    /// 反向索引：请求实例 ID → 执行键。取消和活跃态查询只读这张表，绝不从可变请求内容
    /// 重新推导键——请求可能在执行中被修改，从内容推导会定位到错误的任务。
    private var executionKeyByInstanceID: [UUID: ExecutionKey] = [:]

    static let shared = NtkTaskManager()

    private init() {}

    /// 去重执行的统一入口，所有请求（有/无去重键）都走这里。
    ///
    /// 流程：① 已取消的请求直接失败；② 有去重键时先尝试复用进行中的共享任务
    /// （`tryReuseInFlightTask`），命中即作为 waiter 返回共享结果；③ 未命中或没有去重键时，
    /// 作为 primary 创建新任务。
    ///
    /// 不变量：只有成功建立去重键的执行才能查找共享任务；key 缺失必须永远独立执行。
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
        let executionKey = deduplicationKey.map(ExecutionKey.shared) ?? .isolated(request.instanceIdentifier)
        let timeoutForExecution = deduplicationKey?.effectiveTimeout ?? effectiveTimeout
        let logContext = Self.logContext(for: request, deduplicationKey: deduplicationKey)

        // 只有已经成功建立去重 key 的执行可以查找共享任务；key 缺失必须始终独立执行。
        if deduplicationKey != nil,
           let result: T = try await tryReuseInFlightTask(
               executionKey: executionKey,
               request: request,
               logContext: logContext
           ) {
            return result
        }

        return try await executeNewRequestWithTimeout(
            executionKey: executionKey,
            request: request,
            effectiveTimeout: timeoutForExecution,
            logContext: logContext,
            execution: execution
        )
    }

    /// 取消指定请求实例的等待：只取消该实例自己，共享任务是否保留由 `cancelWaiter` 决定。
    func cancelRequest(instanceIdentifier: UUID) async {
        guard let executionKey = executionKeyByInstanceID[instanceIdentifier] else { return }
        await cancelWaiter(executionKey: executionKey, instanceIdentifier: instanceIdentifier)
    }

    /// 取消全部进行中的执行：先摘掉所有等待者，再取消共享任务，最后清空两张表。
    /// 用途：进程退出、账号切换等需要立即终止所有网络活动的场景。
    func cancelAllRequests() async {
        for (executionKey, entry) in inFlightTasks {
            if entry.primaryActive {
                logger.debug(
                    "去重主请求已取消：\(entry.primaryLogContext)；影响=其他等待者不受影响。",
                    category: .deduplication
                )
            }
            await entry.primaryWaiter.cancel()
            for (instanceIdentifier, waiterTask) in entry.waiterTasks {
                let logContext = entry.waiterLogContexts[instanceIdentifier]
                    ?? "requestID=\(instanceIdentifier.uuidString)"
                logger.debug(
                    "去重等待请求已取消：\(logContext)；影响=仅取消当前等待，不取消共享网络任务。",
                    category: .deduplication
                )
                await waiterTask.cancel()
            }
            entry.sharedTask.cancel()
            removeAllInstanceIndexes(for: entry, executionKey: executionKey)
        }
        inFlightTasks.removeAll()
        executionKeyByInstanceID.removeAll()
    }

    func activeRequestCount() -> Int {
        inFlightTasks.count
    }

    func isRequestActive(instanceIdentifier: UUID) -> Bool {
        executionKeyByInstanceID[instanceIdentifier] != nil
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
                    "去重任务执行超时：\(logContext)，原因=超过 \(effectiveTimeout)s 未完成；影响=本次及等待该任务的请求失败。",
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
            "去重任务执行失败：\(logContext)，原因=\(String(reflecting: type(of: error)))；影响=本次及等待该任务的请求收到失败结果。",
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

    /// 为共享任务创建"等待器"（`TaskWaiter`）：一个自持挂起点的结果槽 + 一个结果转发器。
    ///
    /// ## 为什么不能直接 `await` 共享任务（设计目的）
    /// Swift 的 `await 任务.value` 不响应等待者的取消：等待者收到取消信号后，这个等待
    /// 不会中断，会一直挂到被等待任务完成。旧实现直接 `await sharedTask.value`，取消要
    /// 等接口返回、走到下一个 `Task.isCancelled` 检查点才能抛错——取消被推迟到"接口返回后"
    /// （`fe5e90b` 修复的就是这个"取消不及时"）。
    ///
    /// ## 为什么需要一个等待器 + 转发器
    /// 要"立即取消"，等待者必须挂在一个**自己能随时唤醒**的挂起点上：`TaskWaiter` 用
    /// `withCheckedThrowingContinuation` 把挂起点存在自己的属性里，manager 取消时直接调
    /// `waiter.cancel()` 就能当场 `resume(.failure(requestCancelled))`。而 `await
    /// sharedTask.value` 的挂起点在任务内部，谁也无法主动唤醒它。因此：
    /// - 调用方 `await waiter.value()` 等待结果，manager 调 `waiter.cancel()` 立即取消；
    /// - `startResultForwarder` 专职等接口、把结果写进 waiter——它无人持有引用、永不
    ///   被取消，网络结果不会因任何等待者被取消而丢失。
    ///
    /// ## 效果
    /// 取消某个等待者 → 该调用方立即收到 `NtkError.requestCancelled` 退出；
    /// 共享网络任务与其他等待者完全不受影响。
    private static func makeWaiter(for underlyingTask: Task<Sendable, Error>) -> TaskWaiter {
        let waiter = TaskWaiter()
        startResultForwarder(from: underlyingTask, into: waiter)
        return waiter
    }

    /// "结果转发器"：专职等待接口返回，把结果写进 waiter 的结果槽。
    ///
    /// 为什么它必须是独立任务：`await 任务.value` 不响应等待者的取消，谁挂在这上面，谁就
    /// 无法立即响应取消。所以这个 await 只能由"永远不会被取消"的任务承担——本转发器无人
    /// 持有引用、不属于任何结构化并发，永远不会收到取消信号；网络结果也就永远不会因任何
    /// 等待者被取消而丢失。
    private static func startResultForwarder(
        from underlyingTask: Task<Sendable, Error>,
        into waiter: TaskWaiter
    ) {
        Task {
            do {
                await waiter.complete(.success(try await underlyingTask.value))
            } catch {
                await waiter.complete(.failure(error))
            }
        }
    }


    /// 作为 primary 创建并等待一次新的共享执行。
    ///
    /// 关键顺序：先在两张表中完整登记 entry 和反向索引，之后才第一次 await。
    /// 原因：`await` 会让出 actor 控制权，若期间别的任务调用 `cancelRequest`，必须能通过
    /// 反向索引立刻找到并取消本 primary；先登记再等待保证取消永不丢失目标。
    ///
    /// `defer { primaryDidFinish }` 保证无论成功/失败/取消，primary 都会从共享执行中退出。
    private func executeNewRequestWithTimeout<T: Sendable>(
        executionKey: ExecutionKey,
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
        let entry = SharedTaskEntry(
            token: UUID(),
            sharedTask: underlyingTask,
            primaryWaiter: Self.makeWaiter(for: underlyingTask),
            primaryInstanceId: request.instanceIdentifier,
            primaryLogContext: logContext
        )

        // 先完整登记 primary，再第一次 await，保证 cancel 可立即通过实例反向索引定位。
        inFlightTasks[executionKey] = entry
        registerInstanceIndex(request.instanceIdentifier, for: executionKey)
        logger.debug(
            "去重新任务已创建：\(logContext)，原因=没有可复用的进行中任务，超时=\(effectiveTimeout)s；影响=后续相同请求将等待此任务。",
            category: .deduplication
        )

        defer {
            primaryDidFinish(executionKey: executionKey, token: entry.token)
        }

        do {
            let result = try await entry.primaryWaiter.value
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

    /// 尝试复用进行中的共享任务：命中则以 waiter 身份登记并等待其结果。
    ///
    /// 返回 `nil` 表示没有可复用的任务（调用方需自行创建）；非 nil 为共享任务的结果。
    /// 与 primary 路径相同的顺序约束：waiter 登记、entry 更新、反向索引必须在第一次 await 前
    /// 一起完成，否则 await 让出控制权后取消无法定位到本 waiter。
    private func tryReuseInFlightTask<T: Sendable>(
        executionKey: ExecutionKey,
        request: NtkMutableRequest,
        logContext: String
    ) async throws -> T? {
        guard var entry = inFlightTasks[executionKey] else { return nil }

        let instanceIdentifier = request.instanceIdentifier
        let underlyingTask = entry.sharedTask
        let waiterTask = Self.makeWaiter(for: underlyingTask)

        // waiter 的等待句柄、entry 和反向索引必须在首次 await 前一起写入。
        entry.waiterTasks[instanceIdentifier] = waiterTask
        entry.waiterLogContexts[instanceIdentifier] = logContext
        inFlightTasks[executionKey] = entry
        registerInstanceIndex(instanceIdentifier, for: executionKey)
        logger.debug(
            "去重命中进行中任务：\(logContext)；影响=当前请求复用已有网络任务，不再发起新的请求。",
            category: .deduplication
        )
        let token = entry.token

        defer {
            waiterDidFinish(
                executionKey: executionKey,
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

    /// 反向索引的增删必须与 `inFlightTasks` 的登记/摘除成对出现；删除前校验当前值，
    /// 防止旧请求的清理误删同实例 ID 新登记的反向索引。
    private func registerInstanceIndex(_ instanceIdentifier: UUID, for executionKey: ExecutionKey) {
        executionKeyByInstanceID[instanceIdentifier] = executionKey
    }

    private func removeInstanceIndex(_ instanceIdentifier: UUID, for executionKey: ExecutionKey) {
        guard executionKeyByInstanceID[instanceIdentifier] == executionKey else { return }
        executionKeyByInstanceID.removeValue(forKey: instanceIdentifier)
    }

    /// 摘除 entry 关联的全部反向索引（primary + 所有 waiter）。
    private func removeAllInstanceIndexes(for entry: SharedTaskEntry, executionKey: ExecutionKey) {
        removeInstanceIndex(entry.primaryInstanceId, for: executionKey)
        for instanceIdentifier in entry.waiterTasks.keys {
            removeInstanceIndex(instanceIdentifier, for: executionKey)
        }
    }

    /// primary 完成（成功/失败/取消）后从共享执行中退出。
    /// `token` 防重入：同 key 下若已有新 entry（旧任务完成时新任务已登记），旧 primary 的
    /// defer 不得清理新 entry，直接返回。
    private func primaryDidFinish(executionKey: ExecutionKey, token: UUID) {
        guard var entry = inFlightTasks[executionKey], entry.token == token else { return }
        entry.primaryActive = false
        removeInstanceIndex(entry.primaryInstanceId, for: executionKey)
        removeEntryIfNoWaiters(entry, executionKey: executionKey)
    }

    /// waiter 完成（成功/失败/取消）后从共享执行中退出，并摘除自己的反向索引。
    private func waiterDidFinish(executionKey: ExecutionKey, token: UUID, instanceIdentifier: UUID) {
        guard var entry = inFlightTasks[executionKey], entry.token == token else { return }
        entry.waiterTasks.removeValue(forKey: instanceIdentifier)
        entry.waiterLogContexts.removeValue(forKey: instanceIdentifier)
        removeInstanceIndex(instanceIdentifier, for: executionKey)
        removeEntryIfNoWaiters(entry, executionKey: executionKey)
    }

    /// 维护"等待者引用计数"不变量：还有任何人等待就保留 entry；全走光才取消共享任务并清理。
    /// 这是共享任务生命周期收敛的唯一出口之一（另一个是 `cancelWaiter`）。
    private func removeEntryIfNoWaiters(_ entry: SharedTaskEntry, executionKey: ExecutionKey) {
        let hasWaiters = entry.primaryActive || !entry.waiterTasks.isEmpty
        if hasWaiters {
            inFlightTasks[executionKey] = entry
        } else {
            entry.sharedTask.cancel()
            inFlightTasks.removeValue(forKey: executionKey)
            logger.debug(
                "去重任务已清理：\(entry.primaryLogContext)，原因=没有等待者；影响=底层任务已取消或已完成。",
                category: .deduplication
            )
        }
    }

    /// 取消单个请求实例的等待（由 `cancelRequest` 调用）。
    ///
    /// 区分三种情况：目标是 primary → 置 `primaryActive=false` 并取消其等待句柄；目标是
    /// waiter → 从表中移除并取消其等待句柄；两者都不是 → 仅清理可能残留的反向索引。
    /// 取消后若仍有人等待，共享任务继续执行；否则一并取消并清理 entry。
    private func cancelWaiter(executionKey: ExecutionKey, instanceIdentifier: UUID) async {
        guard var entry = inFlightTasks[executionKey] else {
            removeInstanceIndex(instanceIdentifier, for: executionKey)
            return
        }

        if entry.primaryInstanceId == instanceIdentifier {
            entry.primaryActive = false
            await entry.primaryWaiter.cancel()
            removeInstanceIndex(instanceIdentifier, for: executionKey)
            logger.debug(
                "去重主请求已取消：\(entry.primaryLogContext)；影响=其他等待者不受影响。",
                category: .deduplication
            )
        } else if let waiterTask = entry.waiterTasks.removeValue(forKey: instanceIdentifier) {
            await waiterTask.cancel()
            removeInstanceIndex(instanceIdentifier, for: executionKey)
            let logContext = entry.waiterLogContexts.removeValue(forKey: instanceIdentifier)
                ?? "requestID=\(instanceIdentifier.uuidString)"
            logger.debug(
                "去重等待请求已取消：\(logContext)；影响=仅取消当前等待，不取消共享网络任务。",
                category: .deduplication
            )
        } else {
            removeInstanceIndex(instanceIdentifier, for: executionKey)
            return
        }

        if entry.primaryActive || !entry.waiterTasks.isEmpty {
            inFlightTasks[executionKey] = entry
        } else {
            entry.sharedTask.cancel()
            removeAllInstanceIndexes(for: entry, executionKey: executionKey)
            inFlightTasks.removeValue(forKey: executionKey)
            logger.debug(
                "去重任务已清理：\(entry.primaryLogContext)，原因=没有等待者；影响=底层任务已取消或已完成。",
                category: .deduplication
            )
        }
    }
}

// MARK: - 等待句柄支持类型

/// 等待器：一个"只写一次的结果槽 + 自持挂起点"，是"每个等待者可独立取消"的载体。
///
/// 目的：让取消能"当场送达"等待者（见 `makeWaiter`）。等待者 `await 任务.value` 时挂起点
/// 在任务内部、谁也无法主动唤醒；而这里用 `withCheckedThrowingContinuation` 把挂起点存进
/// 自己的 `continuation` 属性，manager 调 `cancel()` 就能随时 resume 唤醒。
///
/// 原理：`result` 只允许第一次写入（`finish` 的 guard）。`complete`（网络结果到达）和
/// `cancel`（外部取消）可能来自不同任务并发调用，actor 隔离保证串行，且两个事件只有
/// 一个生效、等待者恰好被唤醒一次（对同一 continuation 重复 resume 会触发 fatal error）。
///
/// 效果：`value()` 挂起调用方；`complete`/`cancel` 唤醒并交付结果或取消错误；
/// 结果先到则后续 `value()` 直接返回，不重复挂起。
private actor TaskWaiter {
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
