import UIKit

class ConcurrencyTestViewController: UIViewController {

    // 使用Actor来确保对共享数据的线程安全访问
    actor TestDataCollector {
        struct TaskInfo {
            let id: Int
            let timestamp: TimeInterval
            let threadName: String
        }

        private(set) var taskStartInfos: [TaskInfo] = []

        func recordStart(id: Int, threadName: String) {
            let info = TaskInfo(id: id, timestamp: Date().timeIntervalSince1970, threadName: threadName)
            taskStartInfos.append(info)
        }

        func getResults() -> [TaskInfo] {
            return taskStartInfos
        }
    }

    let dataCollector = TestDataCollector()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        print("--- 开始并发任务测试 ---")
        print("预期：任务将在不同的线程上并行执行，但它们的启动记录将通过一个统一的调度点，表现出串行特性。")

        // 启动一个任务来运行我们的测试并等待结果
        Task {
            await runConcurrencyTest()
            await analyzeResults()
        }
    }

    func runConcurrencyTest() async {
        let taskCount = 100
        
        // 使用任务组来并发执行大量任务
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    // 1. 立即记录任务启动信息
                    // 这是关键：我们观察的是任务被“调度”的瞬间
                    let threadName = Thread.current.description
                    await self.dataCollector.recordStart(id: i, threadName: threadName)
                    
                    // 2. 模拟耗时工作，让任务有机会并行执行
                    // 随机睡眠0到10毫秒
                    let sleepTime = UInt64.random(in: 0...10_000_000)
                    try? await Task.sleep(nanoseconds: sleepTime)
                }
            }
        }
    }

    func analyzeResults() async {
        let results = await dataCollector.getResults()
        
        print("\n--- 测试结果分析 ---")
        print("总共记录了 \(results.count) 个任务的启动信息。")

        // 检查线程多样性
        let uniqueThreads = Set(results.map { $0.threadName })
        print("\n1. 线程执行情况：")
        print("任务在 \(uniqueThreads.count) 个不同的线程上执行过。这证明了执行是并行的。")
        uniqueThreads.forEach { print("  - \($0)") }

        // 检查时间戳的序列性
        var isMonotonic = true
        for i in 1..<results.count {
            if results[i].timestamp < results[i-1].timestamp {
                isMonotonic = false
                break
            }
        }
        
        print("\n2. 调度入口分析：")
        if isMonotonic {
            print("✅ 成功：所有任务的启动时间戳是单调递增的。")
            print("   这强烈表明，尽管任务在多个线程上并行执行，但它们是通过一个统一的、串行化的入口点进行调度和记录的。")
        } else {
            print("❌ 失败：任务的启动时间戳不是单调递增的，这与我们的模型假设不符。")
        }
        
        print("\n--- 详细启动记录 (前20条) ---")
        for info in results.prefix(20) {
            // 格式化时间戳以便阅读
            let formattedTimestamp = String(format: "%.6f", info.timestamp)
            print("任务ID: \(info.id), 时间戳: \(formattedTimestamp), 线程: \(info.threadName)")
        }
        
        print("\n--- 测试结束 --- ")
        print("请在Xcode的Debug Navigator中设置断点到 `recordStart` 方法内部，然后单步执行，观察左侧线程调用栈的变化，您会看到调用总是发生在名为 'com.apple.root.xxx-qos.cooperative' 的队列上。")
    }
}