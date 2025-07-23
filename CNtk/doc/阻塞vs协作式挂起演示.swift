import Foundation

// MARK: - 演示：Thread.sleep vs Task.sleep 的性能差异

/// ❌ 错误示例：使用Thread.sleep阻塞线程
func blockingMethod() async -> Bool {
    print("🔴 阻塞方法开始 - 线程: \(Thread.current)")
    // ⚠️ 注意：Swift编译器会警告这个用法！
    // 警告信息："Thread.sleep is unavailable from asynchronous contexts"
    // 这正好证明了我们要说明的问题！
    Thread.sleep(forTimeInterval: 1.0)  // 阻塞当前线程1秒
    print("🔴 阻塞方法结束 - 线程: \(Thread.current)")
    return true
}

/// ✅ 正确示例：使用Task.sleep协作式挂起
func cooperativeMethod() async -> Bool {
    print("🟢 协作方法开始 - 线程: \(Thread.current)")
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // 挂起1秒，释放线程
    print("🟢 协作方法结束 - 线程: \(Thread.current)")
    return true
}

// MARK: - 性能对比测试

/// 测试阻塞方法的性能影响
func testBlockingPerformance() async {
    print("\n=== 🔴 测试阻塞方法性能 ===")
    let startTime = Date()
    
    await withTaskGroup(of: Void.self) { group in
        for i in 1...5 {
            group.addTask {
                print("任务 \(i) 开始")
                _ = await blockingMethod()
                print("任务 \(i) 完成")
            }
        }
    }
    
    let duration = Date().timeIntervalSince(startTime)
    print("🔴 阻塞方法总耗时: \(String(format: "%.2f", duration))秒")
}

/// 测试协作方法的性能
func testCooperativePerformance() async {
    print("\n=== 🟢 测试协作方法性能 ===")
    let startTime = Date()
    
    await withTaskGroup(of: Void.self) { group in
        for i in 1...5 {
            group.addTask {
                print("任务 \(i) 开始")
                _ = await cooperativeMethod()
                print("任务 \(i) 完成")
            }
        }
    }
    
    let duration = Date().timeIntervalSince(startTime)
    print("🟢 协作方法总耗时: \(String(format: "%.2f", duration))秒")
}

// MARK: - 线程池状态观察

/// 观察线程池的使用情况
func observeThreadPoolUsage() async {
    print("\n=== 🔍 观察线程池使用情况 ===")
    
    // 创建多个并发任务来观察线程分配
    await withTaskGroup(of: Void.self) { group in
        for i in 1...8 {
            group.addTask {
                print("📍 任务 \(i) 在线程: \(Thread.current.description)")
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                print("📍 任务 \(i) 恢复在线程: \(Thread.current.description)")
            }
        }
    }
}

// MARK: - 实际场景模拟

/// 模拟网络请求的错误做法
func badNetworkRequest() async -> String {
    print("🔴 错误的网络请求开始")
    
    // ❌ 模拟同步网络请求（阻塞线程）
    // ⚠️ Swift编译器警告：不要在async上下文中使用Thread.sleep！
    Thread.sleep(forTimeInterval: 2.0)
    
    return "网络数据"
}

/// 模拟网络请求的正确做法
func goodNetworkRequest() async -> String {
    print("🟢 正确的网络请求开始")
    
    // ✅ 使用真正的异步网络请求
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 模拟异步等待
    
    return "网络数据"
}

// MARK: - 主执行代码

// 使用顶层异步代码执行演示
Task {
    print("🚀 Swift并发机制演示：阻塞 vs 协作式挂起")
    
    // 1. 观察线程池使用
    await observeThreadPoolUsage()
    
    // 2. 对比阻塞方法性能
    await testBlockingPerformance()
    
    // 3. 对比协作方法性能  
    await testCooperativePerformance()
    
    print("\n=== 📊 性能分析总结 ===")
    print("🔴 阻塞方法：线程被占用，无法处理其他任务，总时间约等于单个任务时间")
    print("🟢 协作方法：线程可以复用，多个任务可以并发执行，总时间接近单个任务时间")
    print("\n💡 关键理解：")
    print("- Thread.sleep 阻塞物理线程，浪费系统资源")
    print("- Task.sleep 挂起逻辑任务，释放线程给其他任务使用")
    print("- Swift并发的核心是协作式调度，而非抢占式调度")
    
    exit(0)
}

// MARK: - 扩展说明

/*
 🎯 核心概念解释：
 
 1. **线程池有限性**
    - Swift的全局并发池通常有 CPU核心数 个线程
    - 在8核机器上，可能只有8个工作线程
    - 如果5个线程都被Thread.sleep阻塞，只剩3个线程可用
 
 2. **调度机制差异**
    - Thread.sleep: 线程进入系统级睡眠，完全不可用
    - Task.sleep: 任务挂起，线程返回线程池继续服务其他任务
 
 3. **性能影响**
    - 阻塞方法：5个1秒任务 ≈ 5秒（串行执行）
    - 协作方法：5个1秒任务 ≈ 1秒（并行执行）
 
 4. **实际应用场景**
    - ❌ 同步文件I/O、同步网络请求、Thread.sleep
    - ✅ async/await网络请求、Task.sleep、FileHandle异步读取
 
 🔧 最佳实践：
 - 永远不要在async函数中使用Thread.sleep
 - 避免在async函数中调用阻塞的同步API
 - 使用Task.sleep代替Thread.sleep
 - 使用异步版本的I/O操作
 - 如果必须调用同步API，考虑使用Task.detached在后台队列执行
*/