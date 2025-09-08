import Foundation

// 用于测试Swift并发调度机制的实际行为
class ConcurrencySchedulingTest {
    
    // 辅助函数：打印当前线程信息
    static func printCurrentContext(_ message: String) {
        let threadName = Thread.current.isMainThread ? "MainThread" : "Thread-\(Thread.current.hash)"
        print("[\(threadName)] \(message)")
    }
    
    // 测试1: 跨Actor调用的执行器切换
    @MainActor
    static func testCrossActorCalls() async {
        print("\n=== 测试1: 跨Actor调用 ===")
        
        let uiManager = UITestManager()
        await uiManager.handleUserAction()
    }
    
    // 测试2: Task上下文继承
    static func testTaskContextInheritance() async {
        print("\n=== 测试2: Task上下文继承 ===")
        
        let networkManager = NetworkTestManager()
        await networkManager.testTaskCreation()
    }
    
    // 测试3: 复杂调用链
    @MainActor
    static func testComplexCallChain() async {
        print("\n=== 测试3: 复杂调用链 ===")
        
        let controller = ComplexTestController()
        await controller.complexFlow()
    }
    
    // 测试4: 普通异步函数调用
    static func testGlobalAsyncFunctions() async {
        print("\n=== 测试4: 普通异步函数调用 ===")
        
        printCurrentContext("开始全局函数测试")
        let result = await globalAsyncFunction()
        printCurrentContext("全局函数测试完成: \(result)")
    }
}

// 测试用的Actor和类
@MainActor
class UITestManager {
    func handleUserAction() async {
        ConcurrencySchedulingTest.printCurrentContext("UI操作开始")
        
        let networkManager = NetworkTestManager()
        let result = await networkManager.fetchData()
        
        ConcurrencySchedulingTest.printCurrentContext("UI操作完成: \(result)")
    }
}

actor NetworkTestManager {
    func fetchData() async -> String {
        ConcurrencySchedulingTest.printCurrentContext("网络请求开始")
        
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        ConcurrencySchedulingTest.printCurrentContext("网络请求完成")
        return "网络数据"
    }
    
    func testTaskCreation() async {
        ConcurrencySchedulingTest.printCurrentContext("Actor中创建Task测试开始")
        
        // 测试Task继承上下文
        Task {
            ConcurrencySchedulingTest.printCurrentContext("Task内部 - 应该继承Actor上下文")
            
            // 在Task内部调用Actor方法
            let data = await self.internalMethod()
            ConcurrencySchedulingTest.printCurrentContext("Task内部调用完成: \(data)")
        }
        
        // 测试Task.detached
        Task.detached {
            ConcurrencySchedulingTest.printCurrentContext("Task.detached内部 - 应该在全局执行器")
            
            // 需要await来访问Actor
            let manager = NetworkTestManager()
            let data = await manager.internalMethod()
            ConcurrencySchedulingTest.printCurrentContext("Task.detached调用完成: \(data)")
        }
        
        ConcurrencySchedulingTest.printCurrentContext("Actor中Task创建完成")
    }
    
    private func internalMethod() async -> String {
        ConcurrencySchedulingTest.printCurrentContext("Actor内部方法执行")
        return "内部数据"
    }
}

@MainActor
class ComplexTestController {
    func complexFlow() async {
        ConcurrencySchedulingTest.printCurrentContext("复杂流程开始")
        
        // 步骤1: 调用网络管理器
        let networkManager = NetworkTestManager()
        let networkData = await networkManager.fetchData()
        
        ConcurrencySchedulingTest.printCurrentContext("获取到网络数据: \(networkData)")
        
        // 步骤2: 调用全局异步函数
        let globalData = await globalAsyncFunction()
        
        ConcurrencySchedulingTest.printCurrentContext("获取到全局数据: \(globalData)")
        
        // 步骤3: 调用自定义Actor
        let processor = DataTestProcessor()
        let processedData = await processor.process(networkData + globalData)
        
        ConcurrencySchedulingTest.printCurrentContext("处理完成: \(processedData)")
    }
}

actor DataTestProcessor {
    func process(_ data: String) async -> String {
        ConcurrencySchedulingTest.printCurrentContext("数据处理开始: \(data)")
        
        // 模拟处理时间
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        ConcurrencySchedulingTest.printCurrentContext("数据处理完成")
        return "已处理的\(data)"
    }
}

// 全局异步函数
func globalAsyncFunction() async -> String {
    ConcurrencySchedulingTest.printCurrentContext("全局异步函数执行")
    
    // 模拟异步工作
    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
    
    ConcurrencySchedulingTest.printCurrentContext("全局异步函数完成")
    return "全局数据"
}

// 主测试函数
func runConcurrencyTests() async {
    print("🚀 Swift并发调度机制测试开始")
    print("观察不同场景下的线程切换行为")
    
    await ConcurrencySchedulingTest.testCrossActorCalls()
    
    // 等待一下，让异步操作完成
    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
    
    await ConcurrencySchedulingTest.testTaskContextInheritance()
    
    try? await Task.sleep(nanoseconds: 200_000_000)
    
    await ConcurrencySchedulingTest.testComplexCallChain()
    
    try? await Task.sleep(nanoseconds: 200_000_000)
    
    await ConcurrencySchedulingTest.testGlobalAsyncFunctions()
    
    print("\n✅ 所有测试完成")
    print("\n📝 观察要点:")
    print("1. MainThread 表示主线程(MainActor)")
    print("2. Thread-xxx 表示其他线程")
    print("3. 注意跨Actor调用时的线程切换")
    print("4. 注意Task继承上下文 vs Task.detached的区别")
    print("5. 注意同Actor内调用不会切换线程")
}

// 如果这个文件被直接运行，执行测试
if CommandLine.arguments.contains("--run-tests") {
    Task {
        await runConcurrencyTests()
        exit(0)
    }
    
    // 保持程序运行
    RunLoop.main.run()
}