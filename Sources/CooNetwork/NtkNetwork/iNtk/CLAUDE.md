# iNtk

核心接口层。

## 职责

定义网络抽象的协议接口。

## 核心协议

- `iNtkClient` - 网络客户端抽象
- `iNtkRequest` - 请求定义
- `iNtkResponse` - 响应抽象
- `iNtkInterceptor` - 普通拦截器接口；只能读取请求并控制请求/响应责任链
- `iNtkRequestModifyingInterceptor` - 明确参与请求构建阶段的 interceptor 能力协议
- `iNtkResponseMapKeys` - 响应键映射协议（定义在 model/NtkResponseDecoder.swift，因与 NtkResponseDecoder 强绑定）
- `iNtkResponseParser` - 响应解析器（框架通过 `NtkResponseParserBox` 包装为 `innerHigh` 拦截器）
- `iNtkCacheProvider` - 缓存能力提供者（拦截器遵循后 executor 可通过协议发现获取缓存读取能力）
