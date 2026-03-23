# Client

Alamofire 客户端实现。

## 职责

实现 `iNtkClient` 协议，提供基于 Alamofire 的网络请求能力。

## 核心类型

- `AFClient<Keys>` - Alamofire 客户端
- `iAFRequest` - Alamofire 请求协议
- `AFResponseMapKeys` - 响应映射键
- `NtkDataParsingInterceptor` - 通用响应解析拦截器（支持 Data / JsonObject 等多种数据源）
