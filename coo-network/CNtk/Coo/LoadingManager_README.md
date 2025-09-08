# LoadingManager - 计数式Loading管理器

基于SVProgressHUD的计数式Loading管理器，支持Swift6严格并发模式，解决多个并发请求时Loading提前消失的问题。

## 🚀 特性

- ✅ **计数机制**：支持多个并发请求，只有所有请求完成后才隐藏Loading
- ✅ **Swift6兼容**：完全支持Swift6严格并发模式
- ✅ **线程安全**：使用@MainActor确保UI操作在主线程执行
- ✅ **向后兼容**：保持原有API不变，新增计数功能
- ✅ **灵活配置**：支持自定义文本、静默模式、调试模式等
- ✅ **错误处理**：提供强制重置和异常恢复机制

## 📁 文件结构

```
CNtk/Coo/
├── LoadingManager.swift                    # 核心Loading管理器
├── interceptor/
│   └── NtkLoadingCounterInterceptor.swift  # 计数式拦截器
├── Coo_UI.swift                           # UI扩展方法
├── LoadingManagerExample.swift            # 使用示例
└── LoadingManager_README.md               # 本文档
```

## 🔧 核心组件

### 1. LoadingManager

核心的Loading管理器，使用单例模式和计数机制：

```swift
// 显示Loading（计数+1）
await LoadingManager.shared.showLoadingAsync(with: "加载中...")

// 隐藏Loading（计数-1，只有计数为0时才真正隐藏）
await LoadingManager.shared.hideLoadingAsync()

// 强制隐藏（重置计数，立即隐藏）
await LoadingManager.shared.forceHideAsync()

// 显示成功/错误/信息消息
await LoadingManager.shared.showSuccess("操作成功！")
await LoadingManager.shared.showError("操作失败！")
await LoadingManager.shared.showInfo("提示信息")
```

### 2. NtkLoadingCounterInterceptor

基于计数机制的网络请求拦截器：

```swift
// 默认拦截器
let interceptor = NtkLoadingCounterInterceptor.default()

// 带自定义文本的拦截器
let interceptor = NtkLoadingCounterInterceptor.withText("正在加载...")

// 静默拦截器（只计数，不显示UI）
let interceptor = NtkLoadingCounterInterceptor.silent()

// 调试拦截器（Debug模式）
let interceptor = NtkLoadingCounterInterceptor.debug(identifier: "UserAPI")
```

### 3. Coo_UI 扩展

便捷的工厂方法：

```swift
// 推荐使用：计数式Loading拦截器
let interceptor = Coo.getCounterLoadingInterceptor(loadingText: "加载中...")

// 静默拦截器
let silentInterceptor = Coo.getSilentLoadingInterceptor()

// 调试拦截器（Debug模式）
let debugInterceptor = Coo.getDebugLoadingInterceptor(identifier: "API-1")

// 原有方法（保持向后兼容）
let oldInterceptor = Coo.getLoadingInterceptor(request)
```

## 📖 使用指南

### 基本使用

#### 1. 单个请求

```swift
func singleRequest() {
    Task {
        await LoadingManager.shared.showLoadingAsync(with: "加载中...")
        
        // 执行网络请求
        let result = try await performNetworkRequest()
        
        await LoadingManager.shared.hideLoadingAsync()
        await LoadingManager.shared.showSuccess("加载成功！")
    }
}
```

#### 2. 使用拦截器（推荐）

```swift
func requestWithInterceptor() {
    let request = createRequest()
    let interceptor = Coo.getCounterLoadingInterceptor(loadingText: "获取数据中...")
    
    // 将拦截器添加到请求中
    request.addInterceptor(interceptor)
    
    // 执行请求
    NetworkManager.execute(request)
}
```

### 并发请求（核心场景）

```swift
func multipleConcurrentRequests() {
    Task {
        // 同时发起多个请求
        async let userInfo = fetchUserInfo()      // 显示Loading，计数=1
        async let messageList = fetchMessages()   // 显示Loading，计数=2
        async let settings = fetchSettings()      // 显示Loading，计数=3
        
        // 等待所有请求完成
        let (user, messages, userSettings) = await (userInfo, messageList, settings)
        // 此时所有请求都完成，计数归零，Loading自动隐藏
        
        print("所有数据加载完成")
    }
}

private func fetchUserInfo() async -> UserInfo {
    await LoadingManager.shared.showLoadingAsync(with: "获取用户信息...")
    defer {
        Task { await LoadingManager.shared.hideLoadingAsync() }
    }
    
    // 模拟网络请求
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    return UserInfo()
}
```

### 错误处理

```swift
func requestWithErrorHandling() {
    Task {
        await LoadingManager.shared.showLoadingAsync()
        
        do {
            let result = try await riskyNetworkRequest()
            await LoadingManager.shared.showSuccess("操作成功！")
        } catch {
            await LoadingManager.shared.showError("操作失败：\(error.localizedDescription)")
        }
        // 注意：showSuccess和showError会自动重置计数
    }
}
```

## 🔄 迁移指南

### 从原有Loading方案迁移

#### 1. 替换直接的SVProgressHUD调用

**之前：**
```swift
// 旧方式
SVProgressHUD.show()
// ... 网络请求
SVProgressHUD.dismiss()
```

**现在：**
```swift
// 新方式
await LoadingManager.shared.showLoadingAsync()
// ... 网络请求
await LoadingManager.shared.hideLoadingAsync()
```

#### 2. 替换原有拦截器

**之前：**
```swift
let interceptor = Coo.getLoadingInterceptor(request)
```

**现在：**
```swift
let interceptor = Coo.getCounterLoadingInterceptor(loadingText: "加载中...")
```

#### 3. 处理并发场景

**之前的问题：**
```swift
// 问题：第一个请求完成时，Loading就消失了
async let request1 = performRequest1() // SVProgressHUD.show()
async let request2 = performRequest2() // SVProgressHUD.show()
// request1完成 -> SVProgressHUD.dismiss() -> Loading消失
// request2还在进行，但用户看不到Loading了
```

**现在的解决方案：**
```swift
// 解决：使用计数机制，所有请求完成后才隐藏
async let request1 = performRequest1() // 计数=1
async let request2 = performRequest2() // 计数=2
// request1完成 -> 计数=1，Loading继续显示
// request2完成 -> 计数=0，Loading隐藏
```

## ⚠️ 注意事项

### 1. Swift6并发要求

- 所有Loading操作必须在MainActor上执行
- 使用`await`关键字调用异步方法
- 确保回调函数标记为`@Sendable`

### 2. 计数平衡

```swift
// ✅ 正确：每个show都有对应的hide
await LoadingManager.shared.showLoadingAsync()
// ... 操作
await LoadingManager.shared.hideLoadingAsync()

// ❌ 错误：计数不平衡
await LoadingManager.shared.showLoadingAsync()
await LoadingManager.shared.showLoadingAsync()
// 只调用一次hide，计数还剩1
await LoadingManager.shared.hideLoadingAsync()
```

### 3. 异常处理

```swift
// ✅ 推荐：使用defer确保Loading被隐藏
func safeRequest() async {
    await LoadingManager.shared.showLoadingAsync()
    defer {
        Task { await LoadingManager.shared.hideLoadingAsync() }
    }
    
    // 可能抛出异常的操作
    try await riskyOperation()
}

// 🆘 紧急情况：强制重置
if LoadingManager.shared.currentCount > 0 {
    await LoadingManager.shared.forceHideAsync()
}
```

### 4. 调试支持

```swift
#if DEBUG
// 打印当前状态
await LoadingManager.shared.printDebugInfo()

// 使用调试拦截器
let debugInterceptor = Coo.getDebugLoadingInterceptor(identifier: "UserAPI")

// 重置状态（仅测试用）
await LoadingManager.shared.resetForTesting()
#endif
```

## 🎯 最佳实践

### 1. 优先使用拦截器

对于网络请求，优先使用拦截器而不是手动管理：

```swift
// ✅ 推荐
let interceptor = Coo.getCounterLoadingInterceptor()
request.addInterceptor(interceptor)

// ❌ 不推荐（除非有特殊需求）
await LoadingManager.shared.showLoadingAsync()
// ... 手动管理
await LoadingManager.shared.hideLoadingAsync()
```

### 2. 合理选择拦截器类型

```swift
// 用户可见的重要操作
let userInterceptor = Coo.getCounterLoadingInterceptor(loadingText: "保存中...")

// 后台数据同步
let backgroundInterceptor = Coo.getSilentLoadingInterceptor()

// 开发调试
let debugInterceptor = Coo.getDebugLoadingInterceptor(identifier: "API-Debug")
```

### 3. 错误恢复策略

```swift
// 在应用启动或关键节点检查Loading状态
func checkLoadingState() {
    #if DEBUG
    if LoadingManager.shared.currentCount > 0 {
        print("警告：检测到Loading计数异常，当前计数：\(LoadingManager.shared.currentCount)")
        // 可以选择重置或记录日志
    }
    #endif
}
```

## 🔍 故障排除

### 常见问题

1. **Loading不消失**
   - 检查show/hide调用是否平衡
   - 使用`printDebugInfo()`查看当前计数
   - 必要时使用`forceHide()`重置

2. **Loading闪烁**
   - 避免快速的show/hide操作
   - 考虑使用静默拦截器

3. **并发问题**
   - 确保所有Loading操作都在MainActor上
   - 使用await关键字

4. **内存泄漏**
   - 检查是否有未完成的异步操作
   - 使用weak引用避免循环引用

### 调试命令

```swift
#if DEBUG
// 查看当前状态
await LoadingManager.shared.printDebugInfo()

// 重置状态
await LoadingManager.shared.resetForTesting()

// 检查计数
let count = LoadingManager.shared.currentCount
let isShowing = LoadingManager.shared.isCurrentlyShowing
#endif
```

## 📝 更新日志

### v1.0.0
- ✅ 初始版本
- ✅ 支持计数机制
- ✅ Swift6严格并发模式支持
- ✅ 完整的拦截器实现
- ✅ 向后兼容性保证

## 📄 许可证

本项目遵循项目原有许可证。

---

**注意**：这是一个内部组件，请确保在使用前充分测试，特别是在复杂的并发场景下。如有问题，请及时反馈。