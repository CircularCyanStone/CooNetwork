# model

数据模型层。

## 职责

定义网络请求和响应的数据结构。

## 核心类型

- `NtkMutableRequest` - 可修改的请求对象
- `NtkRequestIdentity` / `NtkRequestIdentityPolicy` - 稳定本地身份与其字段投影规则
- `NtkIdentityParticipation` - `.automatic`、`.included`、`.excluded` 字段参与状态
- `NtkClientResponse` - 客户端原始响应
- `NtkResponse<T>` - 类型安全的响应包装
- `NtkDynamicData` - 动态数据类型
- `NtkReturnCode` - 返回码类型
- `NtkNever` - 无响应数据标记
- `NtkResponseDecoder` - 泛型 JSON 解码器，依赖 `iNtkResponseMapKeys` 和 `NtkCodingKeys`

`NtkMutableRequest` 的 identity 标记与 `addIdentityComponent` 只影响本地身份、不发送服务端；`.included`/`.excluded` 优先于 normalizer。排除凭证时必须保留 user/tenant 隔离，构建失败只禁用缓存与去重。
