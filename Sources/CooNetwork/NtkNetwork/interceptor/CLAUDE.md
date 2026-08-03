# interceptor

拦截器基础设施。

## 职责

提供拦截器链的管理和执行机制。

链管理器和上下文是普通 `Sendable` 值流，不绑定全局 actor；共享可变状态由具体拦截器或状态所有者自行隔离。

## 核心类型

- `NtkInterceptorChainManager` - 拦截器链管理器
- `NtkInterceptorContext` - 请求上下文
- `iNtkRequestHandler` - 请求处理器协议实现
- `NtkCacheInterceptor` - 缓存拦截器，同时遵循 `iNtkCacheProvider`，优先级为 `innerLow`

executor 在请求修改器结束并 prune 后冻结一次身份、有效超时和结构化去重键，再写入同一只读 context；缓存与去重只能消费该结果。身份构建失败时 context 不提供身份，缓存/共享执行降级关闭而网络继续。
