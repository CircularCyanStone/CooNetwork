import Foundation

// 严格按照书中例子，不添加任何修改
func shouldLoopAgain() -> Bool {
    // 只是一个例子
    return true
}

// 全局变量用于控制测试
var testRunning = true

// 严格重现书中的例子
func testOriginalExample() {
    print("📚 严格重现书中原始例子")
    print("代码完全按照书中描述，不添加任何优先级或修改")
    print()
    
    let startTime = Date()
    
    // 任务1：完全按照书中的代码
    Task.detached {
        print("Task 1")
        var loop = true
        while loop {
            // 实际工作
            // ...
            loop = shouldLoopAgain() && testRunning
        }
        print("All Done")
    }
    
    // 任务2：完全按照书中的代码
    Task.detached {
        print("Task 2")
    }
    
    // 5秒后停止测试
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        testRunning = false
        
        // 再等1秒观察结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let duration = Date().timeIntervalSince(startTime)
            print()
            print("📊 测试结果分析:")
            print("总运行时间: \(String(format: "%.2f", duration))秒")
            print()
            
            if testRunning {
                print("❌ 如果你看到这条消息在'All Done'之前，说明Task 1的无限循环被提前终止了")
            }
            
            print("🔍 关键观察点:")
            print("1. Task 2 是否在 'All Done' 之前输出？")
            print("2. 如果是，说明Task 2没有被Task 1阻塞")
            print("3. 如果不是，说明Task 2被Task 1的无限循环阻塞了")
            print()
            print("📖 书中预期结果:")
            print("   Task 2应该被阻塞，直到Task 1完成")
            print("   输出应该是: Task 1 -> All Done -> Task 2")
            
            exit(0)
        }
    }
}

// 启动测试
print("🧪 Swift Task 调度测试 - 严格按照书中例子")
print(String(repeating: "=", count: 50))
testOriginalExample()

RunLoop.main.run()