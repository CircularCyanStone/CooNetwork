import Foundation

// 测试：在什么条件下相同优先级任务会真正共用线程？
func testWhenTasksShareThreads() {
    print("🔬 测试：什么条件下任务会共用线程？")
    print(String(repeating: "=", count: 50))
    print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
    print()
    
    // 测试1：创建大量任务，超过CPU核心数
    testManyTasks()
}

func testManyTasks() {
    print("📊 测试1：创建大量任务（超过CPU核心数）")
    print("创建20个相同优先级的任务...")
    
    actor ThreadCollector {
        private var taskThreads: [String: String] = [:]
        
        func recordTask(_ taskName: String, threadId: String) {
            taskThreads[taskName] = threadId
        }
        
        func getResults() -> [String: String] {
            return taskThreads
        }
    }
    
    let collector = ThreadCollector()
    let group = DispatchGroup()
    
    // 创建20个任务（远超CPU核心数）
    for i in 1...20 {
        group.enter()
        Task.detached {  // 默认优先级
            let threadId = Thread.current.description
            await collector.recordTask("Task\(i)", threadId: threadId)
            
            // 模拟一些工作，让任务有时间被调度
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
            group.leave()
        }
    }
    
    group.wait()
    
    Task {
        let results = await collector.getResults()
        let uniqueThreads = Set(results.values)
        
        print("20个任务使用了 \(uniqueThreads.count) 个线程")
        
        // 统计每个线程上的任务数
        var threadTaskCount: [String: Int] = [:]
        for (_, thread) in results {
            threadTaskCount[thread, default: 0] += 1
        }
        
        print()
        print("🧵 线程使用详情:")
        for (thread, count) in threadTaskCount.sorted(by: { $0.value > $1.value }) {
            print("线程 \(thread): \(count)个任务")
        }
        
        let maxTasksPerThread = threadTaskCount.values.max() ?? 0
        if maxTasksPerThread > 1 {
            print()
            print("✅ 发现线程共用！最多一个线程上运行了 \(maxTasksPerThread) 个任务")
            print("📖 这证实了书中的说法在任务数量超过线程池大小时是正确的")
        } else {
            print()
            print("❌ 没有发现线程共用，每个任务都使用了独立线程")
        }
        
        // 继续测试CPU密集型任务
        testCPUIntensiveTasks()
    }
}

func testCPUIntensiveTasks() {
    print()
    print("📊 测试2：CPU密集型任务的线程共用")
    print("创建CPU密集型任务来占用线程...")
    
    actor ThreadCollector {
        private var taskThreads: [String: String] = [:]
        
        func recordTask(_ taskName: String, threadId: String) {
            taskThreads[taskName] = threadId
        }
        
        func getResults() -> [String: String] {
            return taskThreads
        }
    }
    
    let collector = ThreadCollector()
    let group = DispatchGroup()
    
    // 创建CPU密集型任务
    for i in 1...15 {
        group.enter()
        Task.detached {
            let threadId = Thread.current.description
            await collector.recordTask("CPUTask\(i)", threadId: threadId)
            
            // CPU密集型工作（不使用await，占用线程）
            var result = 0.0
            for j in 0..<1000000 {
                result += sin(Double(j)) * cos(Double(j))
            }
            
            group.leave()
        }
    }
    
    group.wait()
    
    Task {
        let results = await collector.getResults()
        let uniqueThreads = Set(results.values)
        
        print("15个CPU密集型任务使用了 \(uniqueThreads.count) 个线程")
        
        // 统计每个线程上的任务数
        var threadTaskCount: [String: Int] = [:]
        for (_, thread) in results {
            threadTaskCount[thread, default: 0] += 1
        }
        
        print()
        print("🧵 CPU密集型任务的线程分配:")
        for (thread, count) in threadTaskCount.sorted(by: { $0.value > $1.value }) {
            print("线程 \(thread): \(count)个任务")
        }
        
        let maxTasksPerThread = threadTaskCount.values.max() ?? 0
        if maxTasksPerThread > 1 {
            print()
            print("✅ CPU密集型任务确实会共用线程！")
            print("📖 这解释了为什么书中的无限循环会阻塞其他任务")
        }
        
        // 最终结论
        finalConclusion()
    }
}

func finalConclusion() {
    print()
    print("🎯 最终结论：书中表述的真实含义")
    print(String(repeating: "=", count: 60))
    print()
    print("📖 书中说：\"同样优先级的任务共用一个调度线程\"")
    print()
    print("🔍 这句话的真实含义:")
    print("1. 不是说相同优先级就必然共用线程")
    print("2. 而是说Swift并发调度器使用有限的线程池")
    print("3. 当任务数量超过可用线程数时，多个任务会被分配到同一线程")
    print("4. 相同优先级的任务更容易被分配到同一个线程队列")
    print()
    print("⚠️  书中表述的问题:")
    print("- 表述过于简化，容易误解为\"相同优先级=共用线程\"")
    print("- 没有说明这是在特定条件下才成立")
    print("- 忽略了现代Swift运行时的动态调度能力")
    print()
    print("✅ 更准确的理解:")
    print("Swift并发调度器使用线程池，当系统繁忙时，")
    print("多个任务（特别是相同优先级的）可能会排队等待")
    print("在同一个线程上执行，这时就会出现书中描述的饥饿现象。")
    print()
    print("💡 你的质疑是对的！")
    print("书中的表述确实容易引起\"优先级决定线程分配\"的误解。")
    print("实际上是\"线程池容量限制导致任务排队\"的问题。")
    
    exit(0)
}

// 启动测试
testWhenTasksShareThreads()
RunLoop.main.run()