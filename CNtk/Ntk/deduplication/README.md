# CNtk 请求去重功能

## 概述

CNtk 请求去重功能是一个高性能、线程安全的网络请求去重解决方案，旨在避免重复的网络请求，提升应用性能和用户体验。

## 核心特性

- ✅ **自动去重**: 自动识别并合并相同的网络请求
- ✅ **结果共享**: 多个相同请求共享同一个网络响应
- ✅ **线程安全**: 基于 Swift Actor 模型，确保并发安全
- ✅ **配置灵活**: 支持全局和单个请求级别的配置
- ✅ **向后兼容**: 不影响现有代码，可选择性启用
- ✅ **性能优化**: 轻量级实现，最小化性能开销

## 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                    CNtk 请求去重架构                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐    │
│  │ NtkDeduplication│    │   NtkRequestDeduplication    │    │
│  │   Interceptor   │───▶│        Manager               │    │
│  │                 │    │                              │    │
│  └─────────────────┘    └──────────────────────────────┘    │
│           │                           │                     │
│           │                           ▼                     │
│           │              ┌──────────────────────────────┐    │
│           │              │  NtkRequestIdentifier        │    │
│           │              │       Manager                │    │
│           │              └──────────────────────────────┘    │
│           │                           │                     │
│           ▼                           │                     │
│  ┌─────────────────┐                  │                     │
│  │ NtkDeduplication│◀─────────────────┘                     │
│  │     Config      │                                        │
│  └─────────────────┘                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 组件说明

1. **NtkDeduplicationInterceptor**: 请求拦截器，负责检查和启动去重逻辑
2. **NtkTaskManager**: 网络请求任务管理器，统一管理请求Task的生命周期，包括去重、超时控制和取消操作
3. **NtkRequestIdentifierManager**: 请求标识符管理器，生成请求的唯一标识
4. **NtkDeduplicationConfig**: 配置管理器，提供全局配置选项

## 快速开始

### 基本使用

```swift
// 1. 创建请求
let request = YourApiRequest()
let wrapper = NtkRequestWrapper(request: request)

// 2. 启用去重功能
wrapper.enableDeduplication()

// 3. 发送请求
let response = try await client.send(wrapper)
```

### 并发请求示例

```swift
// 多个地方同时请求用户信息，只会发送一次网络请求
async let userInfo1 = fetchUserInfo(enableDeduplication: true)
async let userInfo2 = fetchUserInfo(enableDeduplication: true)
async let userInfo3 = fetchUserInfo(enableDeduplication: true)

let results = try await [userInfo1, userInfo2, userInfo3]
// 三个结果相同，但只发送了一次网络请求
```

## 配置选项

### 全局配置

```swift
let config = NtkDeduplicationConfig.shared

// 启用/禁用去重功能
config.isGloballyEnabled = true

// 设置请求超时时间
config.requestTimeoutInterval = 60.0

// 设置最大并发请求数
config.maxConcurrentRequests = 100

// 启用调试日志
config.isDebugLoggingEnabled = true
```

### 动态Header管理

```swift
// 添加需要忽略的动态Header（这些Header不参与去重判断）
config.addDynamicHeader("x-timestamp")
config.addDynamicHeader("x-nonce")

// 移除动态Header
config.removeDynamicHeader("authorization")

// 检查Header是否为动态Header
if config.isDynamicHeader("timestamp") {
    print("timestamp会在去重时被忽略")
}
```

### 请求级别配置

```swift
let wrapper = NtkRequestWrapper(request: request)

// 方式1: 直接启用/禁用
wrapper.enableDeduplication()
wrapper.disableDeduplication()

// 方式2: 使用策略
wrapper.setDeduplicationPolicy(.enabled)
wrapper.setDeduplicationPolicy(.disabled)

// 检查状态
if wrapper.isDeduplicationEnabled {
    print("已启用去重")
}
```

## 工作原理

### 请求标识符生成

1. **序列化请求**: 将请求的 URL、方法、参数、Header 序列化为字符串
2. **排除动态Header**: 忽略时间戳、随机数等动态Header
3. **生成哈希**: 使用 MD5 算法生成唯一标识符
4. **缓存优化**: 使用 LRU 缓存避免重复计算

### 去重逻辑

```swift
// 伪代码示例
func executeWithDeduplication<T>(request: NtkRequestWrapper, handler: () async throws -> T) async throws -> T {
    let identifier = await getRequestIdentifier(request)
    
    // 检查是否有相同请求正在进行
    if let ongoingTask = ongoingRequests[identifier] {
        // 等待现有请求完成
        return try await ongoingTask.value
    }
    
    // 创建新的Task
    let task = Task<T, Error> {
        try await handler()
    }
    
    ongoingRequests[identifier] = task
    
    defer {
        ongoingRequests.removeValue(forKey: identifier)
    }
    
    return try await task.value
}
```

## 适用场景

### ✅ 适合去重的场景

- 用户信息、配置信息等相对静态的数据请求
- 列表数据的首页请求
- 搜索建议、自动完成等频繁触发的请求
- 重复点击按钮导致的重复请求
- 应用启动时的多个初始化请求

### ❌ 不适合去重的场景

- 提交表单、创建数据等写操作
- 包含时间戳等动态参数的请求
- 需要实时数据的请求
- 文件上传、下载等大数据传输
- 支付、订单等关键业务操作

## 性能考虑

### 内存使用

- 每个正在进行的请求会在内存中保存一个 Task 引用
- 请求完成后会自动清理，不会造成内存泄漏
- LRU 缓存限制了标识符缓存的内存占用

### CPU 开销

- 请求标识符生成使用 MD5 算法，计算开销很小
- LRU 缓存减少了重复计算
- Actor 模型确保线程安全，无锁设计

### 网络优化

- 避免重复的网络请求，减少带宽使用
- 降低服务器压力
- 提升用户体验，减少等待时间

## 调试和监控

### 启用调试日志

```swift
NtkDeduplicationConfig.shared.isDebugLoggingEnabled = true
```

### 日志输出示例

```
[NtkDeduplication] 开始执行请求去重逻辑
[NtkDeduplication] 发现重复请求，等待现有请求完成: /api/user/info
[NtkDeduplication] 请求完成，移除Task: /api/user/info
```

### 监控指标

```swift
let manager = NtkTaskManager()

// 获取当前正在进行的请求数量
let count = manager.getOngoingRequestCount()

// 检查特定请求是否正在进行
let isOngoing = await manager.isRequestOngoing(request: wrapper)
```

## 最佳实践

### 1. 合理配置动态Header

```swift
// 添加应用特定的动态Header
config.addDynamicHeader("x-session-id")
config.addDynamicHeader("x-device-id")
config.addDynamicHeader("x-app-version")
```

### 2. 根据场景选择性启用

```swift
// 对于用户信息等静态数据启用去重
func fetchUserInfo() async throws -> UserInfo {
    let wrapper = NtkRequestWrapper(request: GetUserInfoRequest())
    wrapper.enableDeduplication()
    return try await client.send(wrapper)
}

// 对于提交操作禁用去重
func submitForm(data: FormData) async throws -> SubmitResult {
    let wrapper = NtkRequestWrapper(request: SubmitFormRequest(data: data))
    wrapper.disableDeduplication() // 明确禁用
    return try await client.send(wrapper)
}
```

### 3. 监控和调优

```swift
// 在开发阶段启用详细日志
#if DEBUG
NtkDeduplicationConfig.shared.isDebugLoggingEnabled = true
#endif

// 根据应用特点调整配置
config.requestTimeoutInterval = 30.0 // 根据网络环境调整
config.maxConcurrentRequests = 50    // 根据设备性能调整
```

## 故障排除

### 常见问题

1. **请求没有被去重**
   - 检查是否启用了去重功能
   - 确认全局配置是否启用
   - 检查请求参数是否完全相同

2. **内存使用过高**
   - 检查是否有长时间运行的请求
   - 调整最大并发请求数限制
   - 确认请求正常完成和清理

3. **性能问题**
   - 检查是否过度使用去重功能
   - 优化动态Header配置
   - 监控请求标识符生成性能

### 调试步骤

1. 启用调试日志
2. 检查配置是否正确
3. 验证请求标识符生成
4. 监控内存和性能指标
5. 查看网络请求日志

## 版本历史

- **v1.0.0**: 初始版本，支持基本的请求去重功能
- 支持自定义配置和动态Header管理
- 提供完整的单元测试和使用示例

## 许可证

本功能遵循项目的整体许可证协议。