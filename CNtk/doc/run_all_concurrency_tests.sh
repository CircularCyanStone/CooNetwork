#!/bin/bash

# Swift并发机制完整测试套件
# 运行所有相关的并发测试，验证理论结论

echo "🚀 Swift并发机制完整测试套件"
echo "=================================="

# 检查是否在正确的目录
if [ ! -f "CNtk框架技术文档.md" ]; then
    echo "❌ 错误: 请在 CNtk/doc 目录下运行此脚本"
    exit 1
fi

echo "📍 当前目录: $(pwd)"
echo ""

# 测试1: Actor注释对比测试
echo "🧪 测试1: Actor注释对比测试"
echo "----------------------------"
if [ -f "run_actor_annotation_test.sh" ]; then
    chmod +x run_actor_annotation_test.sh
    ./run_actor_annotation_test.sh
    echo ""
else
    echo "⚠️  Actor注释测试脚本不存在，跳过"
    echo ""
fi

# 测试2: 并发调度机制测试
echo "🧪 测试2: 并发调度机制测试"
echo "----------------------------"
if [ -f "run_concurrency_test.sh" ]; then
    chmod +x run_concurrency_test.sh
    ./run_concurrency_test.sh
    echo ""
else
    echo "⚠️  并发调度测试脚本不存在，跳过"
    echo ""
fi

# 测试3: 线程架构验证测试
echo "🧪 测试3: 线程架构验证测试"
echo "----------------------------"
if [ -f "run_thread_architecture_test.sh" ]; then
    chmod +x run_thread_architecture_test.sh
    ./run_thread_architecture_test.sh
    echo ""
else
    echo "⚠️  线程架构测试脚本不存在，跳过"
    echo ""
fi

# 测试4: 队列行为测试
echo "🧪 测试4: 队列行为测试"
echo "----------------------------"
if [ -f "test_concurrent_queue_behavior.sh" ]; then
    chmod +x test_concurrent_queue_behavior.sh
    ./test_concurrent_queue_behavior.sh
    echo ""
else
    echo "⚠️  队列行为测试脚本不存在，跳过"
    echo ""
fi

# 测试5: Actor串行化测试
echo "🧪 测试5: Actor串行化测试"
echo "----------------------------"
if [ -f "test_actor_serialization.sh" ]; then
    chmod +x test_actor_serialization.sh
    ./test_actor_serialization.sh
    echo ""
else
    echo "⚠️  Actor串行化测试脚本不存在，跳过"
    echo ""
fi

# 测试6: 调度机制测试
echo "🧪 测试6: 调度机制测试"
echo "----------------------------"
if [ -f "run_scheduling_mechanism_test.sh" ]; then
    chmod +x run_scheduling_mechanism_test.sh
    ./run_scheduling_mechanism_test.sh
    echo ""
else
    echo "⚠️  调度机制测试脚本不存在，跳过"
    echo ""
fi

echo "✅ 所有测试完成！"
echo ""
echo "📚 查看详细结论请参考:"
echo "   - Swift并发机制完整指南.md"
echo "   - Swift并发测试验证与结论.md"
echo "   - CNtk框架技术文档.md"