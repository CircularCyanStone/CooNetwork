# model

数据模型层。

## 职责

定义网络请求和响应的数据结构。

## 核心类型

- `NtkMutableRequest` - 可修改的请求对象
- `NtkRequestIdentity` / `NtkRequestIdentityPolicy` - 稳定本地请求 key 与字段筛选策略
- `NtkRequestIdentityRule` - `.automatic`、`.include`、`.exclude` 字段写入规则
- `NtkClientResponse` - 客户端原始响应
- `NtkResponse<T>` - 类型安全的响应包装
- `NtkDynamicData` - 动态数据类型
- `NtkReturnCode` - 返回码类型
- `NtkNever` - 无响应数据标记
- `NtkResponseDecoder` - 泛型 JSON 解码器，依赖 `iNtkResponseMapKeys` 和 `NtkCodingKeys`

`NtkMutableRequest.headers` / `parameters` 对外只读，修改必须经过 `set`、`merge`、`remove` 系列方法，以同步维护真实请求和字段级 Request Identity 规则。`requestIdentityRule` 与 `setRequestIdentityValue` 只影响本地请求 key，不发送服务端；字段级 `.include`/`.exclude` 优先于策略中的转换闭包。排除凭证时必须保留 user/tenant 隔离，构建失败只禁用缓存与去重。
