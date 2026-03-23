# AlamofireClient

Alamofire 集成实现。

## 职责

提供基于 Alamofire 的网络客户端实现。

## 依赖

- Alamofire 5.10.0+
- CooNetwork

## 核心类型

- `AFClient` - Alamofire 客户端（实现 `iNtkClient`）
- `NtkAF<T>` - 便捷类型别名（等同于 `Ntk<T>`）
- `NtkAFBool` - Bool 响应类型别名
- `AFDefaultResponseValidation` - 默认响应验证（code == 0 或 "0" 视为成功）
- `iAFRequest` - AF 请求协议，扩展 `iNtkRequest`，含 `encoding`、`requestModifier`、`validation` 等
- `iAFUploadRequest` - 上传请求协议，含 `AFUploadSource`（data / fileURL / multipart）

## 子模块

- `Client/` - 客户端实现（AFClient、AFResponseMapKeys、AFRequest、NtkDataParsingInterceptor）
- `Interceptor/` - AF 特定拦截器（AFToastInterceptor）
- `Error/` - AF 错误处理（AFClientError）
