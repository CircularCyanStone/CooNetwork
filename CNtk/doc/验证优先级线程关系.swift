import Foundation

// 测试：相同优先级的任务是否真的共用一个调度线程？
func testSamePriorityThreadSharing() {
    print("🔬 测试：相同优先级任务的线程分配")
    print(String(repeating: "=", count: 50))
    print()
    
    // 使用actor来安全收集线程信息
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
    
    // 创建多个相同优先级的任务
    print("📊 创建5个默认优先级的Task.detached任务...")
    
    let group = DispatchGroup()
    
    for i in 1...5 {
        group.enter()
        Task.detached {  // 默认优先级
            let threadId = Thread.current.description
            await collector.recordTask("Task\(i)", threadId: threadId)
            print("Task \(i) 运行在线程: \(threadId)")
            
            // 模拟一些工作
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            group.leave()
        }
    }
    
    // 等待所有任务完成
    group.wait()
    
    // 分析结果
    Task {
        let results = await collector.getResults()
        print()
        print("📊 线程分配分析:")
        
        let uniqueThreads = Set(results.values)
        print("总共使用了 \(uniqueThreads.count) 个不同的线程")
        
        // 按线程分组显示任务
        var threadGroups: [String: [String]] = [:]
        for (task, thread) in results {
            if threadGroups[thread] == nil {
                threadGroups[thread] = []
            }
            threadGroups[thread]!.append(task)
        }
        
        print()
        print("🧵 线程分组详情:")
        for (thread, tasks) in threadGroups.sorted(by: { $0.key < $1.key }) {
            print("线程 \(thread): \(tasks.joined(separator: ", "))")
        }
        
        print()
        print("🎯 结论:")
        if uniqueThreads.count == 1 {
            print("✅ 书中说法正确：所有相同优先级任务确实共用了一个线程")
        } else if uniqueThreads.count == results.count {
            print("❌ 书中说法不准确：每个任务都使用了不同的线程")
        } else {
            print("⚠️  部分正确：\(results.count)个任务使用了\(uniqueThreads.count)个线程，存在线程复用但不是完全共用一个")
        }
        
        // 继续测试不同优先级
        testDifferentPriorities()
    }
}

// 测试不同优先级任务的线程分配
func testDifferentPriorities() {
    print()
    print("🔬 测试：不同优先级任务的线程分配")
    print(String(repeating: "=", count: 50))
    
    actor ThreadCollector {
        private var taskThreads: [(String, String, String)] = [] // (任务名, 优先级, 线程ID)
        
        func recordTask(_ taskName: String, priority: String, threadId: String) {
            taskThreads.append((taskName, priority, threadId))
        }
        
        func getResults() -> [(String, String, String)] {
            return taskThreads
        }
    }
    
    let collector = ThreadCollector()
    let group = DispatchGroup()
    
    // 高优先级任务
    group.enter()
    Task.detached(priority: .high) {
        let threadId = Thread.current.description
        await collector.recordTask("HighTask", priority: "High", threadId: threadId)
        print("🔴 高优先级任务运行在: \(threadId)")
        try? await Task.sleep(nanoseconds: 100_000_000)
        group.leave()
    }
    
    // 普通优先级任务
    group.enter()
    Task.detached(priority: .medium) {
        let threadId = Thread.current.description
        await collector.recordTask("MediumTask", priority: "Medium", threadId: threadId)
        print("🟡 中等优先级任务运行在: \(threadId)")
        try? await Task.sleep(nanoseconds: 100_000_000)
        group.leave()
    }
    
    // 低优先级任务
    group.enter()
    Task.detached(priority: .low) {
        let threadId = Thread.current.description
        await collector.recordTask("LowTask", priority: "Low", threadId: threadId)
        print("🔵 低优先级任务运行在: \(threadId)")
        try? await Task.sleep(nanoseconds: 100_000_000)
        group.leave()
    }
    
    // 默认优先级任务
    group.enter()
    Task.detached {
        let threadId = Thread.current.description
        await collector.recordTask("DefaultTask", priority: "Default", threadId: threadId)
        print("⚪ 默认优先级任务运行在: \(threadId)")
        try? await Task.sleep(nanoseconds: 100_000_000)
        group.leave()
    }
    
    group.wait()
    
    Task {
        let results = await collector.getResults()
        print()
        print("📊 不同优先级的线程分配:")
        
        for (task, priority, thread) in results {
            print("\(task) (\(priority)): \(thread)")
        }
        
        // 按优先级分组
        var priorityGroups: [String: [String]] = [:]
        for (_, priority, thread) in results {
            if priorityGroups[priority] == nil {
                priorityGroups[priority] = []
            }
            priorityGroups[priority]!.append(thread)
        }
        
        print()
        print("🎯 优先级与线程关系:")
        for (priority, threads) in priorityGroups {
            let uniqueThreads = Set(threads)
            print("\(priority)优先级: 使用了\(uniqueThreads.count)个线程")
        }
        
        finalAnalysis()
    }
}

func finalAnalysis() {
    print()
    print("🎯 最终分析：书中表述的准确性")
    print(String(repeating: "=", count: 50))
    print()
    print("📖 书中原文：\"同样优先级的任务共用一个调度线程\"")
    print()
    print("🔍 这个表述的问题:")
    print("1. 过于绝对化 - 暗示相同优先级=必然共用线程")
    print("2. 忽略了动态调度 - Swift调度器会根据系统状态调整")
    print("3. 没有说明条件 - 在什么情况下会共用线程")
    print()
    print("✅ 更准确的表述应该是:")
    print("\"相同优先级的任务可能会被分配到同一个调度线程，")
    print(" 特别是在系统资源紧张或任务数量超过可用线程数时\"")
    print()
    print("💡 关键理解:")
    print("- Swift使用有限的线程池（通常等于CPU核心数）")
    print("- 调度器会尽量复用线程以减少上下文切换开销")
    print("- 但不是严格的\"相同优先级=共用线程\"的映射关系")
    
    exit(0)
}

// 启动测试
print("🧪 验证书中关于\"相同优先级共用线程\"的说法")
print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
print()

testSamePriorityThreadSharing()

RunLoop.main.run()