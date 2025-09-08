#!/bin/bash

# Swift并发机制演示：阻塞 vs 协作式挂起
# 运行阻塞vs协作式挂起演示

echo "🚀 开始Swift并发机制演示：阻塞 vs 协作式挂起"
echo "================================================"

# 检查Swift版本
echo "📋 Swift版本信息："
swift --version
echo ""

# 运行演示程序
echo "🔄 运行演示程序..."
echo "================================================"

cd "$(dirname "$0")"

# 运行Swift文件
swift 阻塞vs协作式挂起演示.swift

echo ""
echo "================================================"
echo "✅ 演示完成！"
echo ""
echo "📚 关键学习要点："
echo "1. Thread.sleep 会阻塞物理线程，严重影响并发性能"
echo "2. Task.sleep 使用协作式挂起，释放线程给其他任务"
echo "3. Swift并发的核心是协作式调度，避免阻塞操作是关键"
echo "4. 在async函数中永远不要使用Thread.sleep或其他阻塞操作"
echo ""
echo "🔗 相关文档："
echo "- Swift并发机制完整指南.md"
echo "- 阻塞vs协作式挂起演示.swift"