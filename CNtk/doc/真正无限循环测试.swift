import Foundation

// 完全按照书中的例子，shouldLoopAgain() 永远返回 true
func shouldLoopAgain() -> Bool {
    // 只是一个例子
    return true
}

print("🧪 完全按照书中例子 - 真正的无限循环")
print(String(repeating: "=", count: 50))
print("⚠️  警告：这将创建真正的无限循环！")
print("📖 书中原始代码，shouldLoopAgain() 永远返回 true")
print()

let startTime = Date()

// 任务1：完全按照书中的代码 - 真正的无限循环
Task.detached {
    print("Task 1")
    var loop = true
    while loop {
        // 实际工作
        // ...
        loop = shouldLoopAgain()
    }
    print("All Done")  // 这行永远不会执行
}

// 任务2：完全按照书中的代码
Task.detached {
    print("Task 2")
}

// 5秒后强制退出程序来观察结果
DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
    let duration = Date().timeIntervalSince(startTime)
    print()
    print("⏰ 5秒时间到，强制结束测试")
    print("📊 实际运行时间: \(String(format: "%.2f", duration))秒")
    print()
    print("🔍 观察结果:")
    print("如果你看到了 'Task 2'，说明Task 2没有被阻塞")
    print("如果你没看到 'Task 2'，说明Task 2被Task 1的无限循环阻塞了")
    print("如果你没看到 'All Done'，说明Task 1确实在无限循环中")
    print()
    print("📖 这就是书中描述的'资源饥饿'现象")
    
    exit(0)
}

RunLoop.main.run()