# interceptor

拦截器基础设施。

## 职责

提供拦截器链的管理和执行机制。

链管理器和上下文是普通 `Sendable` 值流，不绑定 `NtkActor`；共享可变状态由具体拦截器或状态所有者自行隔离。

## 核心类型

- `NtkInterceptorChainManager` - 拦截器链管理器
- `NtkInterceptorContext` - 请求上下文
- `iNtkRequestHandler` - 请求处理器协议实现
- `NtkCacheInterceptor` - 缓存拦截器，同时遵循 `iNtkCacheProvider`，优先级为 `innerLow`
