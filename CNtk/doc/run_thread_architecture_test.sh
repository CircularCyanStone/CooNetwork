#!/bin/bash

echo "🧪 开始Swift并发线程架构验证测试"
echo "=================================="

# 编译并运行测试
swift - <<'EOF'
import Foundation

// 测试Swift并发运行时的线程行为
@MainActor
class ThreadBehaviorTest {
    
    static func runAllTests() async {
        print("🧪 开始Swift并发线程架构验证测试\n")
        
        await testMultipleTasksThreadBehavior()
        await testTaskYieldBehavior()
        await testActorSwitchingBehavior()
        
        print("\n✅ 所有测试完成")
    }
    
    // 测试1: 多个并发任务的线程分配
    static func testMultipleTasksThreadBehavior() async {
        print("=== 测试1: 多个并发任务的线程分配 ===")
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...6 {
                group.addTask {
                    let threadInfo = getCurrentThreadInfo()
                    print("Task \(i) 开始执行 - \(threadInfo)")
                    
                    // 模拟一些工作
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    
                    let threadInfoAfter = getCurrentThreadInfo()
                    print("Task \(i) 完成执行 - \(threadInfoAfter)")
                }
            }
        }
        print()
    }
    
    // 测试2: Task.yield()的线程切换行为
    static func testTaskYieldBehavior() async {
        print("=== 测试2: Task.yield()的线程切换行为 ===")
        
        for i in 1...4 {
            let beforeYield = getCurrentThreadInfo()
            print("Task \(i) yield前 - \(beforeYield)")
            
            await Task.yield() // 主动让出执行权
            
            let afterYield = getCurrentThreadInfo()
            print("Task \(i) yield后 - \(afterYield)")
            
            if beforeYield != afterYield {
                print("  ↳ 🔄 线程发生切换")
            } else {
                print("  ↳ ➡️ 保持同一线程")
            }
        }
        print()
    }
    
    // 测试3: Actor切换的线程行为
    static func testActorSwitchingBehavior() async {
        print("=== 测试3: Actor切换的线程行为 ===")
        
        let ntkActor = NtkActor()
        
        for i in 1...3 {
            let mainThread = getCurrentThreadInfo()
            print("第\(i)次调用 - MainActor: \(mainThread)")
            
            let result = await ntkActor.processWithThreadInfo("数据\(i)")
            
            let returnThread = getCurrentThreadInfo()
            print("第\(i)次返回 - MainActor: \(returnThread)")
            print("  ↳ 结果: \(result)")
        }
        print()
    }
}

// 辅助Actor用于测试
actor NtkActor {
    func processWithThreadInfo(_ data: String) -> String {
        let threadInfo = getCurrentThreadInfo()
        print("  NtkActor处理中 - \(threadInfo)")
        return "处理完成: \(data)"
    }
}

// 获取当前线程信息的辅助函数
func getCurrentThreadInfo() -> String {
    let thread = Thread.current
    if thread.isMainThread {
        return "[MainThread]"
    } else {
        return "[Thread-\(thread.hash % 1000)]"
    }
}

// 运行测试
await ThreadBehaviorTest.runAllTests()

print("\n🎯 关键观察点:")
print("1. 不同任务可能在不同线程执行")
print("2. 同一任务在yield前后可能切换线程") 
print("3. Actor切换会导致线程切换")
print("4. 线程会被动态复用，没有固定的'调度线程'")
print("5. Serial Queue保证逻辑顺序，不绑定物理线程")

print("\n📋 架构总结:")
print("• Serial Queue: 逻辑调度队列，不绑定特定线程")
print("• Thread Pool: 物理线程池，所有线程都是平等的工作者")
print("• 调度机制: 任何空闲线程都可以从Serial Queue取任务执行")
print("• Actor隔离: 通过逻辑顺序保证，不是通过线程绑定")
EOF

echo ""
echo "=================================="
echo "✅ 测试完成"