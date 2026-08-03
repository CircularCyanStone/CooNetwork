# deduplication

请求去重机制。

## 职责

防止相同请求重复执行。

## 核心类型

- `NtkDeduplicationInterceptor` - 去重拦截器
- `NtkDeduplicationKey` - 结构化执行键：请求 key、`ObjectIdentifier` 响应类型、有效超时和 namespace
- `NtkTaskManager` - actor 状态所有者，维护运行任务与 `instanceIdentifier` 反向索引；不构建请求 key

去重 key 不可用时降级为独立执行；取消和活跃查询只查反向索引，不从请求重新推导 key。
