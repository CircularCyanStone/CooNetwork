# Client

Alamofire 客户端实现。

## 职责

实现 `iNtkClient` 协议，提供基于 Alamofire 的网络请求能力。

## 核心类型

- `AFClient<Keys>` - Alamofire 客户端
- `iAFRequest` - Alamofire 请求协议
- `AFResponseMapKeys` - 响应映射键
- `AFDataParsingInterceptor` - 数据解析拦截器
- `AFResponseParsingInterceptor` - 响应解析拦截器
