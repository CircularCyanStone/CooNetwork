#!/bin/bash

echo "🧪 验证Actor串行执行特性 vs 你以为的并发执行"

# 创建测试代码
cat > /tmp/actor_serialization_test.swift << 'EOF'
import Foundation

// 验证Actor的真实串行行为
actor TestActor {
    private var counter = 0
    
    func longRunningTask(id: Int) async {
        let startTime = Date()
        let threadInfo = getCurrentThreadInfo()
        print("任务\(id) 开始 - \(threadInfo) - 计数器: \(counter) - 时间: 0ms")
        
        // 模拟长时间运行的任务
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        counter += 1
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime) * 1000
        
        print("任务\(id) 完成 - \(threadInfo) - 计数器: \(counter) - 耗时: \(String(format: "%.1f", duration))ms")
    }
}

// 对比：普通并发任务
func normalConcurrentTask(id: Int) async {
    let startTime = Date()
    let threadInfo = getCurrentThreadInfo()
    print("并发任务\(id) 开始 - \(threadInfo)")
    
    // 同样的100ms延迟
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime) * 1000
    print("并发任务\(id) 完成 - \(threadInfo) - 耗时: \(String(format: "%.1f", duration))ms")
}

@MainActor
class SerializationTest {
    
    static func testActorSerialization() async {
        print("🔍 测试1: Actor的串行执行")
        print(String(repeating: "=", count: 50))
        
        let actor = TestActor()
        let startTime = Date()
        
        // 同时发起4个Actor任务
        async let task1: Void = actor.longRunningTask(id: 1)
        async let task2: Void = actor.longRunningTask(id: 2)  
        async let task3: Void = actor.longRunningTask(id: 3)
        async let task4: Void = actor.longRunningTask(id: 4)
        
        print("所有Actor任务已发起")
        
        // 等待所有任务完成
        await task1
        await task2
        await task3
        await task4
        
        let totalTime = Date().timeIntervalSince(startTime) * 1000
        print("Actor任务总耗时: \(String(format: "%.1f", totalTime))ms")
        
        if totalTime > 350 {
            print("✅ 证明：Actor任务确实是串行执行的！")
        } else {
            print("❌ 意外：Actor任务似乎是并发执行的？")
        }
    }
    
    static func testNormalConcurrency() async {
        print("\n🔍 测试2: 普通任务的并发执行")
        print(String(repeating: "=", count: 50))
        
        let startTime = Date()
        
        // 同时发起4个普通并发任务
        async let task1: Void = normalConcurrentTask(id: 1)
        async let task2: Void = normalConcurrentTask(id: 2)
        async let task3: Void = normalConcurrentTask(id: 3)
        async let task4: Void = normalConcurrentTask(id: 4)
        
        print("所有并发任务已发起")
        
        // 等待所有任务完成
        await task1
        await task2
        await task3
        await task4
        
        let totalTime = Date().timeIntervalSince(startTime) * 1000
        print("并发任务总耗时: \(String(format: "%.1f", totalTime))ms")
        
        if totalTime < 150 {
            print("✅ 证明：普通任务确实是并发执行的！")
        } else {
            print("❌ 意外：普通任务似乎是串行执行的？")
        }
    }
    
    static func testMultipleActors() async {
        print("\n🔍 测试3: 多个Actor的并发执行")
        print(String(repeating: "=", count: 50))
        
        let actor1 = TestActor()
        let actor2 = TestActor()
        let actor3 = TestActor()
        let actor4 = TestActor()
        
        let startTime = Date()
        
        // 不同Actor的任务可以并发执行
        async let task1: Void = actor1.longRunningTask(id: 1)
        async let task2: Void = actor2.longRunningTask(id: 2)
        async let task3: Void = actor3.longRunningTask(id: 3)
        async let task4: Void = actor4.longRunningTask(id: 4)
        
        print("多个Actor任务已发起")
        
        await task1
        await task2
        await task3
        await task4
        
        let totalTime = Date().timeIntervalSince(startTime) * 1000
        print("多Actor任务总耗时: \(String(format: "%.1f", totalTime))ms")
        
        if totalTime < 150 {
            print("✅ 证明：不同Actor的任务可以并发执行！")
        } else {
            print("❌ 意外：不同Actor的任务也是串行的？")
        }
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

// 运行所有测试
Task {
    await SerializationTest.testActorSerialization()
    await SerializationTest.testNormalConcurrency()
    await SerializationTest.testMultipleActors()
    
    print("\n📋 总结:")
    print("1. 同一Actor内的任务：串行执行（~400ms）")
    print("2. 普通并发任务：并发执行（~100ms）")
    print("3. 不同Actor的任务：并发执行（~100ms）")
    print("\n🎯 这就是Swift并发的真实行为！")
    
    exit(0)
}

// 保持程序运行
RunLoop.main.run()
EOF

echo "编译并运行测试..."
swift /tmp/actor_serialization_test.swift