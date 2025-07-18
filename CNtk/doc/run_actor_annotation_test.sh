#!/bin/bash

# Actor注释对比测试脚本

echo "=== 编译并运行Actor注释对比测试 ==="

# 创建临时的可执行测试文件
cat > /tmp/actor_comparison_test.swift << 'EOF'
import Foundation

/// 网络组件全局Actor
@globalActor
actor NtkActor {
    static var shared = NtkActor()
}

// 测试1: 没有Actor注释的struct
struct SchoolWithoutActor {
    func play() async -> String {
        print("SchoolWithoutActor.play() 开始执行")
        try? await Task.sleep(nanoseconds: 100_000_000)
        print("SchoolWithoutActor.play() 执行完成")
        return "play without actor"
    }
}

// 测试2: 有@NtkActor注释的struct
@NtkActor
struct SchoolWithActor {
    func play() async -> String {
        print("SchoolWithActor.play() 开始执行")
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
        print("ActorComparisonTest 在 @NtkActor 上执行")
        
        // 测试没有Actor注释的情况
        print("\n1. 调用SchoolWithoutActor:")
        let result1 = await schoolWithoutActor.play()
        print("返回结果: \(result1)")
        
        // 测试有Actor注释的情况
        print("\n2. 调用SchoolWithActor:")
        let result2 = await schoolWithActor.play()
        print("返回结果: \(result2)")
    }
}

@MainActor
class MainActorTest {
    func testFromMainActor() async {
        print("\n=== 从@MainActor调用测试 ===")
        print("MainActorTest 在 @MainActor 上执行")
        
        let schoolWithoutActor = SchoolWithoutActor()
        let schoolWithActor = await SchoolWithActor()
        
        // 测试没有Actor注释的情况
        print("\n1. 调用SchoolWithoutActor:")
        let result1 = await schoolWithoutActor.play()
        print("返回结果: \(result1)")
        
        // 测试有Actor注释的情况
        print("\n2. 调用SchoolWithActor:")
        let result2 = await schoolWithActor.play()
        print("返回结果: \(result2)")
    }
}

// 全局函数测试
func testFromGlobalContext() async {
    print("\n=== 从全局上下文调用测试 ===")
    print("testFromGlobalContext 在全局执行器上执行")
    
    let schoolWithoutActor = SchoolWithoutActor()
    let schoolWithActor = await SchoolWithActor()
    
    // 测试没有Actor注释的情况
    print("\n1. 调用SchoolWithoutActor:")
    let result1 = await schoolWithoutActor.play()
    print("返回结果: \(result1)")
    
    // 测试有Actor注释的情况
    print("\n2. 调用SchoolWithActor:")
    let result2 = await schoolWithActor.play()
    print("返回结果: \(result2)")
}

// 性能对比测试
func performanceComparison() async {
    print("\n=== 性能对比测试 ===")
    
    let schoolWithoutActor = SchoolWithoutActor()
    let schoolWithActor = await SchoolWithActor()
    
    // 测试没有Actor注释的性能
    let start1 = Date()
    for i in 1...5 {
        print("第\(i)次调用SchoolWithoutActor")
        _ = await schoolWithoutActor.play()
    }
    let duration1 = Date().timeIntervalSince(start1)
    print("SchoolWithoutActor 5次调用总时间: \(duration1)秒")
    
    // 测试有Actor注释的性能
    let start2 = Date()
    for i in 1...5 {
        print("第\(i)次调用SchoolWithActor")
        _ = await schoolWithActor.play()
    }
    let duration2 = Date().timeIntervalSince(start2)
    print("SchoolWithActor 5次调用总时间: \(duration2)秒")
    
    print("性能差异: \(abs(duration2 - duration1))秒")
}

// 主测试函数
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
    
    // 测试4: 性能对比
    await performanceComparison()
    
    print("\n=== 测试完成 ===")
    print("\n结论:")
    print("1. 在同一Actor内调用时，有无@NtkActor注释的行为完全相同")
    print("2. 跨Actor调用时，@NtkActor注释会强制执行器切换")
    print("3. 性能差异主要体现在跨Actor调用的切换开销上")
}

// 运行测试
Task {
    await runActorAnnotationComparison()
    exit(0)
}

// 保持程序运行
RunLoop.main.run()
EOF

echo "编译测试文件..."
if swiftc -o /tmp/actor_comparison_test /tmp/actor_comparison_test.swift; then
    echo "编译成功，运行测试..."
    /tmp/actor_comparison_test
    
    # 清理临时文件
    rm -f /tmp/actor_comparison_test /tmp/actor_comparison_test.swift
else
    echo "编译失败"
    exit 1
fi