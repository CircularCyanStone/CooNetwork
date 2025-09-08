import Foundation

// 创建一个更极端的例子来重现饥饿
func extremeStarvationDemo() {
    print("📚 极端饥饿演示 - 重现书中问题")
    print(String(repeating: "=", count: 60))
    
    var shouldStop = false
    let startTime = Date()
    
    // 任务1: 极度占用CPU的循环任务
    Task.detached(priority: .high) {
        print("🔴 Task 1 开始 - 将占用线程")
        var count = 0
        while !shouldStop {
            // 极度CPU密集的操作，不给其他任务机会
            for _ in 0..<1000000 {
                count += 1
                // 故意不使用任何await，完全占用线程
                _ = sin(Double(count)) * cos(Double(count))
            }
            
            if count % 10000000 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                print("🔴 Task 1 循环中... 已运行 \(String(format: "%.1f", elapsed))秒")
            }
        }
        print("🔴 Task 1 完成")
    }
    
    // 任务2: 尝试执行的任务
    Task.detached(priority: .medium) {
        print("🟡 Task 2 开始")
        print("🟡 Task 2 完成")
    }
    
    // 任务3: 另一个尝试执行的任务
    Task.detached(priority: .low) {
        print("🔵 Task 3 开始")
        print("🔵 Task 3 完成")
    }
    
    // 2秒后停止第一个任务
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        shouldStop = true
        print("⏰ 2秒到，停止Task 1")
        
        // 再等1秒观察结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let totalTime = Date().timeIntervalSince(startTime)
            print("\n📊 结果分析:")
            print("总运行时间: \(String(format: "%.2f", totalTime))秒")
            print("如果Task 2和Task 3在Task 1完成前就输出，说明没有饥饿")
            print("如果Task 2和Task 3在Task 1完成后才输出，说明发生了饥饿")
            
            // 开始协作式演示
            cooperativeDemo()
        }
    }
}

// 协作式演示
func cooperativeDemo() {
    print("\n🔬 协作式演示 - 使用Task.yield()解决饥饿")
    print(String(repeating: "=", count: 60))
    
    var shouldStop = false
    let startTime = Date()
    
    // 任务1: 使用协作式调度的循环任务
    Task.detached(priority: .high) {
        print("🟢 Cooperative Task 1 开始")
        var count = 0
        while !shouldStop {
            // 同样的CPU密集操作
            for _ in 0..<1000000 {
                count += 1
                _ = sin(Double(count)) * cos(Double(count))
            }
            
            // 关键：主动让出执行权
            await Task.yield()
            
            if count % 10000000 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                print("🟢 Cooperative Task 1 循环中... 已运行 \(String(format: "%.1f", elapsed))秒")
            }
        }
        print("🟢 Cooperative Task 1 完成")
    }
    
    // 任务2: 现在应该能正常执行
    Task.detached(priority: .medium) {
        print("🟡 Cooperative Task 2 开始")
        print("🟡 Cooperative Task 2 完成")
    }
    
    // 任务3: 现在应该能正常执行
    Task.detached(priority: .low) {
        print("🔵 Cooperative Task 3 开始")
        print("🔵 Cooperative Task 3 完成")
    }
    
    // 2秒后停止
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        shouldStop = true
        print("⏰ 2秒到，停止Cooperative Task 1")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let totalTime = Date().timeIntervalSince(startTime)
            print("\n📊 协作式结果:")
            print("总运行时间: \(String(format: "%.2f", totalTime))秒")
            print("使用Task.yield()后，其他任务应该能及时执行")
            
            // 最终分析
            finalAnalysis()
        }
    }
}

func finalAnalysis() {
    print("\n🎯 最终分析和解释:")
    print(String(repeating: "=", count: 60))
    print("📖 书中描述的问题确实存在，但现代Swift运行时有所改进")
    print()
    print("🔍 关键理解:")
    print("1. Task.detached 不保证每个任务都在独立线程上运行")
    print("2. Swift的并发调度器使用有限的线程池")
    print("3. CPU密集型循环可能占用整个线程，导致同线程的其他任务等待")
    print("4. 使用 await Task.yield() 可以主动让出执行权")
    print("5. 任务优先级会影响调度顺序")
    print()
    print("💡 你的困惑是合理的！")
    print("   现代Swift运行时确实比书中描述的更智能")
    print("   但在极端情况下，饥饿问题仍然可能发生")
    
    exit(0)
}

// 启动演示
extremeStarvationDemo()
RunLoop.main.run()