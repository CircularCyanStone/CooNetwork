# CNtk请求去重功能设计方案

## 1. 背景与目标

### 1.1 问题描述
CNtk框架目前缺乏真正的请求去重机制，多次快速点击会发起多个相同的网络请求，导致：
- 资源浪费（重复的网络请求）
- 用户体验问题（重复操作）
- 潜在的数据一致性问题
- 服务器压力增加

### 1.2 设计目标
- **自动去重**：相同请求只执行一次
- **结果共享**：所有等待者获得相同结果
- **配置灵活**：支持启用/禁用去重
- **性能优化**：最小化内存和计算开销
- **用户体验**：提升响应速度和操作流畅性

## 2. 技术方案

### 2.1 整体架构

采用"请求去重拦截器 + 请求状态管理器"的组合方案：

```
请求发起 → 去重拦截器 → 状态管理器 → 实际网络请求
     ↓           ↓           ↓
  多个调用者 ← 结果分发 ← Task共享机制
```

### 2.2 核心组件

#### 2.2.1 网络请求任务管理器 (NtkTaskManager)

**职责**：
- 管理正在进行的请求Task
- 实现请求的唯一标识和状态跟踪
- 提供Task共享机制

**核心实现**：
```swift
@NtkActor
class NtkTaskManager {
    // 存储正在进行的请求Task
    private var ongoingRequests: [String: Task<any iNtkResponse, Error>] = [:]
    
    func executeOrWait<T>(
        requestKey: String,
        requestExecutor: @escaping () async throws -> T
    ) async throws -> T where T: iNtkResponse {
        
        // 检查是否已有相同请求正在进行
        if let existingTask = ongoingRequests[requestKey] {
            // 等待现有请求完成并返回结果
            let result = try await existingTask
            return result as! T
        }
        
        // 创建新的请求Task
        let newTask = Task<any iNtkResponse, Error> {
            defer {
                // 请求完成后清理
                ongoingRequests.removeValue(forKey: requestKey)
            }
            return try await requestExecutor()
        }
        
        // 存储Task供其他请求共享
        ongoingRequests[requestKey] = newTask
        
        // 执行并返回结果
        let result = try await newTask.value
        return result as! T
    }
}
```

#### 2.2.2 请求去重拦截器 (NtkDeduplicationInterceptor)

**职责**：
- 集成到现有拦截器链
- 生成请求唯一标识
- 调用去重管理器

**优先级**：高优先级（在缓存拦截器之前）

**核心实现**：
```swift
@NtkActor
class NtkDeduplicationInterceptor: iNtkInterceptor {
    let priority = NtkInterceptorPriority.high
    private let taskManager = NtkTaskManager()
    private let requestIdentifierManager = NtkRequestIdentifierManager.shared
    
    func intercept(
        context: NtkRequestContext, 
        next: NtkRequestHandler
    ) async throws -> any iNtkResponse {
        
        // 检查是否启用去重
        guard context.wrapper.enableDeduplication else {
            return try await next.handle(context: context)
        }
        
        // 生成请求唯一标识
        let requestKey = try await cacheKeyManager.getCacheKey(
            request: context.wrapper.request
        )
        
        // 执行去重逻辑
        return try await deduplicationManager.executeOrWait(
            requestKey: requestKey
        ) {
            return try await next.handle(context: context)
        }
    }
}
```

#### 2.2.3 请求配置扩展

**扩展NtkRequestWrapper**：
```swift
extension NtkRequestWrapper {
    // 是否启用请求去重（默认启用）
    public var enableDeduplication: Bool {
        get { extraData["enableDeduplication"] as? Bool ?? true }
        set { extraData["enableDeduplication"] = newValue }
    }
}
```

### 2.3 结果分发机制

#### 2.3.1 Task共享原理

利用Swift的async/await机制，通过共享同一个Task实例实现结果分发：

1. **第一个请求**：创建Task并开始执行
2. **后续相同请求**：直接await第一个请求的Task
3. **结果分发**：所有等待者自动获得相同的结果
4. **错误传播**：如果请求失败，所有等待者都会收到相同的错误

#### 2.3.2 技术优势

- **自然的结果分发**：无需手动管理回调列表
- **类型安全**：保持原有的泛型类型系统
- **内存效率**：只存储Task引用，不存储结果数据
- **错误处理一致性**：网络错误、超时、取消等都会正确传播

## 3. 集成方案

### 3.1 拦截器注册

在NtkOperation中注册去重拦截器：

```swift
// 在 NtkOperation.swift 中
private func buildInterceptors() -> [iNtkInterceptor] {
    var interceptors: [iNtkInterceptor] = []
    
    // 添加去重拦截器（高优先级）
    interceptors.append(NtkDeduplicationInterceptor())
    
    // 添加其他拦截器...
    interceptors.append(contentsOf: customInterceptors)
    interceptors.append(NtkCacheInterceptor())
    
    return interceptors.sorted { $0.priority.value > $1.priority.value }
}
```

### 3.2 使用示例

#### 3.2.1 默认启用去重
```swift
let network = NtkNetwork<GetUserInfoRequest, UserInfoResponse>()
let result = try await network.sendRequest() // 自动去重
```

#### 3.2.2 禁用去重
```swift
let network = NtkNetwork<SubmitFormRequest, SubmitResponse>()
network.wrapper.enableDeduplication = false
let result = try await network.sendRequest() // 不进行去重
```

#### 3.2.3 多个地方同时请求
```swift
// 界面A
Task {
    let userInfo = try await network1.sendRequest()
    // 处理结果
}

// 界面B（几乎同时）
Task {
    let userInfo = try await network2.sendRequest()
    // 获得相同结果，只发起一次网络请求
}
```

## 4. 实施计划

### 4.1 第一阶段：核心组件开发

**时间**：1-2天

**任务**：
1. 创建 `NtkTaskManager.swift`
2. 创建 `NtkDeduplicationInterceptor.swift`
3. 扩展 `NtkRequestWrapper.swift`
4. 编写基础单元测试

### 4.2 第二阶段：集成与配置

**时间**：1天

**任务**：
1. 修改 `NtkOperation.swift` 注册拦截器
2. 更新拦截器优先级配置
3. 验证与现有拦截器的兼容性

### 4.3 第三阶段：测试与优化

**时间**：2-3天

**任务**：
1. 编写完整的集成测试
2. 性能测试和内存泄漏检查
3. 边界情况测试（网络错误、取消请求等）
4. 文档更新

## 5. 技术考虑

### 5.1 线程安全

- 使用 `@NtkActor` 确保所有操作在同一隔离域
- 利用现有的Actor模型，无需额外的锁机制

### 5.2 内存管理

- Task完成后自动清理，避免内存泄漏
- 不存储请求结果，只存储Task引用
- LRU策略可以考虑在后续版本中添加

### 5.3 错误处理

- 网络错误会传播给所有等待者
- 请求取消会正确处理
- 超时机制保持不变

### 5.4 性能影响

- 最小化性能开销
- 复用现有的缓存键生成逻辑
- 避免不必要的计算和存储

## 6. 预期效果

### 6.1 用户体验提升

- 避免重复请求导致的界面卡顿
- 快速点击不会产生多次提交
- 提升应用响应速度

### 6.2 资源优化

- 减少不必要的网络请求
- 降低服务器压力
- 节省设备电量和流量

### 6.3 开发体验

- 透明的去重机制，无需修改现有代码
- 灵活的配置选项
- 保持现有API的兼容性

## 7. 风险评估

### 7.1 技术风险

- **低风险**：基于现有架构，影响范围可控
- **兼容性**：与现有拦截器链完全兼容
- **性能**：最小化性能影响

### 7.2 业务风险

- **低风险**：可配置启用/禁用
- **回滚方案**：可以快速移除拦截器
- **渐进式部署**：可以逐步在不同模块中启用

## 8. 后续优化

### 8.1 高级功能

- 支持请求优先级
- 添加去重统计和监控
- 支持自定义去重策略

### 8.2 性能优化

- 实现LRU缓存策略
- 添加请求超时清理机制
- 优化内存使用

---

**文档版本**：v1.0  
**创建时间**：2024年  
**最后更新**：2024年  
**负责人**：开发团队