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
            for i in 1...8 {
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
        
        for i in 1...5 {
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

// 高级测试：观察线程池的动态行为
@MainActor
class AdvancedThreadPoolTest {
    
    static func testThreadPoolDynamics() async {
        print("🔬 高级测试: 线程池动态行为观察")
        
        // 创建大量短期任务，观察线程复用
        print("\n--- 短期任务测试 (观察线程复用) ---")
        for batch in 1...3 {
            print("批次 \(batch):")
            await withTaskGroup(of: Void.self) { group in
                for i in 1...4 {
                    group.addTask {
                        let start = getCurrentThreadInfo()
                        print("  短任务\(i) - \(start)")
                        // 很短的任务
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    }
                }
            }
        }
        
        // 创建长期任务，观察线程分配
        print("\n--- 长期任务测试 (观察线程分配) ---")
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    let start = getCurrentThreadInfo()
                    print("长任务\(i) 开始 - \(start)")
                    
                    // 较长的任务
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    let end = getCurrentThreadInfo()
                    print("长任务\(i) 结束 - \(end)")
                }
            }
        }
    }
}

// 主测试函数
func runThreadArchitectureTests() async {
    await ThreadBehaviorTest.runAllTests()
    await AdvancedThreadPoolTest.testThreadPoolDynamics()
    
    print("\n🎯 关键观察点:")
    print("1. 不同任务可能在不同线程执行")
    print("2. 同一任务在yield前后可能切换线程")
    print("3. Actor切换会导致线程切换")
    print("4. 线程会被动态复用，没有固定的'调度线程'")
    print("5. Serial Queue保证逻辑顺序，不绑定物理线程")
}

// 运行测试
Task {
    await runThreadArchitectureTests()
}