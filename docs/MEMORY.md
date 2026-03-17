# CooNetwork Memory

## 代码精简分析记录

### 分析日期
2026-03-17

---

## 高优先级问题（待讨论）

### 1. Ntk 类 @NtkActor 多余
- **文件**: `Ntk.swift`
- **问题**: `@NtkActor` 修饰是早期版本遗留，现在 `NtkNetwork` 使用锁保证线程安全
- **改进**: 删除 `@NtkActor`
- **状态**: 已确认，待修改

### 2. 缓存机制无用
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: `cacheMap` 缓存 key→key 映射，没有实际价值
- **状态**: 待讨论

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

### 6. 哈希计算逻辑重复
- **文件**: `NtkRequestIdentifierManager.swift`
- **问题**: `generateHashForCache` 和 `generateHashForDeduplication` 90% 代码重复
- **状态**: 待讨论

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
