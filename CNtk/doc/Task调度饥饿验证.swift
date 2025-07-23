import Foundation

// 全局变量用于控制循环
var shouldContinueLoop = true

// 模拟书中的例子
func shouldLoopAgain() -> Bool {
    // 模拟一些工作，然后决定是否继续
    Thread.sleep(forTimeInterval: 0.001) // 1毫秒的工作
    return shouldContinueLoop
}

// 测试1: 重现书中的问题 - 无限循环导致饥饿
func testStarvationProblem() async {
    print("🔬 测试1: 重现书中的饥饿问题")
    print(String(repeating: "=", count: 50))
    
    let startTime = Date()
    
    // 任务1: 占用线程的循环任务
    Task.detached {
        print("Task 1 开始")
        var loop = true
        var count = 0
        while loop {
            // 实际工作
            count += 1
            if count % 1000 == 0 {
                print("Task 1 循环次数: \(count)")
            }
            loop = shouldLoopAgain()
        }
        print("Task 1 完成")
    }
    
    // 任务2: 被饥饿的任务
    Task.detached {
        print("Task 2 开始")
        print("Task 2 完成")
    }
    
    // 任务3: 另一个被饥饿的任务
    Task.detached {
        print("Task 3 开始")
        print("Task 3 完成")
    }
    
    // 让循环运行3秒后停止
    try? await Task.sleep(nanoseconds: 3_000_000_000)
    shouldContinueLoop = false
    
    // 再等待1秒让所有任务完成
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    
    let duration = Date().timeIntervalSince(startTime)
    print("总耗时: \(String(format: "%.2f", duration))秒")
    print()
}

// 测试2: 使用yield()解决饥饿问题
func testWithYield() async {
    print("🔬 测试2: 使用Task.yield()解决饥饿问题")
    print(String(repeating: "=", count: 50))
    
    shouldContinueLoop = true // 重置标志
    let startTime = Date()
    
    // 任务1: 改进的循环任务，使用yield()
    Task.detached {
        print("Task 1 (with yield) 开始")
        var loop = true
        var count = 0
        while loop {
            // 实际工作
            count += 1
            if count % 1000 == 0 {
                print("Task 1 循环次数: \(count)")
                // 主动让出执行权
                await Task.yield()
            }
            loop = shouldLoopAgain()
        }
        print("Task 1 (with yield) 完成")
    }
    
    // 任务2: 现在可以正常执行的任务
    Task.detached {
        print("Task 2 (with yield) 开始")
        print("Task 2 (with yield) 完成")
    }
    
    // 任务3: 另一个可以正常执行的任务
    Task.detached {
        print("Task 3 (with yield) 开始")
        print("Task 3 (with yield) 完成")
    }
    
    // 让循环运行3秒后停止
    try? await Task.sleep(nanoseconds: 3_000_000_000)
    shouldContinueLoop = false
    
    // 再等待1秒让所有任务完成
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    
    let duration = Date().timeIntervalSince(startTime)
    print("总耗时: \(String(format: "%.2f", duration))秒")
    print()
}

// 测试3: 验证线程使用情况
func testThreadUsage() async {
    print("🔬 测试3: 验证线程使用情况")
    print(String(repeating: "=", count: 50))
    
    // 使用actor来安全地收集线程信息
    actor ThreadCollector {
        private var threadIds: Set<String> = []
        
        func addThread(_ threadId: String) {
            threadIds.insert(threadId)
        }
        
        func getCount() -> Int {
            return threadIds.count
        }
    }
    
    let collector = ThreadCollector()
    
    // 创建多个任务来观察线程分配
    await withTaskGroup(of: Void.self) { group in
        for i in 1...10 {
            group.addTask {
                let threadId = Thread.current.description
                await collector.addThread(threadId)
                print("Task \(i) 运行在线程: \(threadId)")
                
                // 模拟一些工作
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
        }
    }
    
    let threadCount = await collector.getCount()
    print("总共使用了 \(threadCount) 个线程")
    print()
}

// 测试4: 不同优先级任务的调度
func testPriorityScheduling() async {
    print("🔬 测试4: 不同优先级任务的调度")
    print(String(repeating: "=", count: 50))
    
    // 高优先级任务
    Task.detached(priority: .high) {
        print("🔴 高优先级任务开始")
        for i in 1...5 {
            print("🔴 高优先级任务 - 步骤 \(i)")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        }
        print("🔴 高优先级任务完成")
    }
    
    // 低优先级任务
    Task.detached(priority: .low) {
        print("🔵 低优先级任务开始")
        for i in 1...5 {
            print("🔵 低优先级任务 - 步骤 \(i)")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        }
        print("🔵 低优先级任务完成")
    }
    
    // 普通优先级任务
    Task.detached {
        print("🟡 普通优先级任务开始")
        for i in 1...5 {
            print("🟡 普通优先级任务 - 步骤 \(i)")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        }
        print("🟡 普通优先级任务完成")
    }
    
    // 等待所有任务完成
    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
    print()
}

// 主测试函数
func runAllTests() async {
    print("📚 Swift Task调度和饥饿现象验证")
    print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
    print("活跃处理器数: \(ProcessInfo.processInfo.activeProcessorCount)")
    print()
    
    // 运行所有测试
    await testStarvationProblem()
    await testWithYield()
    await testThreadUsage()
    await testPriorityScheduling()
    
    print("🎯 关键结论:")
    print("1. Task.detached 创建的任务可能会在同一个线程上串行执行")
    print("2. 无限循环会阻塞整个调度线程，导致其他任务饥饿")
    print("3. 使用 Task.yield() 可以主动让出执行权，避免饥饿")
    print("4. 不同优先级的任务会影响调度顺序")
    print("5. Swift的并发调度器会复用线程，而不是为每个任务创建新线程")
}

// 启动测试
Task {
    await runAllTests()
    exit(0)
}

RunLoop.main.run()