# Wrapper Task 取消隔离方案设计

## 问题

去重场景下，多个 NtkNetwork 实例共享同一个底层 Task。任意一个实例调用 `cancelRequest`，会直接 `entry.task.cancel()` + 从字典移除，导致所有等待者都被影响。

此外，当前 `cancelRequest` 实际上几乎无效——底层执行链路中没有任何 `Task.checkCancellation()` 调用，取消标志被设置后无人检查。

## 目标

1. 取消一个等待者（follower），不影响其他等待者和底层执行 Task
2. 所有等待者（含 owner）都取消后，底层 Task 也取消（引用计数归零）
3. 补全取消检查点，让 `cancelRequest` 真正生效

## 术语

- **owner**：第一个发起请求的调用者，走 `executeNewRequestWithTimeout` 路径，创建底层 Task
- **follower**：后续相同请求的调用者，走 `awaitOngoingResultIfAvailable` 路径，等待底层 Task 结果
- **底层 Task**：`RequestTaskEntry.task`，执行实际网络请求
- **wrapper Task**：follower 创建的独立 Task，内部 await 底层 Task 的 value

## 设计权衡

**owner 取消后不会立即返回**：owner 在 `executeNewRequestWithTimeout` 中直接 `await entry.task.value`。当 owner 被取消时（`cancelDedupWaiter` 设置 `ownerActive = false`），如果还有 follower 在等待，底层 Task 不会被 cancel。owner 必须等到底层 Task 自然完成后，才能检查 `isCancelledRef` 并抛出 `requestCancelled`。

这是有意的设计权衡——避免给 owner 也包装 wrapper Task 带来的额外复杂度。从用户体验看，`NtkNetwork.cancel()` 是 async 方法，调用后立即返回；上层 `try await network.request()` 的等待延迟对已销毁的 UI 组件无感。

## 数据结构变更

```swift
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
```

总等待者数 = `(ownerActive ? 1 : 0) + followerTasks.count`

> 注：`RequestTaskEntry` 是 struct（值类型）。修改后必须写回字典 `ongoingRequests[key] = entry`。
> 所有对 entry 的读-改-写操作都在 `@NtkActor` 上串行执行，中间无 await 挂起点，保证原子性。

## 改动详解

### 1. `awaitOngoingResultIfAvailable` — follower 路径

当前代码：
```swift
let result = try await ongoingEntry.task.value  // 直接等待底层 Task
```

改为：
```swift
private func awaitOngoingResultIfAvailable<T: Sendable>(
    runtimeKey: RuntimeKey,
    baseRequestId: String,
    request: NtkMutableRequest          // 新增参数
) async throws -> T? {
    guard var entry = ongoingRequests[runtimeKey] else { return nil }

    logger.info("发现重复请求，等待现有请求完成: \(baseRequestId)", category: .deduplication)

    let instanceId = request.instanceIdentifier
    // 只捕获 task 引用，不捕获整个 entry struct
    // entry.task 是 Task（引用类型），值拷贝后仍指向同一个 Task 实例
    let underlyingTask = entry.task

    // 创建独立的 wrapper Task
    let waiterTask = Task<Sendable, Error> {
        try Task.checkCancellation()                // 进入前检查（防止先取消后执行的可重入）
        let result = try await underlyingTask.value // 等待底层结果
        try Task.checkCancellation()                // 拿到结果后检查
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
            throw NtkError.requestCancelled
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
            throw NtkError.requestCancelled
        }
        logger.warning("现有请求失败，透传错误: \(baseRequestId), 错误: \(error)", category: .deduplication)
        throw error
    }
}
```

**关键设计点：**
- `let underlyingTask = entry.task`：只捕获 Task 引用，避免闭包持有整个 struct 拷贝
- catch 路径中检查 `isCancelledRef`：解决"follower 被 cancel 但底层 Task 抛网络错误"时用户收到错误类型不一致的问题
- `waiterTask.cancel()` 不会中断 `await underlyingTask.value`（Swift 协作式取消），底层 Task 完成后 `checkCancellation` 才生效

### 2. `cancelRequest` — 去重场景改为取消 wrapper Task

```swift
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
        // 去重场景：只取消对应的等待者，不直接取消底层 Task
        cancelDedupWaiter(runtimeKey: runtimeKey, instanceId: request.instanceIdentifier)
    } else {
        let requestInstanceId = request.instanceIdentifier
        runtimeKey = nonDedupRuntimeKey(
            baseRequestId: baseRequestId, requestInstanceId: requestInstanceId)
        // 非去重场景：直接取消（行为不变）
        cancelTask(with: runtimeKey)
    }
}
```

### 3. `cancelDedupWaiter` — 新增方法

```swift
private func cancelDedupWaiter(runtimeKey: RuntimeKey, instanceId: UUID) {
    guard var entry = ongoingRequests[runtimeKey] else { return }

    if entry.ownerInstanceId == instanceId {
        // 取消的是 owner
        entry.ownerActive = false
    } else if let waiterTask = entry.followerTasks[instanceId] {
        // 取消的是 follower
        waiterTask.cancel()
        entry.followerTasks.removeValue(forKey: instanceId)
    } else {
        return  // 找不到对应的等待者，可能已完成
    }

    // 统一公式计算总等待者数
    let totalWaiters = (entry.ownerActive ? 1 : 0) + entry.followerTasks.count
    if totalWaiters == 0 {
        // 所有等待者都取消了，取消底层 Task
        entry.task.cancel()
        ongoingRequests.removeValue(forKey: runtimeKey)
    } else {
        ongoingRequests[runtimeKey] = entry
    }
}
```

### 4. `executeNewRequestWithTimeout` — owner 路径改动

```swift
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
            throw NtkError.requestCancelled
        }
        logger.debug("请求成功完成: \(requestKey)", category: .deduplication)
        guard let typedResult = result as? T else {
            throw NtkError.typeMismatch
        }
        return typedResult
    } catch {
        // 统一检查：如果 owner 已被取消，优先抛 requestCancelled
        // （覆盖底层抛 NtkError.requestTimeout / CancellationError / 网络错误等所有情况）
        if let cancelledRef = request.isCancelledRef, cancelledRef.isCancelled {
            throw NtkError.requestCancelled
        }
        if let ntkError = error as? NtkError, case .requestTimeout = ntkError {
            logger.warning("请求超时: \(requestKey), 超时时间: \(timeout)秒", category: .deduplication)
        } else {
            logger.error("请求执行失败: \(requestKey), 错误: \(error)", category: .deduplication)
        }
        throw error
    }
}
```

### 5. `ownerDidFinish` — 新增方法

```swift
private func ownerDidFinish(requestKey: RuntimeKey, token: UUID) {
    guard var entry = ongoingRequests[requestKey], entry.token == token else { return }
    entry.ownerActive = false
    // 统一公式（ownerActive 刚设为 false，等价于 followerTasks.count，但用统一公式更清晰）
    let totalWaiters = (entry.ownerActive ? 1 : 0) + entry.followerTasks.count
    if totalWaiters == 0 {
        // 没有 follower 在等了，可以清理
        ongoingRequests.removeValue(forKey: requestKey)
    } else {
        // 还有 follower 在等，保留 entry
        ongoingRequests[requestKey] = entry
    }
}
```

> 注：`ownerDidFinish` 不调用 `entry.task.cancel()`，因为 owner 完成意味着底层 Task 已经完成（owner 是通过 `await entry.task.value` 等待的）。

### 6. `followerDidFinish` — 新增方法

```swift
private func followerDidFinish(runtimeKey: RuntimeKey, token: UUID, instanceId: UUID) {
    guard var entry = ongoingRequests[runtimeKey], entry.token == token else { return }
    entry.followerTasks.removeValue(forKey: instanceId)
    let totalWaiters = (entry.ownerActive ? 1 : 0) + entry.followerTasks.count
    if totalWaiters == 0 {
        // 所有等待者都已完成/取消，取消底层 Task（如果还在运行的话）并清理
        entry.task.cancel()
        ongoingRequests.removeValue(forKey: runtimeKey)
    } else {
        ongoingRequests[runtimeKey] = entry
    }
}
```

> 注：`followerDidFinish` 中 `entry.task.cancel()` 对已完成的 Task 调用是无害的（no-op）。
> 这里保留 cancel 调用是为了覆盖"owner 被取消 + 所有 follower 也完成/取消"的场景，此时底层 Task 可能仍在运行。

### 7. `executeWithTimeout` — 补全 checkCancellation

```swift
private func executeWithTimeout<T: Sendable>(
    timeout: TimeInterval,
    execution: @escaping @Sendable () async throws -> T
) async throws -> T {
    // 超时参数校验逻辑不变...

    return try await withThrowingTaskGroup(of: T.self) { group in
        defer { group.cancelAll() }

        group.addTask {
            try Task.checkCancellation()       // 新增：执行前检查
            let result = try await execution()
            try Task.checkCancellation()       // 新增：执行后检查
            return result
        }

        group.addTask {
            try await Task.sleep(
                nanoseconds: UInt64(validTimeout * 1_000_000_000)
            )
            throw NtkError.requestTimeout
        }

        guard let result = try await group.next() else {
            throw NtkError.requestCancelled
        }
        return result
    }
}
```

### 8. `cancelAllRequests` 改动

```swift
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
```

### 9. `executeWithDeduplication` 入口 — 传递 request

```swift
if let result: T = try await awaitOngoingResultIfAvailable(
    runtimeKey: runtimeKey,
    baseRequestId: baseRequestId,
    request: request          // 新增参数
) {
    return result
}
```

### 10. 删除 `removeEntryIfTokenMatches`，更新 `cancelTask`

原有的 `removeEntryIfTokenMatches` 方法被 `ownerDidFinish` 和 `followerDidFinish` 替代，删除。

`cancelTask` 方法仅用于非去重场景，更新为自包含实现（不再依赖 `removeEntryIfTokenMatches`）：

```swift
private func cancelTask(with key: RuntimeKey) {
    guard let entry = ongoingRequests[key] else { return }
    entry.task.cancel()
    ongoingRequests.removeValue(forKey: key)
}
```

> 非去重场景下每个请求有独立的 runtimeKey，不存在 follower，直接取消并移除即可。

## 不变的部分

- `NtkMutableRequest` — 不需要新增属性，已有 `instanceIdentifier` 和 `isCancelledRef`
- `NtkNetwork.cancel()` — 调用方式不变
- `NtkDeduplicationInterceptor` — 不变
- `NtkCancellableState` — 不变
- 非去重路径 — 行为不变（每个请求独立 runtimeKey，直接 cancel）
- runtimeKey 构造逻辑 — 不变
- `hasActiveTask` — 不变
- `isRequestActive` — 不变

## 并发安全分析

所有对 `ongoingRequests` 字典的操作都在 `@NtkActor` 上串行执行：

| 方法 | 隔离 | await 挂起点 | 安全性 |
|------|------|-------------|--------|
| `awaitOngoingResultIfAvailable` 注册 follower | @NtkActor | guard var → 写回之间无 await | 原子 ✓ |
| `awaitOngoingResultIfAvailable` await waiterTask | @NtkActor | 挂起释放 actor，恢复后回到 actor | 安全 ✓ |
| `cancelDedupWaiter` | @NtkActor | 无 await | 原子 ✓ |
| `ownerDidFinish` (defer) | @NtkActor | 无 await | 原子 ✓ |
| `followerDidFinish` (defer) | @NtkActor | 无 await | 原子 ✓ |
| waiterTask 闭包内部 | 全局并发池 | 只访问捕获的 Task 引用（线程安全） | 安全 ✓ |

**竞态场景分析：**

`cancelDedupWaiter` 与 `followerDidFinish` 可能对同一个 follower 操作：
1. `cancelDedupWaiter` 先执行：移除 follower，写回 entry
2. `followerDidFinish` 后执行：`entry.followerTasks.removeValue(forKey: instanceId)` 对不存在的 key 是 no-op，totalWaiters 计算正确

`cancelDedupWaiter` 与 `ownerDidFinish` 可能对 owner 操作：
1. `cancelDedupWaiter` 设置 `ownerActive = false`
2. `ownerDidFinish` 再次设置 `ownerActive = false`（幂等），totalWaiters 计算正确

## 完整场景推演

### 场景 1：正常去重（无取消）
```
T1: A 发起请求 → executeNewRequestWithTimeout → 创建 entry(ownerActive=true, ownerInstanceId=A)
T2: B 发起相同请求 → awaitOngoingResultIfAvailable → 创建 waiterTask, followerTasks[B]=waiterTask
T3: 底层 Task 完成
T4: A 的 await entry.task.value 恢复 → isCancelledRef 未取消 → 返回结果
T5: B 的 waiterTask 内 await underlyingTask.value 恢复 → checkCancellation 通过 → waiterTask 完成
T6: B 的 await waiterTask.value 恢复 → isCancelledRef 未取消 → 返回结果
T7: A 的 defer → ownerDidFinish: ownerActive=false, followerTasks 可能已空 → 清理
T8: B 的 defer → followerDidFinish: 移除 B, 检查 totalWaiters → 清理
（T7/T8 顺序不确定，但都在 @NtkActor 上串行，两种顺序都安全）
```

### 场景 2：follower 取消，owner 继续
```
T1: A(owner) 发起请求
T2: B(follower) 加入, followerTasks[B]=waiterTask
T3: 用户取消 B → NtkNetwork.cancel():
    - isCancelledRef.cancel()（B 的取消标志）
    - cancelDedupWaiter: waiterTask.cancel(), 从 followerTasks 移除 B
    - totalWaiters = 1(owner) → 底层 Task 不取消
T4: 底层 Task 完成
T5: A 的 await 恢复 → isCancelledRef 未取消 → 返回结果 ✓
T6: B 的 waiterTask 内 await 恢复 → checkCancellation 抛 CancellationError
T7: B 的 await waiterTask.value 抛错 → catch 中检查 isCancelledRef → 抛 NtkError.requestCancelled
T8: B 的 defer → followerDidFinish: B 已不在 followerTasks 中 → guard 通过但 removeValue 是 no-op
```

### 场景 3：owner 取消，follower 继续
```
T1: A(owner) 发起请求
T2: B(follower) 加入
T3: 用户取消 A → NtkNetwork.cancel():
    - isCancelledRef.cancel()（A 的取消标志）
    - cancelDedupWaiter: ownerActive=false
    - totalWaiters = 1(B) → 底层 Task 不取消
T4: 底层 Task 完成
T5: B 的 waiterTask 恢复 → checkCancellation 通过 → B 拿到结果 ✓
T6: A 的 await entry.task.value 恢复 → 检查 isCancelledRef → 抛 NtkError.requestCancelled
T7: B 的 defer → followerDidFinish: 移除 B, totalWaiters=(false?0:1)+0=0 → 清理 entry
T8: A 的 defer → ownerDidFinish: guard 失败（entry 已被 T7 移除）→ return
（或 T8 先于 T7：ownerDidFinish 设 ownerActive=false, totalWaiters=1(B) → 保留 entry → T7 再清理）
```

### 场景 4：所有人取消
```
T1: A(owner) 发起请求
T2: B(follower) 加入
T3: 取消 B → cancelDedupWaiter: waiterTask.cancel(), 移除 B, totalWaiters=1(owner)
T4: 取消 A → cancelDedupWaiter: ownerActive=false, totalWaiters=0
    → entry.task.cancel() → 底层 Task 被取消 ✓
    → 从字典移除
T5: 底层 Task 因取消而完成（抛 CancellationError）
T6: A 的 await entry.task.value 抛 CancellationError → catch 中检查 isCancelledRef → 抛 requestCancelled
T7: B 的 waiterTask 内 await 抛 CancellationError → checkCancellation 也抛 → waiterTask 完成
T8: defer 中 guard 失败（entry 已被 T4 移除）→ return
```

### 场景 5：取消后重新发起
```
T1: A 发起请求 → owner
T2: 取消 A → cancelDedupWaiter: ownerActive=false, totalWaiters=0 → 底层取消 + 移除
T3: C 发起相同请求 → 字典中无 entry → executeNewRequestWithTimeout → 创建新 Task ✓
```

### 场景 6：底层 Task 超时
```
T1: A(owner) 发起请求
T2: B(follower) 加入
T3: 底层 Task 超时 → executeWithTimeout 中超时任务先完成 → 抛 NtkError.requestTimeout
T4: A 的 await entry.task.value 抛 requestTimeout → A 收到 requestTimeout ✓
T5: B 的 waiterTask 内 await underlyingTask.value 抛 requestTimeout → waiterTask.value 抛错
T6: B 的 catch → isCancelledRef 未取消 → 透传 requestTimeout ✓
```

### 场景 7：非去重请求取消（行为不变）
```
A 发起请求（dedup disabled）→ 独立 runtimeKey（含 instanceIdentifier）
B 发起相同请求（dedup disabled）→ 另一个独立 runtimeKey
取消 A → cancelTask(with: A的key) → 只影响 A ✓
B 继续正常执行 ✓
```

### 场景 8：follower 被取消，但底层 Task 抛网络错误
```
T1: A(owner) 发起请求
T2: B(follower) 加入
T3: 取消 B → waiterTask.cancel()
T4: 底层 Task 因网络错误失败
T5: B 的 waiterTask 内 await 抛网络错误（不是 CancellationError）
T6: B 的 catch → 检查 isCancelledRef → 已取消 → 抛 NtkError.requestCancelled ✓
    （用户收到的是取消错误，而非网络错误，符合预期）
```

## 测试计划

### 恢复的测试
- `testDedupFollowerCancelDoesNotAffectSharedWaiting` — 取消注释并调整

### 新增测试
1. **testDedupOwnerCancelDoesNotAffectFollower** — owner 取消，follower 正常拿到结果（场景 3）
2. **testDedupAllWaitersCancelledCancelsUnderlyingTask** — 所有等待者取消后底层 Task 被取消（场景 4）
3. **testDedupCancelAndReenterCreatesNewTask** — 全部取消后重新发起，创建新 Task（场景 5）
4. **testDedupMultipleFollowersCancelOneByOne** — 多个 follower 逐个取消，最后一个取消时底层才取消
5. **testDedupFollowerCancelReceivesRequestCancelledNotNetworkError** — follower 取消后收到 requestCancelled 而非底层错误（场景 8）

### 现有测试（应全部通过）
- `testDisabledDeduplicationKeepsLatestTaskMapped`
- `testDifferentResponseTypesShouldNotDedup`
- `testCancelRequestCancelsOnlyCurrentDisabledDeduplicationTask`
- `testEnabledDeduplicationSharesSingleExecution`
- `testCancelAndReenterDedupRequestKeepsNewTaskMapped`
