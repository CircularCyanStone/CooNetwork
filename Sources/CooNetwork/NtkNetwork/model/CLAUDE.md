# model

数据模型层。

## 职责

定义网络请求和响应的数据结构。

## 核心类型

- `NtkMutableRequest` - 可修改的请求对象
- `NtkClientResponse` - 客户端原始响应
- `NtkResponse<T>` - 类型安全的响应包装
- `NtkDynamicData` - 动态数据类型
- `NtkReturnCode` - 返回码类型
- `NtkNever` - 无响应数据标记
- `NtkPayload` - 统一的响应 payload 中间层，承载严格 normalize 后的 `Data` 或动态结构
- `NtkResponseDecoder` - 泛型 JSON 解码器，依赖 `iNtkResponseMapKeys` 和 `NtkCodingKeys`
