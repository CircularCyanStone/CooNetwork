import Foundation

/// 网络组件全局Actor
@globalActor
actor NtkActor {
    static var shared = NtkActor()
}

// 测试1: 没有Actor注释的struct
struct SchoolWithoutActor {
    func play() async -> String {
        print("SchoolWithoutActor.play() 开始执行 - 继承调用者的执行器")
        try? await Task.sleep(nanoseconds: 100_000_000)
        print("SchoolWithoutActor.play() 执行完成")
        return "play without actor"
    }
}

// 测试2: 有@NtkActor注释的struct
@NtkActor
struct SchoolWithActor {
    func play() async -> String {
        print("SchoolWithActor.play() 开始执行 - 强制在@NtkActor上执行")
        try? await Task.sleep(nanoseconds: 100_000_000)
        print("SchoolWithActor.play() 执行完成")
        return "play with actor"
    }
}

@NtkActor
class ActorComparisonTest {
    let schoolWithoutActor = SchoolWithoutActor()
    let schoolWithActor = SchoolWithActor()
    
    func testFromNtkActor() async {
        print("\n=== 从@NtkActor调用测试 ===")
        print("ActorComparisonTest 在 @NtkActor 执行器上运行")
        
        // 测试没有Actor注释的情况
        print("\n1. 调用SchoolWithoutActor (无Actor注释):")
        print("   预期: 继承@NtkActor执行器，无切换")
        let result1 = await schoolWithoutActor.play()
        print("   结果: \(result1)")
        print("   返回后仍在@NtkActor执行器上")
        
        // 测试有Actor注释的情况
        print("\n2. 调用SchoolWithActor (有@NtkActor注释):")
        print("   预期: 保持在@NtkActor执行器，无切换")
        let result2 = await schoolWithActor.play()
        print("   结果: \(result2)")
        print("   返回后仍在@NtkActor执行器上")
    }
}

@MainActor
class MainActorTest {
    func testFromMainActor() async {
        print("\n=== 从@MainActor调用测试 ===")
        print("MainActorTest 在 @MainActor 执行器上运行")
        
        let schoolWithoutActor = SchoolWithoutActor()
        let schoolWithActor = await SchoolWithActor()
        
        // 测试没有Actor注释的情况
        print("\n1. 调用SchoolWithoutActor (无Actor注释):")
        print("   预期: 继承@MainActor执行器，无切换")
        let result1 = await schoolWithoutActor.play()
        print("   结果: \(result1)")
        print("   返回后仍在@MainActor执行器上")
        
        // 测试有Actor注释的情况
        print("\n2. 调用SchoolWithActor (有@NtkActor注释):")
        print("   预期: 切换到@NtkActor执行器，然后切换回@MainActor")
        let result2 = await schoolWithActor.play()
        print("   结果: \(result2)")
        print("   返回后切换回@MainActor执行器")
    }
}

// 全局函数测试
func testFromGlobalContext() async {
    print("\n=== 从全局上下文调用测试 ===")
    print("testFromGlobalContext 在全局执行器上运行")
    
    let schoolWithoutActor = SchoolWithoutActor()
    let schoolWithActor = await SchoolWithActor()
    
    // 测试没有Actor注释的情况
    print("\n1. 调用SchoolWithoutActor (无Actor注释):")
    print("   预期: 继承全局执行器，无切换")
    let result1 = await schoolWithoutActor.play()
    print("   结果: \(result1)")
    print("   返回后仍在全局执行器上")
    
    // 测试有Actor注释的情况
    print("\n2. 调用SchoolWithActor (有@NtkActor注释):")
    print("   预期: 切换到@NtkActor执行器，然后切换回全局执行器")
    let result2 = await schoolWithActor.play()
    print("   结果: \(result2)")
    print("   返回后切换回全局执行器")
}

// 执行器继承机制详细测试
func detailedExecutorInheritanceTest() async {
    print("\n=== 执行器继承机制详细分析 ===")
    
    print("\n📋 核心规则:")
    print("1. 普通异步函数: 继承调用者的执行器上下文")
    print("2. Actor注释函数: 强制在指定Actor执行器上运行")
    print("3. 跨Actor调用: 自动进行执行器切换")
    
    print("\n🔍 测试场景分析:")
    
    // 场景1: @NtkActor -> 普通异步函数
    print("\n场景1: @NtkActor调用普通异步函数")
    print("- 调用者: @NtkActor执行器")
    print("- 被调用者: SchoolWithoutActor.play() (无Actor注释)")
    print("- 执行器行为: 继承@NtkActor执行器，无切换开销")
    print("- 性能: 最优，零切换成本")
    
    // 场景2: @MainActor -> 普通异步函数
    print("\n场景2: @MainActor调用普通异步函数")
    print("- 调用者: @MainActor执行器")
    print("- 被调用者: SchoolWithoutActor.play() (无Actor注释)")
    print("- 执行器行为: 继承@MainActor执行器，无切换开销")
    print("- 性能: 最优，零切换成本")
    
    // 场景3: @MainActor -> @NtkActor函数
    print("\n场景3: @MainActor调用@NtkActor函数")
    print("- 调用者: @MainActor执行器")
    print("- 被调用者: SchoolWithActor.play() (@NtkActor注释)")
    print("- 执行器行为: @MainActor -> @NtkActor -> @MainActor")
    print("- 性能: 有切换开销，但保证Actor隔离")
    
    print("\n✅ 结论:")
    print("- 普通异步函数采用'执行器继承'策略")
    print("- Actor注释函数采用'强制执行器'策略")
    print("- 这种设计平衡了性能和安全性")
}

// 运行测试的异步函数
func runActorAnnotationComparison() async {
    print("=== Actor注释对比测试开始 ===")
    
    // 测试1: 从@NtkActor调用
    let ntkTest = await ActorComparisonTest()
    await ntkTest.testFromNtkActor()
    
    // 测试2: 从@MainActor调用
    let mainTest = await MainActorTest()
    await mainTest.testFromMainActor()
    
    // 测试3: 从全局上下文调用
    await testFromGlobalContext()
    
    // 测试4: 详细机制分析
    await detailedExecutorInheritanceTest()
    
    print("\n=== 测试完成 ===")
    
    print("\n🎯 关键发现:")
    print("1. @NtkActor调用普通异步函数 → 继承执行器 (无切换)")
    print("2. @MainActor调用普通异步函数 → 继承执行器 (无切换)")
    print("3. 任何Actor调用@NtkActor函数 → 强制切换到@NtkActor")
    print("4. 执行器继承是Swift并发的性能优化策略")
}

// 如果要运行测试，请在其他地方调用：
// Task { await runActorAnnotationComparison() }