# Request Identity 命名修订设计

## 背景

`RequestKey` 容易被理解为请求参数、Header 或 payload 中会发送到服务端的字段 key。实际类型代表的是请求修改完成后，由 method、URL、筛选后的字段和本地附加值共同形成的稳定资源身份；它只在客户端用于缓存索引和请求去重。

`RequestId` 不采用：`Id` 通常表示单次执行唯一的请求号、trace ID 或幂等性 ID，而本模块必须让等价请求产生相同值。

## 命名决策

公开与内部的领域概念统一使用 `RequestIdentity`：

| 当前名称 | 修订名称 |
| --- | --- |
| `requestKey/` | `requestIdentity/` |
| `NtkRequestKey` | `NtkRequestIdentity` |
| `NtkRequestKeyBuilder` | `NtkRequestIdentityBuilder` |
| `NtkRequestKeyEncoder` | `NtkRequestIdentityEncoder` |
| `NtkRequestKeyPolicy` | `NtkRequestIdentityPolicy` |
| `NtkRequestKeyRule` | `NtkRequestIdentityRule` |
| `requestKey` | `requestIdentity` |
| `requestKeyRule` | `requestIdentityRule` |
| `requestKeyValues` | `requestIdentityValues` |
| `setRequestKeyValue` | `setRequestIdentityValue` |
| `removeRequestKeyValue` | `removeRequestIdentityValue` |

`NtkDeduplicationKey` 保留不变。它是任务管理器中用于查表的复合键，名称描述的是数据结构职责；其中的 `requestIdentity` 字段只代表资源身份。缓存 storage 的 `key:` 参数也保留，它是通用存储接口的索引参数，而非请求模型字段。

## 行为与兼容性

本次仅修改命名、目录、注释、测试和文档，不改变字段筛选、稳定编码、SHA-256 结果、缓存命中、去重边界、超时或失败降级行为。持久化字符串继续保留 `ntk-identity-v2-` 前缀，以命中既有缓存；它与 Swift API 命名一致，无需迁移。

不保留 `RequestKey` 的 deprecated/typealias 兼容层，以避免新 API 的自动补全继续暴露易混淆的词汇。

## 验收标准

- 源码、测试、README 和架构文档统一采用 `RequestIdentity`。
- `RequestKey` 仅可出现在泛化存储索引语境或历史说明中；不存在请求身份 API。
- `NtkDeduplicationKey` 仍以 `NtkRequestIdentity` 作为其资源身份组成部分。
- 重命名前后对同一输入生成的持久化字符串完全一致。
