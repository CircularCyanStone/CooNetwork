# CooNetwork 代码评审修复计划

## 背景

本次修复计划基于 CooNetwork 项目的全面代码评审结果，解决评审中发现的 HIGH 和 MEDIUM 优先级问题。综合评分 7.5/10，主要改进方向为测试覆盖率、类型安全、内存泄漏和代码质量。

---

## 问题总览

### HIGH 优先级问题 (4 项)

| 问题 | 影响 | 文件 |
|------|------|------|
| 测试覆盖率严重不足 | 质量保证 | Tests/ |
| NtkTaskManager 内存泄漏 | 应用稳定性 | NtkTaskManager.swift |
| NtkCacheMeta 类型转换不安全 | 并发安全 | NtkCacheMeta.swift |
| Actor 隔离域使用不当 | 并发安全 | NtkNetwork.swift |

### MEDIUM 优先级问题 (4 项)

| 问题 | 影响 | 文件 |
|------|------|------|
| 拼写错误 `RetureData` | API 规范 | AFRequest.swift, AFJsonObjectParsingInterceptor.swift |
| 日志记录不统一 | 可维护性 | 多个文件 |
| 错误信息可能包含敏感数据 | 安全性 | AFClient.swift |
| @preconcurrency 暗示兼容性问题 | 未来兼容性 | AFClient.swift |

---

## 修复阶段

### 阶段一：低风险快速修复

#### 1.1 修复拼写错误 `RetureData` → `ReturnData`

**问题描述：** 公共 API 方法名存在拼写错误，共 9 处。

**受影响文件：**
- `Sources/AlamofireClient/Client/AFRequest.swift` (6 处)
- `Sources/AlamofireClient/Client/AFJsonObjectParsingInterceptor.swift` (3 处)

**修复方案：**
- 将所有 `unwrapRetureData` 改为 `unwrapReturnData`
- 将所有 `enableCustomRetureDataDecode` 改为 `enableCustomReturnDataDecode`
- 将所有 `customRetureDataDecode` 改为 `customReturnDataDecode`

**风险评估：** 低 - 纯粹重命名，功能不变

**验证方法：** 编译检查 + 运行现有测试

---

#### 1.2 统一日志系统

**问题描述：** 混用 `print()` 和 `NtkLogger`，导致日志不可控。

**受影响文件：**
- `Sources/AlamofireClient/Client/AFDataParsingInterceptor.swift`
- `Sources/AlamofireClient/Client/AFJsonObjectParsingInterceptor.swift`
- `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift`
- `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`

**修复方案：**
- 替换所有 `print()` 为 `NtkLogger.shared.debug/info/warning/error`
- 移除 `#if DEBUG` 条件编译，使用运行时开关 `NtkConfiguration.shared.isLoggingEnabled`
- 添加正确的日志分类（.network, .interceptor, .retry, .cache）

**风险评估：** 低 - NtkLogger 已成熟实现

**验证方法：** 验证日志开关控制输出

---

### 阶段二：中风险核心修复

#### 2.1 修复 NtkTaskManager 内存泄漏 ✅

**问题描述：** 使用静态字典存储 Task，当外部取消请求时，最后的 catch 分支未移除 Task，导致内存泄漏。

**受影响文件：**
- `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`
- `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift` (调用方)
- `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift` (调用方)

**已完成修复：**

**第一轮修复 (commit acfc059):**
- 在缺失的 catch 分支补充 `removeValue` 调用
- 快速解决 CancellationError 时的内存泄漏

**第二轮优化 (commit 45ae23d):**
- 改用单例 Actor 模式（`static let shared = NtkTaskManager()`）
- 使用 `defer` 确保所有退出路径都清理
- 移除多个手动 `removeValue` 调用，统一由 defer 处理
- 更新调用方使用 `NtkTaskManager.shared`

**风险评估：** 已完成 - 编译通过，测试通过

**验证结果：**
- ✅ 编译通过
- ✅ 所有现有测试通过 (6 tests)
- ✅ defer 确保任何退出路径都清理

---

#### 2.2 修复 NtkCacheMeta 类型安全

**问题描述：** 类型转换不安全，`[String: Sendable]` 可能包含意外类型。

**受影响文件：**
- `Sources/CooNetwork/NtkNetwork/cache/NtkCacheMeta.swift`

**修复方案：**
1. 添加 `NtkCacheDataType` 枚举标识数据类型
2. 在 `init` 中自动检测并保存数据类型
3. 在 `init?(coder:)` 中根据类型安全解码
4. 添加类型安全访问方法（`asDictionary()`, `asArray()` 等）

**风险评估：** 中等 - 添加新字段，需处理向后兼容

**验证方法：**
- 类型安全测试：验证类型验证逻辑
- 序列化测试：验证编解码一致性

---

### 阶段三：并发安全修复

#### 3.1 优化 NtkNetwork Actor 隔离

**问题描述：** 使用 `@unchecked Sendable` 和内部锁，违反 Swift 6 Actor 隔离原则。

**受影响文件：**
- `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`

**修复方案：**
1. 移除内部锁（`NtkUnfairLock`）
2. 将配置改为不可变值类型
3. 所有配置方法返回新实例（不可变模式）
4. 实际执行委托给 `NtkNetworkExecutor` (Actor)

**风险评估：** 中等 - 改变 API 语义（链式调用返回新实例）

**验证方法：**
- 并发测试：多线程同时配置
- 单元测试：验证不可变性
- 集成测试：完整请求流程

---

### 阶段四：测试覆盖率提升

#### 4.1 补充单元测试

**目标覆盖率：** 80%+

**需要添加的测试文件：**

1. **NtkTaskManagerTests.swift** (新建)
   - 去重功能测试
   - 并发请求测试
   - 内存泄漏测试
   - 取消功能测试

2. **NtkNetworkTests.swift** (增强)
   - 并发配置测试
   - 不可变性测试
   - 拦截器链测试

3. **AFClientTests.swift** (新建)
   - Alamofire 集成测试
   - 参数编码测试
   - 响应解析测试

4. **NtkLoggerTests.swift** (新建)
   - 日志开关测试
   - 日志级别测试

---

## 关键文件清单

### 需要修改的文件

| 文件 | 修改类型 | 阶段 |
|------|---------|------|
| AFRequest.swift | 重命名 | 1.1 |
| AFJsonObjectParsingInterceptor.swift | 重命名 | 1.1 |
| AFDataParsingInterceptor.swift | 日志统一 | 1.2 |
| NtkRetryInterceptor.swift | 日志统一 | 1.2 |
| NtkNetwork.swift | 日志统一 + Actor 优化 | 1.2, 3.1 |
| NtkTaskManager.swift | 架构重构 | 2.1 |
| NtkDeduplicationInterceptor.swift | 调用方更新 | 2.1 |
| NtkNetworkExecutor.swift | 调用方更新 | 2.1 |
| NtkCacheMeta.swift | 类型安全增强 | 2.2 |

### 需要新建的测试文件

- Tests/CooNetworkTests/NtkTaskManagerTests.swift
- Tests/CooNetworkTests/AFClientTests.swift
- Tests/CooNetworkTests/NtkLoggerTests.swift

---

## 执行顺序

1. **阶段一** - 快速修复拼写和日志（低风险，快速见效）
2. **阶段二** - 修复内存泄漏和类型安全（核心问题）
3. **阶段三** - 优化 Actor 隔离（并发安全）
4. **阶段四** - 提升测试覆盖率（质量保证）

---

## 验证计划

### 编译验证
```bash
swift build
```

### 测试验证
```bash
swift test
```

### 覆盖率检查
```bash
swift test --enable-code-coverage
```

### 手动验证
- 发送网络请求验证功能正常
- 检查日志输出格式正确性
- 验证去重功能
- 验证缓存功能
- 验证取消功能

---

## 风险缓解

### 向后兼容性
- 拼写修复：考虑添加 `@available(*, deprecated, renamed: "...")` 标记
- 架构变更：提供迁移指南

### 破坏性变更
- 阶段三的不可变模式会改变 API 语义
- 需要更新所有现有代码

### 测试策略
- 每个阶段完成后运行完整测试套件
- 使用 Git 分支隔离开发
- 逐阶段合并，降低风险

---

## 成功标准

- [ ] 所有拼写错误修复
- [ ] 日志系统完全统一
- [x] 内存泄漏问题解决 (2.1)
- [ ] 类型安全增强完成
- [ ] Actor 隔离优化完成
- [ ] 测试覆盖率达到 80%+
- [x] 所有现有测试通过
- [ ] 无编译警告
