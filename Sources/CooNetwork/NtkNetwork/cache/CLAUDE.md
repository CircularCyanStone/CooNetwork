# cache

缓存系统。

## 职责

提供网络请求的缓存解决方案。

## 核心类型

- `iNtkCacheStorage` - 缓存存储协议
- `NtkNetworkCache` - 缓存管理工具
- `NtkCacheMeta` - 缓存元数据
- `NtkRequestIdentity` - executor 生成并由缓存/去重共享的稳定身份
- `NtkCacheConfiguration` - 请求级缓存启用/时长策略
