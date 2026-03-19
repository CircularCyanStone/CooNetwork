# Code Review 报告

**日期**: 2026-03-19
**范围**: develop 分支相对 main 的全部变更（70 个文件，+7561 / -1362）
**审查人**: AI Code Reviewer
**状态**: 待修复

---

## Strengths

1. **双层架构设计清晰** — NtkNetwork (Builder/配置层) + NtkNetworkExecutor (Actor/执行层) 的分离合理，既支持链式调用又保证并发安全。

2. **去重取消隔离设计精巧** — `NtkTaskManager` 的 owner/follower 模型通过独立 wrapper Task 实现取消隔离，引用计数归零才取消底层 Task，逻辑严密。

3. **NtkReturnCode/NtkDynamicData 重构到 Storage enum** — 类型标记与值绑定在一起，消除了之前 `_type` + `rawValue` 分离可能的不一致风险。

4. **测试质量高** — `NtkTaskManagerTests` 使用 `TaskExecutionGate` + `ExecutionCounter` 精确控制并发时序，覆盖了 owner 取消、follower 取消、全部取消、取消后重入等关键场景。

5. **NtkCancellableState 引用类型解决值类型共享状态** — 设计简洁，锁保护正确。

6. **LRU 缓存用于 NtkRequestIdentifierManager** — 基于设备内存分段设置容量上限，避免无限增长。

---

## Issues

### Critical (Must Fix)

#### C-1: NtkRetryInterceptor 重试循环 off-by-one

- **文件**: `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift:38`
- **问题**: `while attemptCount < retryPolicy.maxRetryCount`，`maxRetryCount = 3` 时总共执行 3 次（首次 + 2 次重试）。如果 `maxRetryCount` 语义是"最大重试次数"（不含首次），则少执行了一次；如果语义是"最大执行次数"（含首次），则命名有误导。
- **影响**: `maxRetryCount = 1` 时不会重试，只执行一次。
- **修复方向**: 明确语义后调整循环条件或重命名。
- **状态**: ✅ 已修复（首次执行与重试循环分离，补充 5 个测试用例）

#### C-2: `requestWithCache()` 缺少单次使用保护

- **文件**: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift:241`
- **问题**: `requestWithCache()` 内部调用了 `self.request()`（有 `markRequestConsumedOrThrow` 保护），但 `requestWithCache()` 自身入口没有调用该保护。用户可以多次调用 `requestWithCache()`，第二次的 `request()` 会失败但 `loadCache()` 不受保护，行为不一致。
- **影响**: 违反 NtkNetwork 单次使用的设计契约。
- **修复方向**: 在 `requestWithCache()` 入口也调用 `markRequestConsumedOrThrow()`。
- **状态**: ✅ 已修复（入口添加 markRequestConsumedOrThrow，内部改用 executeRequest 避免重复检查）

---

### Important (Should Fix)

#### I-1: NtkLogger.shared 初始化时固化配置，后续 `configure()` 不生效

- **文件**: `Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift:20-25`
- **问题**: `shared` 是 `static let`，首次访问时读取 `NtkConfiguration.current.builder.isLoggingEnabled` 并固化。如果用户在 app 启动后才调用 `NtkConfiguration.configure { $0.isLoggingEnabled = true }`，logger 仍然是关闭状态。
- **影响**: 用户困惑"为什么开了日志没输出"。
- **修复方向**: 让 `isLoggingEnabled` 动态读取 `NtkConfiguration.current.builder.isLoggingEnabled`。
- **状态**: ✅ 已修复（isLoggingEnabled 改为 computed property 动态读取）

#### I-2: `NtkConfiguration.current` 读取未加锁

- **文件**: `Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift:33`
- **问题**: `configure()` 用 `lock` 保护写入，但所有读取 `NtkConfiguration.current.builder.xxx` 的地方都没有加锁。`Builder` 是 struct，读取时如果另一个线程正在写入，可能读到半更新的状态。
- **影响**: Swift 6 严格并发模型下的数据竞争。
- **修复方向**: 将读取也用 `lock` 保护，或改为不可变快照模式（`configure()` 生成新的 frozen Builder，原子替换）。
- **状态**: ✅ 已修复（不可变快照模式：current 改为加锁读取，builder 改为 let，configure 原子替换）

#### I-3: NtkDeduplicationInterceptor 闭包中的 actor 隔离确认

- **文件**: `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationInterceptor.swift:13-14`
- **问题**: execution 闭包捕获了 `context`（`@NtkActor` 隔离的 class），在 `NtkTaskManager.executeWithDeduplication` 内部通过 `Task<Sendable, Error>` 执行。需要确认该 Task 是否继承了 `@NtkActor` 隔离域。
- **影响**: 如果未继承隔离域，可能违反 actor 隔离。
- **修复方向**: 确认 `NtkTaskManager`（`@NtkActor`）方法内创建的 `Task` 是否自动继承隔离域；如果不确定，显式标注 `@NtkActor`。
- **状态**: ✅ 已确认无需修改（execution 闭包经 TaskGroup.addTask 执行，不继承 actor 隔离，但 next.handle() 本身是 @NtkActor 隔离的，Swift 自动 hop 回 actor；context 是 Sendable，跨隔离域安全）

#### I-4: `onTermination` 中 `@unknown default: fatalError` 会在未来 Swift 版本崩溃

- **文件**: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift:297`
- **问题**: `AsyncThrowingStream.Termination` 如果新增 case，生产环境直接 crash。
- **影响**: 未来 Swift 版本升级时的兼容性风险。
- **修复方向**: 改为 `break` 或 log warning。
- **状态**: ✅ 已修复（fatalError 改为 break）

---

### Minor (Nice to Have)

#### M-1: NtkDeduplicationConst.swift 文件头注释错误

- **文件**: `Sources/CooNetwork/NtkNetwork/deduplication/NtkDeduplicationConst.swift:1`
- **问题**: 文件头注释是 `// File.swift`，应更新为实际文件名。
- **状态**: ✅ 已修复

#### M-2: NtkNetworkExecutor catch 链冗余

- **文件**: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift:79-83`, `:110-114`
- **问题**: `catch let error as NtkError { throw error } catch { throw error }` 两个分支做的事情完全一样，可简化为单个 `catch`。
- **状态**: ✅ 已修复

#### M-3: `getRequestIdentifier` 没有使用 LRU 缓存

- **文件**: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestIdentifierManager.swift:188-191`
- **问题**: `getCacheKey` 有 LRU 缓存，但 `getRequestIdentifier`（用于去重）每次重新计算 hash。`Hasher` 本身很快，优先级不高。
- **状态**: ⬜ 跳过（Hasher 本身足够快，加缓存收益不大）: 测试中使用 `Task.sleep` 等待 follower 进入等待状态

- **文件**: `Tests/CooNetworkTests/NtkTaskManagerTests.swift:352,368,436` 等
- **问题**: `Task.sleep(nanoseconds: 50_000_000)` 是时间依赖的等待，CI 慢机器上可能不稳定。
- **修复方向**: 用类似 `TaskExecutionGate` 的机制替代。
- **状态**: ⬜ 跳过（需侵入生产代码添加测试钩子，收益不大）

---

## 修复优先级

| 优先级 | 编号 | 摘要 |
|--------|------|------|
| 🔴 P0 | C-1 | 重试循环 off-by-one |
| 🔴 P0 | C-2 | requestWithCache 单次使用保护 |
| 🟡 P1 | I-1 | Logger 配置不生效 — ✅ 已修复 |
| 🟡 P1 | I-2 | NtkConfiguration 读写竞争 — ✅ 已修复（不可变快照模式） |
| 🟡 P1 | I-3 | 去重拦截器 actor 隔离确认 — ✅ 已确认无需修改 |
| 🟡 P1 | I-4 | onTermination fatalError — ✅ 已修复 |
| 🟢 P2 | M-1 | 文件头注释错误 — ✅ 已修复 |
| 🟢 P2 | M-2 | catch 链冗余 — ✅ 已修复 |
| 🟢 P2 | M-3 | getRequestIdentifier 缓存 — ⬜ 跳过（Hasher 足够快） |
| 🟢 P2 | M-4 | 测试 Task.sleep — ⬜ 跳过（无法不污染生产代码） |

---

## 总体评估

**Ready to merge?** Yes

所有 Critical 和 Important 问题已修复或确认。M-3、M-4 为低优先级可选优化，已跳过。
