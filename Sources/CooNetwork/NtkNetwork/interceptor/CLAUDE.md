# interceptor

拦截器基础设施。

## 职责

提供拦截器链的管理和执行机制。

## 核心类型

- `NtkInterceptorChainManager` - 拦截器链管理器
- `NtkInterceptorContext` - 请求上下文
- `iNtkRequestHandler` - 请求处理器协议实现
- `NtkDataParsingInterceptor` - 通用响应解析拦截器，实现 `iNtkResponseParser`，支持多数据源（通过 `iNtkDecoderBuilding` 适配）
- `NtkCacheInterceptor` - 缓存拦截器，同时遵循 `iNtkCacheProvider`，优先级为 `innerLow`
- `NtkDecoderBuilders` - `NtkDataDecoderBuilder`（Data 源）和 `NtkJsonObjectDecoderBuilder`（字典源）的内置适配实现
