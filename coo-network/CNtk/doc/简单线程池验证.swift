import Foundation

// 阻塞任务函数
func blockingTask(id: Int) async -> Int {
    print("🔴 任务 \(id) 开始 - 时间: \(Date())")
    Thread.sleep(forTimeInterval: 1.0) // 故意使用阻塞操作
    print("🔴 任务 \(id) 完成 - 时间: \(Date())")
    return id
}

// 协作式任务函数
func cooperativeTask(id: Int) async -> Int {
    print("🟢 任务 \(id) 开始 - 时间: \(Date())")
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
    print("🟢 任务 \(id) 完成 - 时间: \(Date())")
    return id
}

Task {
    print("🔬 验证用户的线程池理论")
    print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
    
    // 测试1: 阻塞任务
    print("\n📊 测试1: 6个阻塞任务（每个1秒）")
    print("理论: 如果有6个线程，应该约1秒完成")
    
    let startTime1 = Date()
    
    let blockingTasks = (1...6).map { id in
        Task { await blockingTask(id: id) }
    }
    
    for task in blockingTasks {
        _ = await task.value
    }
    
    let duration1 = Date().timeIntervalSince(startTime1)
    print("⏱️  实际耗时: \(String(format: "%.2f", duration1))秒")
    
    // 测试2: 协作式任务（对比）
    print("\n📊 测试2: 6个协作式任务（每个1秒）")
    print("理论: 应该约1秒完成（并发执行）")
    
    let startTime2 = Date()
    
    let cooperativeTasks = (1...6).map { id in
        Task { await cooperativeTask(id: id) }
    }
    
    for task in cooperativeTasks {
        _ = await task.value
    }
    
    let duration2 = Date().timeIntervalSince(startTime2)
    print("⏱️  实际耗时: \(String(format: "%.2f", duration2))秒")
    
    print("\n🎯 结论:")
    print("阻塞任务耗时: \(String(format: "%.2f", duration1))秒")
    print("协作式任务耗时: \(String(format: "%.2f", duration2))秒")
    
    if duration1 <= 2.0 {
        print("✅ 用户理论正确！阻塞任务确实可以并行执行")
    } else {
        print("❌ 阻塞任务执行时间超出预期")
    }
    
    exit(0)
}

// 防止程序立即退出
RunLoop.main.run()