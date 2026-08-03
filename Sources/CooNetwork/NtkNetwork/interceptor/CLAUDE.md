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

executor 在请求修改器结束后生成一次请求 key，解析有效超时，再创建结构化去重 key，并把三者写入同一只读 context。`NtkMutableRequest` 的公开写入方法已经同步维护字段及其规则，不需要冻结前补救清理。缓存与去重只能消费该结果。请求 key 构建失败时 context 不提供这两个 key，缓存与共享执行降级关闭而网络继续。
