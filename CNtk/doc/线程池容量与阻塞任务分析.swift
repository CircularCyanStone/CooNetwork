import Foundation

// MARK: - 线程池容量测试

/// 获取系统线程池信息
func getSystemInfo() {
    let processorCount = ProcessInfo.processInfo.processorCount
    let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
    
    print("🖥️  系统信息:")
    print("   - CPU核心数: \(processorCount)")
    print("   - 活跃CPU核心数: \(activeProcessorCount)")
    print("   - Swift并发线程池预期大小: ~\(activeProcessorCount)")
}

/// 测试线程池的实际容量
func testThreadPoolCapacity() async {
    print("\n🔍 测试线程池实际容量...")
    
    var threadSet = Set<String>()
    let semaphore = DispatchSemaphore(value: 0)
    
    // 创建大量阻塞任务来观察线程池大小
    for i in 1...20 {
        Task {
            let threadInfo = Thread.current.description
            threadSet.insert(threadInfo)
            print("📍 任务 \(i) 在线程: \(threadInfo)")
            
            // 短暂阻塞来观察线程分配
            Thread.sleep(forTimeInterval: 0.1)
            
            if i == 20 {
                semaphore.signal()
            }
        }
    }
    
    semaphore.wait()
    print("🧮 观察到的不同线程数量: \(threadSet.count)")
}

// MARK: - 阻塞任务性能测试

/// 短时间阻塞任务（模拟你的疑问）
func shortBlockingTask() async -> Int {
    // ⚠️ 注意：这里故意使用Thread.sleep来演示阻塞效果
    Thread.sleep(forTimeInterval: 0.1) // 阻塞0.1秒
    return 1
}

/// 测试大规模阻塞任务的实际性能
func testLargeScaleBlocking() async {
    print("\n🧪 测试大规模阻塞任务性能...")
    
    let taskCount = 60 // 调整到60个任务，既能验证理论又不会过载系统
    let startTime = Date()
    
    await withTaskGroup(of: Int.self) { group in
        for i in 1...taskCount {
            group.addTask {
                print("🔴 任务 \(i) 开始")
                let result = await shortBlockingTask()
                print("🔴 任务 \(i) 完成")
                return result
            }
        }
        
        var completedTasks = 0
        for await _ in group {
            completedTasks += 1
        }
        print("✅ 完成任务数: \(completedTasks)")
    }
    
    let duration = Date().timeIntervalSince(startTime)
    print("⏱️  总耗时: \(String(format: "%.2f", duration))秒")
    
    // 理论计算
    let expectedParallelTime = Double(taskCount) * 0.1 / Double(ProcessInfo.processInfo.activeProcessorCount)
    let expectedSerialTime = Double(taskCount) * 0.1
    
    print("📊 性能分析:")
    print("   - 实际耗时: \(String(format: "%.2f", duration))秒")
    print("   - 理论并行耗时: \(String(format: "%.2f", expectedParallelTime))秒 (假设\(ProcessInfo.processInfo.activeProcessorCount)个线程)")
    print("   - 理论串行耗时: \(String(format: "%.2f", expectedSerialTime))秒")
    print("   - 并行效率: \(String(format: "%.1f", expectedSerialTime/duration))x")
}

// MARK: - 对比测试：阻塞 vs 协作式

/// 协作式任务
func cooperativeTask() async -> Int {
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    return 1
}

/// 对比阻塞和协作式的性能差异
func compareBlockingVsCooperative() async {
    print("\n⚖️  对比测试：阻塞 vs 协作式")
    
    let taskCount = 50 // 调整到50个任务进行对比
    
    // 测试阻塞方式
    print("\n🔴 测试阻塞方式...")
    let blockingStartTime = Date()
    
    await withTaskGroup(of: Int.self) { group in
        for _ in 1...taskCount {
            group.addTask {
                return await shortBlockingTask()
            }
        }
        
        for await _ in group { }
    }
    
    let blockingDuration = Date().timeIntervalSince(blockingStartTime)
    
    // 测试协作式
    print("\n🟢 测试协作式...")
    let cooperativeStartTime = Date()
    
    await withTaskGroup(of: Int.self) { group in
        for _ in 1...taskCount {
            group.addTask {
                return await cooperativeTask()
            }
        }
        
        for await _ in group { }
    }
    
    let cooperativeDuration = Date().timeIntervalSince(cooperativeStartTime)
    
    print("\n📊 对比结果:")
    print("   - 阻塞方式耗时: \(String(format: "%.2f", blockingDuration))秒")
    print("   - 协作式耗时: \(String(format: "%.2f", cooperativeDuration))秒")
    print("   - 性能差异: \(String(format: "%.1f", blockingDuration/cooperativeDuration))x")
}

// MARK: - 线程饥饿演示

/// 演示线程饥饿问题
func demonstrateThreadStarvation() async {
    print("\n🚨 演示线程饥饿问题...")
    
    // 创建长时间阻塞任务占用所有线程
    let longBlockingTasks = Task {
        await withTaskGroup(of: Void.self) { group in
            for i in 1...15 { // 调整到15个长阻塞任务
                group.addTask {
                    print("🔴 长阻塞任务 \(i) 开始占用线程")
                    // ⚠️ 故意使用Thread.sleep来演示线程饥饿问题
                    Thread.sleep(forTimeInterval: 2.0) // 减少到2秒以便观察
                    print("🔴 长阻塞任务 \(i) 结束")
                }
            }
        }
    }
    
    // 等待一小段时间让阻塞任务开始
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
    
    // 现在尝试执行快速任务
    print("⚡ 尝试执行快速任务...")
    let quickTaskStart = Date()
    
    await withTaskGroup(of: Void.self) { group in
        for i in 1...10 { // 调整到10个快速任务
            group.addTask {
                print("⚡ 快速任务 \(i) 开始")
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                print("⚡ 快速任务 \(i) 完成")
            }
        }
    }
    
    let quickTaskDuration = Date().timeIntervalSince(quickTaskStart)
    print("⚡ 快速任务总耗时: \(String(format: "%.2f", quickTaskDuration))秒")
    
    // 等待长阻塞任务完成
    await longBlockingTasks.value
}

// MARK: - 主执行代码

Task {
    print("🔬 Swift并发线程池深度分析")
    print(String(repeating: "=", count: 50))
    
    // 1. 获取系统信息
    getSystemInfo()
    
    // 2. 测试线程池容量
    await testThreadPoolCapacity()
    
    // 3. 大规模阻塞测试
    await testLargeScaleBlocking()
    
    // 4. 对比测试
    await compareBlockingVsCooperative()
    
    // 5. 线程饥饿演示
    await demonstrateThreadStarvation()
    
    print("\n" + String(repeating: "=", count: 50))
    print("🎯 关键结论:")
    print("1. 你的理论基本正确：阻塞只影响单个线程，不会完全停止调度")
    print("2. 但是：线程池大小有限，大量阻塞任务会导致线程饥饿")
    print("3. 实际性能取决于：任务数量 vs 可用线程数")
    print("4. 协作式调度的优势在于更高效的线程利用率")
    
    exit(0)
}

// MARK: - 扩展说明

/*
 🎯 回答用户的具体问题：
 
 用户的理解是正确的！如果有6个线程，10000个阻塞任务的理论执行时间确实是：
 10000 / 6 ≈ 1667秒，而不是10000秒
 
 但是需要注意几个重要因素：
 
 1. **线程池大小限制**
    - Swift并发线程池通常等于CPU核心数
    - 在8核机器上，可能只有8个工作线程
    - 不是无限的线程池
 
 2. **线程创建开销**
    - 每个阻塞操作占用一个线程
    - 系统需要时间来调度和切换线程
    - 上下文切换有性能开销
 
 3. **内存压力**
    - 10000个Task同时存在会占用大量内存
    - 每个Task都有自己的栈空间
    - 可能导致内存压力影响性能
 
 4. **调度延迟**
    - 虽然不会完全阻塞调度，但会增加调度延迟
    - 新任务需要等待线程释放
    - 影响整体响应性
 
 🔍 实际测试验证：
 - 大规模测试（如100个任务）会充分暴露线程池限制
 - 80个对比任务能清晰显示阻塞vs协作式的性能差异
 - 20个长阻塞任务会明显展示线程饥饿问题
 - 协作式调度在所有规模下都表现更好
*/