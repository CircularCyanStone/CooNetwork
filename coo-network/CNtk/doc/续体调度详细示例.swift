import Foundation

// 真正验证全局串行调度队列FIFO机制的示例
class RealSchedulingDemo {
    
    @MainActor
    static func demonstrateRealFIFO() async {
        print("=== 真正验证全局串行调度队列FIFO机制 ===\n")
        
        // 使用TaskGroup来观察续体的真实调度顺序
        await withTaskGroup(of: (Int, String).self) { group in
            let startTime = Date()
            
            // 添加任务到TaskGroup，观察它们的完成顺序
            group.addTask {
                let result = await delayedWork(id: 1, name: "快速任务", delay: 0.1, startTime: startTime)
                return (1, result)
            }
            
            group.addTask {
                let result = await delayedWork(id: 2, name: "慢速任务", delay: 0.3, startTime: startTime)
                return (2, result)
            }
            
            group.addTask {
                let result = await delayedWork(id: 3, name: "中速任务", delay: 0.2, startTime: startTime)
                return (3, result)
            }
            
            print("任务添加顺序: 1(快速) -> 2(慢速) -> 3(中速)")
            print("预期物理完成顺序: 1 -> 3 -> 2")
            print("观察续体调度顺序...\n")
            
            // 收集结果，观察实际的完成顺序
            var completionOrder: [(Int, String)] = []
            for await result in group {
                completionOrder.append(result)
                print("任务 \(result.0) 完成: \(result.1)")
            }
            
            print("\n实际完成顺序: \(completionOrder.map { $0.0 })")
        }
        
        print("\n=== 验证续体恢复的真实顺序 ===")
        await demonstrateContinuationResumption()
    }
    
    @MainActor
    static func demonstrateContinuationResumption() async {
        print("\n--- 测试续体恢复顺序 vs 任务完成顺序 ---")
        
        let logger = ContinuationLogger()
        let startTime = Date()
        
        // 创建多个任务，但不使用数组等待
        let task1 = Task {
            await trackedDelayedWork(id: 1, name: "任务A", delay: 0.15, logger: logger, startTime: startTime)
        }
        
        let task2 = Task {
            await trackedDelayedWork(id: 2, name: "任务B", delay: 0.05, logger: logger, startTime: startTime)
        }
        
        let task3 = Task {
            await trackedDelayedWork(id: 3, name: "任务C", delay: 0.10, logger: logger, startTime: startTime)
        }
        
        // 分别等待每个任务，观察续体恢复顺序
        let result1 = await task1.value
        let result2 = await task2.value
        let result3 = await task3.value
        
        print("\n续体调度和恢复日志:")
        let logs = await logger.getLogs()
        for log in logs {
            print(log)
        }
        
        print("\n任务等待顺序: \(result1) -> \(result2) -> \(result3)")
        print("关键观察: 即使任务B最快完成，但我们按A->B->C的顺序等待")
    }
    
    @MainActor
    static func demonstrateActualFIFO() async {
        print("\n=== 真正的FIFO验证：续体入队顺序 ===")
        
        let fifoLogger = FIFOLogger()
        
        // 快速连续创建多个await点，观察续体入队顺序
        async let _ = fifoLogger.logContinuation("续体1", order: 1)
        async let _ = fifoLogger.logContinuation("续体2", order: 2)  
        async let _ = fifoLogger.logContinuation("续体3", order: 3)
        async let _ = fifoLogger.logContinuation("续体4", order: 4)
        
        // 等待所有续体完成
        await fifoLogger.waitForCompletion()
        
        print("\n续体入队和恢复顺序:")
        let logs = await fifoLogger.getFIFOLogs()
        for log in logs {
            print(log)
        }
    }
}

// 用于记录续体调度的Actor
actor ContinuationLogger {
    private var logs: [String] = []
    
    func addLog(_ message: String) {
        logs.append(message)
    }
    
    func getLogs() -> [String] {
        return logs
    }
}

// 专门用于验证FIFO的Logger
actor FIFOLogger {
    private var logs: [String] = []
    private var completedCount = 0
    private let totalTasks = 4
    
    func logContinuation(_ name: String, order: Int) async -> String {
        let timestamp = Date().timeIntervalSince1970
        await addLog("\(String(format: "%.3f", timestamp)): \(name) 续体创建 (顺序: \(order))")
        
        // 模拟不同的处理时间，但让后创建的续体可能先完成
        let delay = order == 1 ? 0.2 : (order == 2 ? 0.1 : (order == 3 ? 0.05 : 0.15))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        let resumeTimestamp = Date().timeIntervalSince1970
        await addLog("\(String(format: "%.3f", resumeTimestamp)): \(name) 续体恢复 (顺序: \(order))")
        
        completedCount += 1
        return "\(name)完成"
    }
    
    func waitForCompletion() async {
        while completedCount < totalTasks {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    private func addLog(_ message: String) {
        logs.append(message)
    }
    
    func getFIFOLogs() -> [String] {
        return logs
    }
}

// 带追踪的延迟工作函数
func trackedDelayedWork(id: Int, name: String, delay: Double, logger: ContinuationLogger, startTime: Date) async -> String {
    let createTime = Date().timeIntervalSince(startTime)
    await logger.addLog("\(String(format: "%.3f", createTime))s: \(name) 开始执行")
    
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    
    let completeTime = Date().timeIntervalSince(startTime)
    await logger.addLog("\(String(format: "%.3f", completeTime))s: \(name) 执行完成")
    
    return name
}

// 简单的延迟工作函数
func delayedWork(id: Int, name: String, delay: Double, startTime: Date) async -> String {
    let createTime = Date().timeIntervalSince(startTime)
    print("\(String(format: "%.3f", createTime))s: \(name) 开始执行")
    
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    
    let completeTime = Date().timeIntervalSince(startTime)
    print("\(String(format: "%.3f", completeTime))s: \(name) 执行完成")
    
    return name
}

// 运行演示
Task { @MainActor in
    await RealSchedulingDemo.demonstrateRealFIFO()
    await RealSchedulingDemo.demonstrateActualFIFO()
    exit(0)
}

// 保持程序运行
RunLoop.main.run()