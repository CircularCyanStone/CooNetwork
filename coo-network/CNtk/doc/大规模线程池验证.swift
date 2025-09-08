import Foundation

// 阻塞任务函数
func blockingTask(id: Int) async -> Int {
    print("🔴 任务 \(id) 开始")
    Thread.sleep(forTimeInterval: 0.5) // 故意使用阻塞操作
    print("🔴 任务 \(id) 完成")
    return id
}

// 协作式任务函数
func cooperativeTask(id: Int) async -> Int {
    print("🟢 任务 \(id) 开始")
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
    print("🟢 任务 \(id) 完成")
    return id
}

// 主测试函数
func runTests() async {
    print("🔬 大规模线程池验证测试")
    print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
    
    // 测试1: 60个阻塞任务（每个0.5秒）
    print("\n📊 测试1: 60个阻塞任务（每个0.5秒）")
    print("理论: 如果有12个线程，应该约2.5秒完成 (60÷12×0.5)")
    
    let startTime1 = Date()
    
    await withTaskGroup(of: Int.self) { group in
        for id in 1...60 {
            group.addTask {
                await blockingTask(id: id)
            }
        }
        
        for await _ in group {
            // 等待所有任务完成
        }
    }
    
    let duration1 = Date().timeIntervalSince(startTime1)
    print("⏱️  实际耗时: \(String(format: "%.2f", duration1))秒")
    print("📈 理论耗时: \(String(format: "%.2f", 60.0/12.0*0.5))秒")
    print("📊 效率: \(String(format: "%.1f", (60.0/12.0*0.5)/duration1*100))%")
    
    // 测试2: 50个协作式任务（对比）
    print("\n📊 测试2: 50个协作式任务（每个0.5秒）")
    print("理论: 应该约0.5秒完成（并发执行）")
    
    let startTime2 = Date()
    
    await withTaskGroup(of: Int.self) { group in
        for id in 1...50 {
            group.addTask {
                await cooperativeTask(id: id)
            }
        }
        
        for await _ in group {
            // 等待所有任务完成
        }
    }
    
    let duration2 = Date().timeIntervalSince(startTime2)
    print("⏱️  实际耗时: \(String(format: "%.2f", duration2))秒")
    
    print("\n🎯 结论:")
    print("阻塞任务耗时: \(String(format: "%.2f", duration1))秒")
    print("协作式任务耗时: \(String(format: "%.2f", duration2))秒")
    print("性能差异: \(String(format: "%.1f", duration1/duration2))倍")
    
    let theoreticalTime = 60.0/12.0*0.5
    if abs(duration1 - theoreticalTime) < 0.5 {
        print("✅ 你的理论得到验证！阻塞任务确实按 任务数/线程数 的公式执行")
        print("   实际: \(String(format: "%.2f", duration1))秒 vs 理论: \(String(format: "%.2f", theoreticalTime))秒")
    } else {
        print("❓ 实际结果与理论有差异，可能受到系统调度等因素影响")
    }
}

// 启动测试
Task {
    await runTests()
    exit(0)
}

RunLoop.main.run()