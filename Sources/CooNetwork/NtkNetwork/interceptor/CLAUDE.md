# interceptor

拦截器基础设施。

## 职责

提供拦截器链的管理和执行机制。

## 核心类型

- `NtkInterceptorChainManager` - 拦截器链管理器
- `NtkInterceptorContext` - 请求上下文
- `iNtkRequestHandler` - 请求处理器协议实现
- `NtkCacheInterceptor` - 缓存拦截器，同时遵循 `iNtkCacheProvider`，优先级为 `innerLow`
