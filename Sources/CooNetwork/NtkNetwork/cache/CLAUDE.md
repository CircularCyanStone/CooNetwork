# cache

缓存系统。

## 职责

提供网络请求的缓存解决方案。

## 核心类型

- `iNtkCacheStorage` - 缓存存储协议
- `NtkNetworkCache` - 缓存管理工具
- `NtkCacheMeta` - 缓存元数据
- `NtkRequestIdentity` - executor 已生成的稳定、不透明请求 key，缓存直接消费而不重新计算
- `NtkCacheConfiguration` - 请求级缓存启用/时长策略

缓存不负责字段过滤或请求 key 生成：`NtkRequestIdentityPolicy` 与 `NtkRequestIdentityRule` 属于 `requestIdentity/` 模块。请求 key 不可用或缓存配置无效时跳过缓存，网络继续。

## 归档白名单

`NtkCacheMeta.allowedDataClasses` 是编解码共用的唯一类型定义，`canEncode(_:)` 与 `init?(coder:)` 都消费它。新增支持类型时改这一处即可，不要只改一侧。

可安全往返的类型：`String`、`Bool`、`Int`、`Double`、`Float`、`Data`、`NSNull`，以及由它们任意嵌套组成的 `[String: Sendable]` / `[Sendable]`。

`NSNull` 不可移除：后端 JSON 的 `null` 会以它进入响应字典，缺席时默认解档策略会静默丢失整个 `data`，`.raiseException` 策略下则抛 OC 异常终止进程。

`URL`、`Date`、自定义 Sendable 结构体能归档编码但不在白名单内，属于**不可往返**类型：`save` 与 `NtkCacheInterceptor` 都会在写入前拒绝，避免留下「写成功、读不出」的脏缓存。存储实现若自行解档，遇到白名单外类型时整个 `NtkCacheMeta` 会解档失败并返回 `nil`（而非 `data=nil` 的伪命中）。
