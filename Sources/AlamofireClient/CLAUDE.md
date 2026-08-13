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
- `NtkAFConfiguration<T>` - Alamofire 请求组装配置（client、解析策略和缓存）
- `NtkAFParsingStrategy<T>` - 标准解析流水线或完整自定义 parser
- `AFDefaultResponseValidation` - 默认响应验证（code == 0 或 "0" 视为成功）
- `iAFRequest` - AF 请求协议，扩展 `iNtkRequest`，含 `encoding`、`requestModifier`、`validation` 等
- `iAFUploadRequest` - 上传请求协议，含 `AFUploadSource`（data / fileURL / multipart）

## 子模块

- `Ntk+AF.swift` - 兼容入口、长期入口 `alamofire` 和默认响应验证
- `NtkAFConfiguration.swift` - typed client、解析策略和缓存组装配置
- `Client/` - 客户端实现（AFClient、AFResponseMapKeys、AFRequest）
- `Interceptor/` - AF 特定拦截器（AFToastInterceptor）
- `Error/` - AF 错误处理（AFClientError）
