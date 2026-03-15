# 子目录 CLAUDE.md 总结

## 创建时间

2026-03-15

## 设计原则

子目录 CLAUDE.md 采用极简设计：
- 只描述职责（1-2 行）
- 列出核心类型/协议
- 不包含使用示例
- 不包含设计特点详细描述
- 不包含具体实现细节

**理由：** 大部分信息模型可以通过代码探索获得，文档记录越多，维护成本越高。

## 模块职责矩阵

| 模块 | 职责 | 核心类型 |
|-------|--------|----------|
| **NtkNetwork** | 提供网络请求管理的核心抽象 | NtkNetwork, NtkNetworkExecutor, Ntk |
| **iNtk** | 定义网络抽象的协议接口 | iNtkClient, iNtkRequest, iNtkResponse, iNtkInterceptor, iNtkResponseValidation, iNtkResponseMapKeys |
|**model** | 定义网络请求和响应的数据结构 | NtkMutableRequest, NtkClientResponse, NtkResponse<T>, NtkDynamicData, NtkReturnCode, NtkNever |
| **interceptor** | 提供拦截器链的管理和执行机制 | NtkInterceptorChainManager, NtkInterceptorContext, NtkRequestHandler |
| **cache** | 提供网络请求的缓存解决方案 | iNtkCacheStorage, NtkNetworkCache, NtkCacheMeta, NtkRequestIdentifierManager, NtkRequestConfiguration |
| **retry** | 提供网络请求的自动重试功能 | NtkRetryInterceptor |
| **deduplication** | 防止相同请求重复执行 | NtkDeduplicationInterceptor |
| **UI** | 提供与 UI 集成的 Loading 状态管理 | NtkLoadingInterceptor |
| **lock** | 提供 Swift Concurrency 兼容的锁实现 | NtkUnfairLock |
| **utils** | 提供通用工具函数和扩展 | - |
| **error** | 定义网络请求和缓存的错误类型 | NtkError |
| **AlamofireClient** | 提供 Alamofire 集成 | AFClient<Keys>, NtkAF<T>, NtkAFBool |
| **Client (AF)** | 实现 iNtkClient 协议 | AFClient<Keys>, iAFRequest, AFResponseMapKeys, AFDataParsingInterceptor, AFJsonObjectParsingInterceptor |
| **Interceptor (AF)** | 提供与 Alamofire 集成的拦截器 | AFToastInterceptor |
| **Error (AF)** | 处理 Alamofire 错误 | AFClientError |

## 维护说明

1. **类型列表同步** - 新增类型时需更新对应模块的 CLAUDE.md
2. **职责描述** - 保持简洁，只描述高层目的
3. **不追踪变化** - 类型内部的变化不需要更新文档
4. **按需探索** - 细节信息模型通过代码探索获得

## 与根目录 CLAUDE.md 的关系

```
根 CLAUDE.md (启动时加载）
  ├── 项目概览
  ├── 快速开始命令
  └── 导航链接

子目录 CLAUDE.md (按需加载）
  ├── 模块职责（极简）
  └── 核心类型列表

docs/architecture.md
  ├── 架构设计决策
  └── 详细的技术说明
```

## 文档分层价值

| 层级 | 内容 | 受众 | 加载时机 |
|-------|------|-------|----------|
| 根 CLAUDE.md | 快速启动信息 | 启动时 |
| 子目录 CLAUDE.md | 模块快速导航 | 进入目录时 |
| docs/architecture.md | 架构设计决策 | 手动查阅 |
| 代码文件 | 完整实现细节 | 按需探索 |
