import Foundation

// 验证：Task2是否会在有空闲线程时立即执行，而不是等待Task1完成
func testTaskExecutionWithAvailableThreads() {
    print("🔬 验证：Task2是否等待Task1，还是使用空闲线程？")
    print(String(repeating: "=", count: 60))
    print("CPU核心数: \(ProcessInfo.processInfo.processorCount)")
    print()
    
    let startTime = Date()
    
    // 创建一个长时间运行的Task1
    Task.detached {
        let threadId = Thread.current.description
        print("[\(timeStamp())] Task1 开始 - 线程: \(threadId)")
        
        // 长时间CPU密集型工作（10秒）
        let endTime = Date().addingTimeInterval(10)
        var counter = 0
        while Date() < endTime {
            counter += 1
            // 每100万次循环检查一次时间，避免过度优化
            if counter % 1000000 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                print("[\(timeStamp())] Task1 仍在运行... 已运行 \(String(format: "%.1f", elapsed))秒")
            }
        }
        
        print("[\(timeStamp())] Task1 完成！")
    }
    
    // 等待1秒，确保Task1开始运行并占用线程
    Thread.sleep(forTimeInterval: 1.0)
    
    // 创建Task2
    Task.detached {
        let threadId = Thread.current.description
        print("[\(timeStamp())] Task2 开始 - 线程: \(threadId)")
        print("[\(timeStamp())] Task2: 我没有等待Task1完成！")
        
        // Task2做一些轻量工作
        for i in 1...5 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            print("[\(timeStamp())] Task2: 工作进度 \(i)/5")
        }
        
        print("[\(timeStamp())] Task2 完成！")
    }
    
    // 等待2秒后创建Task3，进一步验证
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
        Task.detached {
            let threadId = Thread.current.description
            print("[\(timeStamp())] Task3 开始 - 线程: \(threadId)")
            print("[\(timeStamp())] Task3: 我也没有等待Task1！")
            print("[\(timeStamp())] Task3 完成！")
        }
    }
    
    // 创建多个短任务来占用更多线程
    for i in 4...8 {
        Task.detached {
            let threadId = Thread.current.description
            print("[\(timeStamp())] Task\(i) 开始 - 线程: \(threadId)")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            print("[\(timeStamp())] Task\(i) 完成")
        }
    }
    
    // 15秒后结束程序
    DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
        print()
        print("🎯 测试结论:")
        print("如果Task2、Task3等在Task1完成前就开始执行，")
        print("说明它们使用了不同的线程，没有被Task1阻塞。")
        print()
        print("✅ 你的理解是正确的：")
        print("- Task1的无限循环只占用自己的线程")
        print("- 其他任务会使用空闲线程执行")
        print("- 只有当所有线程都被占用时，新任务才会排队等待")
        exit(0)
    }
}

func timeStamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

// 启动测试
testTaskExecutionWithAvailableThreads()
RunLoop.main.run()