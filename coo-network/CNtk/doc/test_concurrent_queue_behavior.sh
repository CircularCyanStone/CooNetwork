#!/bin/bash

echo "🧪 验证Swift Serial Queue的无锁并发特性"

# 创建测试代码
cat > /tmp/concurrent_queue_test.swift << 'EOF'
import Foundation

// 测试无锁并发队列的行为
@MainActor
class ConcurrentQueueTest {
    
    static func testConcurrentAccess() async {
        print("🔍 测试多线程并发访问Serial Queue")
        
        // 测试1: 高并发入队操作
        print("\n=== 测试1: 高并发任务创建 ===")
        let startTime = Date()
        
        // 同时创建大量任务，观察队列行为
        await withTaskGroup(of: Void.self) { group in
            for batch in 1...5 {
                for i in 1...10 {
                    group.addTask {
                        let createTime = Date().timeIntervalSince(startTime) * 1000
                        let threadInfo = getCurrentThreadInfo()
                        
                        print("批次\(batch)-任务\(i) 创建 - \(threadInfo) - \(String(format: "%.1f", createTime))ms")
                        
                        // 模拟工作
                        try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...10_000_000))
                        
                        let completeTime = Date().timeIntervalSince(startTime) * 1000
                        print("批次\(batch)-任务\(i) 完成 - \(threadInfo) - \(String(format: "%.1f", completeTime))ms")
                    }
                }
                
                // 短暂间隔，观察批次间的行为
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
        }
        
        print("\n=== 测试2: Actor并发访问 ===")
        let testActor = ConcurrentTestActor()
        
        // 多个线程同时访问同一Actor
        await withTaskGroup(of: Void.self) { group in
            for i in 1...8 {
                group.addTask {
                    await testActor.processWork(id: i)
                }
            }
        }
        
        print("\n=== 测试3: 队列状态观察 ===")
        await observeQueueBehavior()
    }
    
    static func observeQueueBehavior() async {
        print("观察队列的并发访问模式...")
        
        // 创建观察者任务
        let observer = Task {
            for i in 1...20 {
                let threadInfo = getCurrentThreadInfo()
                print("观察者-\(i) - \(threadInfo)")
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        // 同时创建工作任务
        let workers = (1...5).map { workerId in
            Task {
                for taskId in 1...4 {
                    let threadInfo = getCurrentThreadInfo()
                    print("工作者\(workerId)-任务\(taskId) - \(threadInfo)")
                    
                    // 不同长度的工作
                    let workTime = UInt64(taskId * 5_000_000) // 5-20ms
                    try? await Task.sleep(nanoseconds: workTime)
                }
            }
        }
        
        // 等待所有任务完成
        await observer.value
        for worker in workers {
            await worker.value
        }
    }
}

// 测试Actor的并发行为
actor ConcurrentTestActor {
    private var counter = 0
    
    func processWork(id: Int) async {
        let startThread = getCurrentThreadInfo()
        print("Actor工作\(id) 开始 - \(startThread)")
        
        counter += 1
        let currentCount = counter
        
        // 模拟异步工作
        try? await Task.sleep(nanoseconds: UInt64.random(in: 5_000_000...15_000_000))
        
        let endThread = getCurrentThreadInfo()
        print("Actor工作\(id) 完成 - \(endThread) - 计数: \(currentCount)")
    }
}

func getCurrentThreadInfo() -> String {
    let thread = Thread.current
    if thread.isMainThread {
        return "[MainThread]"
    } else {
        return "[Thread-\(thread.hash % 1000)]"
    }
}

// 运行测试
Task {
    await ConcurrentQueueTest.testConcurrentAccess()
    print("\n✅ 测试完成")
    exit(0)
}

// 保持程序运行
RunLoop.main.run()
EOF

echo "编译并运行测试..."
swift /tmp/concurrent_queue_test.swift