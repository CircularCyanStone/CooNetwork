import Foundation

// 全局控制变量
var shouldStop = false

// 模拟书中的例子
func shouldLoopAgain() -> Bool {
    // 简单的检查，不做任何异步操作
    return !shouldStop
}

// 重现书中的确切问题
func demonstrateStarvation() {
    print("🔬 重现书中的饥饿问题")
    print(String(repeating: "=", count: 50))
    
    // 任务1: 占用线程的循环任务（书中的例子）
    Task.detached {
        print("Task 1")
        var loop = true
        while loop {
            // 实际工作 - 这里是CPU密集型操作，不会让出线程
            for _ in 0..<100000 {
                // 模拟计算工作
                _ = sqrt(Double.random(in: 1...1000))
            }
            loop = shouldLoopAgain()
        }
        print("All Done")
    }
    
    // 任务2: 被饥饿的任务
    Task.detached {
        print("Task 2")
    }
    
    // 让第一个任务运行2秒后停止
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        shouldStop = true
        
        // 再等1秒让所有任务完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("\n📊 分析:")
            print("如果你看到 'Task 2' 在 'All Done' 之前输出，说明没有饥饿")
            print("如果你看到 'Task 2' 在 'All Done' 之后输出，说明发生了饥饿")
            exit(0)
        }
    }
}

// 对比测试：使用协作式调度
func demonstrateCooperative() {
    print("\n🔬 对比：协作式调度")
    print(String(repeating: "=", count: 50))
    
    shouldStop = false // 重置
    
    // 任务1: 使用协作式调度的循环任务
    Task.detached {
        print("Cooperative Task 1")
        var loop = true
        while loop {
            // 实际工作
            for _ in 0..<100000 {
                _ = sqrt(Double.random(in: 1...1000))
            }
            
            // 关键：主动让出执行权
            await Task.yield()
            
            loop = shouldLoopAgain()
        }
        print("Cooperative All Done")
    }
    
    // 任务2: 现在可以正常执行的任务
    Task.detached {
        print("Cooperative Task 2")
    }
    
    // 让第一个任务运行2秒后停止
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        shouldStop = true
        
        // 再等1秒让所有任务完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("\n📊 对比分析:")
            print("使用 Task.yield() 后，Task 2 应该能够及时执行")
            exit(0)
        }
    }
}

// 启动演示
print("📚 Swift Task 饥饿现象演示")
print("这个例子将演示书中描述的问题")
print()

demonstrateStarvation()

// 3秒后运行对比测试
DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
    demonstrateCooperative()
}

RunLoop.main.run()