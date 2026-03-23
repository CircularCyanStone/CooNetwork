# Client

Alamofire 客户端实现。

## 职责

实现 `iNtkClient` 协议，提供基于 Alamofire 的网络请求能力。

## 核心类型

- `AFClient` - Alamofire 客户端，实现 `iNtkClient`
- `iAFRequest` - Alamofire 请求协议，扩展 `iNtkRequest`
- `iAFUploadRequest` - 上传请求协议，含 `AFUploadSource`
- `AFResponseMapKeys` - 默认响应字段映射键（code / data / msg）
- `AFDefaultResponseValidation` - 默认响应验证（code == 0 或 "0"）

> `NtkDataParsingInterceptor` 已移至 `CooNetwork/NtkNetwork/interceptor/`，作为通用模块提供。
