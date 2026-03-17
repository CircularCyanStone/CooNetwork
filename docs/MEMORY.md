# CooNetwork Memory

## 代码精简分析记录

### 分析日期
2026-03-17

---

## 高优先级问题

### 1. NtkRequestIdentifierManager 改为 @NtkActor
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: 使用 `@unchecked Sendable` 是历史遗留，应改用 `@NtkActor`
- **改进**: 删除 `@unchecked Sendable`，改用 `@NtkActor`
`- **状态**: ✅ 已完成 (2026-03-17)

### 2. 缓存机制优化
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: 原 `cacheMap` 缓存 key→key 映射，没有实际价值
- **改进**: 实现 RequestCacheKey 方案，缓存 请求特征 → 缓存键
- **性能测试结果**:
  - 10000 次调用: 性能提升 98.81%
  - 100000 次调用: 性能提升 93.71%
- **状态**: ✅ 已完成 (2026-03-17)

### 3. LRU 缓存策略修复
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: 使用 `Dictionary.keys.first` 无法保证获取最老条目（Dictionary 无序）
- **改进**: 新增 `lruLRUQueue` 数组维护访问顺序，实现真正的 LRU
  - 缓存命中时将键移到队列末尾
  - 缓存满时删除队列第一个元素（最老的）
- **状态**: ✅ 已完成 (2026-03-17)

---

## 原始问题列表（已完成）

### ~~1. Ntk 类 @NtkActor 多余~~
- **文件**: `Ntk.swift`
- **问题**: `@NtkActor` 修饰是早期版本遗留，现在 `NtkNetwork` 使用锁保证线程安全
- **改进**: 删除 `@NtkActor`
- **状态**: ~~已确认，待修改~~

### ~~2. 缓存机制无用~~
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: `cacheMap` 缓存 key→key 映射，没有实际价值
- **状态**: ~~待讨论~~

### 3. 拦截器优先级系统过度设计
- **文件**: `iNtkInterceptor.swift`
- **问题**: 存在三套优先级表示方式（枚举、Int 扩展、结构体）
- **状态**: 待讨论

### 4. Executor 创建代码重复
- **文件**: `NtkNetwork.swift`
- **问题**: `request()`, `loadCache()`, `hasCacheData()` 重复创建 executor
- **状态**: 待讨论

### 5. 执行链构建代码重复
- **文件**: `NtkNetworkExecutor.swift`
- **问题**: 三个方法有重复的拦截器链构建逻辑
- **状态**: 待讨论

---

## 中优先级问题（待讨论）

### 4. 拦截器优先级系统过度设计
- **文件**: `iNtkInterceptor.swift`, `NtkRetryInterceptor.swift`
- **问题**: 存在三套优先级表示方式（枚举、Int 扩展、结构体）
- **改进**: 删除冗余的 `iNtkInterceptorPriority` 枚举和 `Int` 扩展，统一使用 `NtkInterceptorPriority`
  - 保留 `NtkInterceptorPriority` 结构体（类型安全，已用于协议）
  - 简化静态属性：`.low`, `.medium`, `.high`
  - 简化 `.priority(_:)` 工厂方法
  - 新增 `+` 和 `-` 运算符，支持 `.high + 1` 这种用法
- **状态**: ✅ 已完成 (2026-03-17)

### 5. Executor 创建代码重复
- **文件**: `NtkNetwork.swift`
- **问题**: `request()`, `loadCache()`, `hasCacheData()` 重复创建 executor
- **改进**: 提取私有方法 `makeExecutor<T>()` 统一创建逻辑
- **状态**: ✅ 已完成 (2026-03-17)

### ~~6. 执行链构建代码重复~~
- **文件**: `NtkNetworkExecutor.swift`
- **问题**: 三个方法有重复的拦截器链构建逻辑
- **评估**: 三个方法的拦截器组合策略和错误处理策略完全不同，只有排序逻辑重复，强行统一反而降低可读性
- **结论**: 接受现状
- **状态**: ~~待讨论~~

### 7. 哈希计算逻辑重复
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: `generateHashForCache` 和 `generateHashForDeduplication` 90% 代码重复
- **改进**: 提取公共逻辑到三个辅助方法：
  - `buildHashComponents()` - 构建哈希组件数组（用于缓存）
  - `appendFilteredHeaders()` - 添加过滤后的 Headers 到 Hasher
  - `appendFilteredParameters()` - 添加过滤后的 Parameters 到 Hasher
- **保持逻辑一致性**:
  - 缓存哈希：使用参数传入的 `cacheConfig`，包含 `cacheTime`
  - 去重哈希：使用 `request.requestConfiguration`，不包含额外内容
- **状态**: ✅ 已完成 (2026-03-17)

### 7. 拦截器排序重复
- **文件**: `NtkNetwork.swift`, `NtkNetworkExecutor.swift`
- **问题**: 在两个地方都进行拦截器排序
- **状态**: 待讨论

### 8. 重试逻辑冗余检查
- **文件**: `NtkRetryInterceptor.swift`
- **问题**: 重试循环中有重复的检查逻辑
- **状态**: 待讨论

### 9. Switch 语句重复
- **文件**: `NtkReturnCode.swift`
- **问题**: 每个计算属性都重复相同的 switch 模式
- **状态**: 待讨论

### 10. 命名不一致
- **多文件**
- **问题**: `Ntk`/`iNtk` 前缀使用不统一
- **状态**: 待讨论

---

## 低优先级问题（待讨论）

### 11. NtkDynamicData 过度复杂
- **状态**: 待讨论

### 12. NtkCacheMeta 使用 NSCoding
- **状态**: 待讨论

### 13. @unchecked Sendable 过多
- **状态**: 待讨论

### 14. 文档不完整
- **状态**: 待讨论
