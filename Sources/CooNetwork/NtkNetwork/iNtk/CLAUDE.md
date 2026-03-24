# iNtk

核心接口层。

## 职责

定义网络抽象的协议接口。

## 核心协议

- `iNtkClient` - 网络客户端抽象
- `iNtkRequest` - 请求定义
- `iNtkResponse` - 响应抽象
- `iNtkInterceptor` - 拦截器接口（含 `NtkInterceptorPriority` 三层 Tier 优先级）
- `iNtkResponseValidation` - 响应验证
- `iNtkResponseMapKeys` - 响应键映射协议（定义在 model/NtkResponseDecoder.swift，因与 NtkResponseDecoder 强绑定）
- `iNtkResponseParser` - 响应解析器（框架通过 `NtkResponseParserBox` 包装为 `innerHigh` 拦截器）
- `iNtkResponsePayloadTransforming` - 前置 payload 改造协议（解密、解包、归一化等）
- `iNtkResponsePayloadDecoding` - payload 解释协议（`NtkPayload` → `NtkResponseDecoder`，并负责 `extractHeader`）
- `iNtkParsingHooks` - 解析生命周期钩子（`didDecodeHeader` / `willValidate` / `didValidateFail` / `didComplete`）
- `iNtkCacheProvider` - 缓存能力提供者（拦截器遵循后 executor 可通过协议发现获取缓存读取能力）
