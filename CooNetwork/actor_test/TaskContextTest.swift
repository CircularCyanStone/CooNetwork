//
//  TaskContextTest.swift
//  CooNetwork
//
//  Created by Assistant on 2025/1/27.
//

import Foundation

actor TaskContextTest {
    
    func testTaskContextInheritance() async {
        print("🔵 主函数开始 - 线程: \(Thread.current)")
        
        // 1. 普通Task - 继承当前Actor上下文
        Task {
            print("🟢 Task内部开始 - 线程: \(Thread.current)")
            await self.someAsyncWork()
            print("🟢 Task内部结束 - 线程: \(Thread.current)")
        }
        
        // 2. Task.detached - 不继承上下文
        Task.detached {
            print("🔴 Detached Task开始 - 线程: \(Thread.current)")
            // 注意：detached task中不能直接调用self的方法
            try? await Task.sleep(nanoseconds: 100_000_000)
            print("🔴 Detached Task结束 - 线程: \(Thread.current)")
        }
        
        // 3. 指定优先级的Task - 仍然继承上下文
        Task(priority: .background) {
            print("🟡 Background Task开始 - 线程: \(Thread.current)")
            await self.someAsyncWork()
            print("🟡 Background Task结束 - 线程: \(Thread.current)")
        }
        
        print("🔵 主函数结束 - 线程: \(Thread.current)")
    }
    
    private func someAsyncWork() async {
        print("  ⚪ 异步工作开始 - 线程: \(Thread.current)")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        print("  ⚪ 异步工作结束 - 线程: \(Thread.current)")
    }
    
    // 测试跨Actor调用
    func testCrossActorCall() async {
        print("🔵 Actor中调用 - 线程: \(Thread.current)")
        
        let mainActorWork = MainActorWork()
        await mainActorWork.doWork()
        
        print("🔵 返回Actor - 线程: \(Thread.current)")
    }
}

@MainActor
class MainActorWork {
    func doWork() async {
        print("🟣 MainActor工作开始 - 线程: \(Thread.current)")
        
        Task {
            print("🟣 MainActor内Task - 线程: \(Thread.current)")
        }
        
        print("🟣 MainActor工作结束 - 线程: \(Thread.current)")
    }
}

// 全局函数测试
func testGlobalContext() async {
    print("🌍 全局上下文开始 - 线程: \(Thread.current)")
    
    Task {
        print("🌍 全局Task - 线程: \(Thread.current)")
    }
    
    print("🌍 全局上下文结束 - 线程: \(Thread.current)")
}

@MainActor
class MainActorWork {
    func doWork() async {
        print("🟣 MainActor工作开始 - 线程: \(Thread.current)")
        
        Task {
            print("🟣 MainActor内Task - 线程: \(Thread.current)")
        }
        
        print("🟣 MainActor工作结束 - 线程: \(Thread.current)")
    }
}

// 全局函数测试
func testGlobalContext() async {
    print("🌍 全局上下文开始 - 线程: \(Thread.current)")
    
    Task {
        print("🌍 全局Task - 线程: \(Thread.current)")
    }
    
    print("🌍 全局上下文结束 - 线程: \(Thread.current)")
}