# CooNetwork 待讨论事项

> 来源：2026-03-17 代码精简分析，已完成项已移除，仅保留待讨论项。

---

## 已完成

### 1. Switch 语句重复 ✅
- **文件**: `NtkReturnCode.swift`
- **解决**: 用 `enum Storage` with associated values 替换 `_type` + `rawValue`，消除强转和重复 switch

### 2. 命名不一致 ✅
- **结论**: `iNtk` = protocol（9个），`Ntk` = 具体类型（27个），是刻意的命名约定，无需修改

---

## 低优先级

### 3. NtkDynamicData 过度复杂 ✅
- **解决**: 用 `enum Storage` with associated values 重构，消除 `valueType` + `rawValue` 二元组合和所有 `as!` 强转

### 4. NtkCacheMeta 使用 NSCoding ✅
- **结论**: `NSSecureCoding` 在此场景合理，`data` 是 existential type 无法直接 Codable，且改动会破坏已有磁盘缓存，无需修改

### 5. @unchecked Sendable 过多 ✅
- **结论**: 仅 3 处（NtkUnfairLock、NtkNetwork、NtkCancellableState），均通过内部锁保证线程安全，每处都有必要，无需修改

### 6. 文档不完整 ✅
- **解决**: 补全了所有缺失的 public API 文档注释，涉及 NtkClientResponse、NtkInterceptorContext、iNtkRequestHandler、NtkConfiguration、Ntk、NtkLogger、NtkResponse、NtkNetwork+loading、AFNoCacheStorage、AFResponseMapKeys、AFToastInterceptor、AFJsonObjectParsingInterceptor、NtkDataParsingInterceptor、AFDetaultResponseValidation、重试策略等

---

## 测试覆盖（持续进行）

- 当前覆盖率约 20%，目标 80%+
- 已有测试：NtkCacheMeta、NtkTaskManager、NtkRequestIdentifierManager、NtkRetryInterceptor、NtkNetworkSingleUse
- 待添加：NtkNetworkCache、NtkInterceptorChainManager、AFClient 集成测试
