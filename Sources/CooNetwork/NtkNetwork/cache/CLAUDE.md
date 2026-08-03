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
