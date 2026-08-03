# cache

缓存系统。

## 职责

提供网络请求的缓存解决方案。

## 核心类型

- `iNtkCacheStorage` - 缓存存储协议
- `NtkNetworkCache` - 缓存管理工具
- `NtkCacheMeta` - 缓存元数据
- `NtkRequestIdentity` - executor 已生成的稳定、不透明身份，缓存直接消费而不重新计算
- `NtkCacheConfiguration` - 请求级缓存启用/时长策略

缓存不负责字段过滤或身份生成：`NtkRequestIdentityPolicy` 与字段 participation 属于 identity 模块。身份不可用或缓存配置无效时跳过缓存，网络继续。
