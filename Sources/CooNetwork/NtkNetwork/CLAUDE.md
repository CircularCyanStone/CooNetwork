# NtkNetwork

CooNetwork 核心模块。

## 结构

目录结构详见根 CLAUDE.md。

## 职责

提供网络请求管理的核心抽象，包括配置层和执行层。

## 核心类型

- `NtkNetwork` - 请求管理器（配置层）
- `NtkNetworkExecutor` - 请求执行器（执行层）
- `Ntk` - 便捷入口点

## 子模块

- `iNtk/` - 核心协议定义
- `model/` - 数据模型
- `interceptor/` - 拦截器基础设施
- `cache/` - 缓存系统
- `retry/` - 重试机制
- `deduplication/` - 去重机制
- `UI/` - UI 相关拦截器
- `lock/` - 并发锁
- `utils/` - 工具类
