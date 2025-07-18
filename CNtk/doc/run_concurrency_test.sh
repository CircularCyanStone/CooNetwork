#!/bin/bash

# Swift并发调度测试运行脚本

echo "🚀 准备运行Swift并发调度测试..."
echo "这个测试将展示不同场景下的执行器切换行为"
echo ""

# 检查是否在正确的目录
if [ ! -f "ConcurrencySchedulingTest.swift" ]; then
    echo "❌ 错误: 请在包含ConcurrencySchedulingTest.swift的目录中运行此脚本"
    exit 1
fi

echo "📝 测试说明:"
echo "- MainThread: 表示主线程(MainActor)"
echo "- Thread-xxx: 表示其他线程"
echo "- 观察跨Actor调用时的线程切换"
echo "- 观察Task继承上下文的行为"
echo ""

echo "▶️  开始执行测试..."
echo "================================================"

# 运行Swift测试
swift ConcurrencySchedulingTest.swift --run-tests

echo "================================================"
echo "✅ 测试完成!"
echo ""
echo "💡 分析要点:"
echo "1. 注意MainActor和其他Actor之间的切换"
echo "2. Task { } 继承当前执行器上下文"
echo "3. Task.detached { } 使用全局执行器"
echo "4. 同Actor内的方法调用不会切换线程"
echo "5. 跨Actor调用会触发执行器切换"