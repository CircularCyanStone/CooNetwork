# NtkNetwork

CooNetwork 核心模块。

## 结构

目录结构详见根 CLAUDE.md。

## 职责

提供网络请求管理的核心抽象，包括配置层和执行层。

## 核心类型

- `NtkNetwork` - 请求管理器（配置层，`@unchecked Sendable`）
- `NtkNetworkExecutor` - 请求执行器（执行层，不可变 `Sendable` 执行快照）
- `NtkRequestIdentityBuilder` - 无状态、确定性的请求 key 构建器；修改器完成后由 executor 生成一次，缓存与去重共同消费
- `NtkTaskManager` - 独立 actor，仅管理运行任务、取消和实例反向索引
- `Ntk` - 便捷入口点

`NtkCacheConfiguration` 只控制缓存策略；`NtkRequestIdentityPolicy` 控制哪些字段写入本地请求 key。请求级非空策略完整覆盖全局策略，字段级 `.include`/`.exclude` 覆盖策略。请求 key 构建失败只关闭缓存和去重，网络继续；排除凭证必须通过 `setRequestIdentityValue` 加入不发送服务端的 user/tenant 值来保持隔离。

## 子模块

- `iNtk/` - 核心通用协议定义（如 `iNtkClient`、`iNtkRequest`、`iNtkResponse`、`iNtkInterceptor`、`iNtkResponseParser`、`iNtkCacheProvider`）
- `parsing/` - 响应解析子模块（payload normalize / transformer / decoder / hooks / validation / policy / parser）
- `model/` - 通用数据模型
- `interceptor/` - 拦截器基础设施（含链管理、上下文、缓存拦截器）
- `cache/` - 缓存系统
- `requestIdentity/` - 请求 key 的字段规则、策略、稳定编码和构建逻辑
- `retry/` - 重试机制
- `deduplication/` - 去重机制
- `UI/` - UI 相关拦截器
- `lock/` - 并发锁
- `utils/` - 工具类
