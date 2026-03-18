# 取消请求设计问题

## 问题描述

### 当前行为

当多个 `NtkNetwork` 实例发起相同请求时，会去重并共享同一个 Task。如果用户取消其中一个实例，会导致所有实例都被取消。

### 场景示例

```swift
// 组件A加载头像 → taskA
let networkA = NtkAF<MyModel>.withAF(request)
let taskA = networkA.request()

// 组件B也需要头像 → taskB 去重等待 taskA
let networkB = NtkAF<MyModel>.withAF(request)  // 相同的 request
let taskB = networkB.request()

// 用户切换Tab，组件B销毁
taskB.cancel()

// 当前问题：taskA 也被取消了！组件A的头像加载失败
```

### 问题根源

```swift
// NtkTaskManager.swift:174
let result = try await ongoingEntry.task.value

// 所有实例等待的是同一个 Task 实例
// task.cancel() 会影响所有等待者
```

## 提出的解决方案

### 核心思路

每个等待者使用独立的 wrapper Task，底层共享执行 Task：

```swift
// 不直接等待底层 Task
// let result = try await ongoingEntry.task.value

// 而是创建 wrapper Task
let wrapperTask = Task {
    try await ongoingEntry.task.value
}
let result = try await wrapperTask.value
```

**关键点**：
- `wrapperTask` 是独立的 Task 实例
- 取消 `wrapperTask` 只停止"等待这个动作"
- `ongoingEntry.task`（底层执行任务）不受影响
- 其他等待者继续正常运行

### 需要的数据结构修改

```swift
private struct RequestTaskEntry {
    let token: UUID
    let task: Task<Sendable, Error>  // 底层执行任务（不变的）
    var waiters: [UUID: Task<Sendable, Error>] = [:]  // 新增：等待者列表
}
```

### 实现要点

#### 1. 发起请求时（executeWithDeduplication）

```swift
func executeWithDeduplication<T: Sendable>(...) async throws -> T {
    if let entry = ongoingRequests[runtime] {

        // 创建独立的等待任务
        let waiterId = UUID()
        let waiterTask = Task<T, Error> {
            try await entry.task.value as! T
        }
        entry.waiters[waiterId] = waiterTask

        // 记录 waiterId 到 request 中，用于后续取消
        request.waiterId = waiterId

        return try await waiterTask.value
    }
}
```

#### 2. 取消请求时（cancelRequest）

```swift
func cancelRequest(request: NtkMutableRequest) {
    guard let waiterId = request.waiterId,
          let entry = ongoingRequests[runtimeKey] else {
        return
    }

    // 只取消这个实例的等待任务
    entry.waiters[waiterId]?.cancel()
    entry.waiters.removeValue(forKey: waiterId)

    // 只有在所有等待者都取消时，才取消底层任务
    if entry.waiters.isEmpty {
        entry.task.cancel()
    }
}
```

#### 3. 底层任务完成后的清理

```swift
private func executeNewRequestWithTimeout<T: Sendable>(...) async throws -> T {
    // ... 创建 entry.task ...

    ongoingRequests[requestKey] = entry

    defer {
        // 底层任务完成后，清理所有等待者和 entry
        ongoingRequests.removeValue(forKey: requestKey)
    }

    let result = try await entry.task.value

    // 通知所有等待者（如果它们还没被取消）
    for waiter in entry.waiters.values {
        // waiter 已经在等待 entry.task，会自动得到结果
    }

    return result as! T
}
```

### 效果

| 场景 | 行为 |
|------|------|
| taskB.cancel() | 只取消 taskB 的等待，taskA 继续正常运行 ✓ |
| 所有实例都取消 | 底层任务也被取消，避免僵尸任务 ✓ |
| 底层任务完成 | 所有活跃的等待者都收到结果 ✓ |

## 待分析的问题

### 技术可行性

- [ ] wrapper Task 是否会被正确管理？
- [ ] 底层 Task 完成后，已取消的等待者是否会正确释放？
- [ ] 内存管理：waiters 字典是否会产生内存泄漏？

### 实现复杂度

- [ ] 如何将 `waiterId` 传递到 `NtkMutableRequest` 中？
- [ ] `cancelRequest` 时如何根据 request 找到对应的 runtimeKey 和 waiterId？
- [ ] 是否需要修改 `NtkMutableRequest` 的接口？

### 边界情况

- [ ] 底层任务正在执行，所有等待者都取消了 → 底层任务是否应该继续？
- [ ] 底层任务超时 → 等待者是否收到超时错误？
- [ ] 底层任务取消 → 等待者是否收到取消错误？

---

## 原始讨论记录

**日期**: 2026-03-18

**结论**：当前基于共享 Task 的设计无法实现"取消一个实例不影响其他实例"。需要引入 wrapper Task 机制，每个等待者使用独立的 Task 来等待底层执行任务。
