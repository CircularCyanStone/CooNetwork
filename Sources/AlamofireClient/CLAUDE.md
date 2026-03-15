# AlamofireClient

Alamofire 集成实现。

## 职责

提供基于 Alamofire 的网络客户端实现。

## 依赖

- Alamofire 5.10.0+
- CooNetwork

## 核心类型

- `AFClient<Keys>` - Alamofire 客户端
- `NtkAF<T>` - 便捷类型别名
- `NtkAFBool` - Bool 响应类型别名

## 子模块

- `Client/` - 客户端实现
- `Interceptor/` - AF 特定拦截器
- `Error/` - AF 错误处理
