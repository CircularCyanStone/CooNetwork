# CooNetwork 架构评审报告 (2026-03-20)

## 评审范围

对 CooNetwork 整体架构进行深度代码审查，重点评估扩展性——即作为统一网络抽象层，能否方便地对接新的网络后端并支持渐进式迁移。

---

## 优势

1. **双层架构设计精准** — 配置层(NtkNetwork)与执行层(NtkNetworkExecutor) 的分离解决了"链式调用需要同步 vs 执行需要并发隔离"的根本矛盾。
2. **拦截器链设计成熟** — `iNtkInterceptor` + `NtkInterceptorChainManager` 实现标准责任链模式，优先级系统支持算术运算，灵活度高。
3. **去重系统设计精密** — `NtkTaskManager` 的 owner/follower 模型、独立取消隔离、引用计数归零自动清理，是生产级实现。
4. **协议抽象层次恰当** — `iNtkClient` / `iNtkRequest` / `iNtkResponse` / `iNtkInterceptor` 四个核心协议构成完整的后端无关边界。
5. **并发模型严谨** — `@NtkActor` 自定义全局 Actor 收敛网络执行到统一隔离域，Swift 6 strict concurrency 全面兼容。
6. **缓存键管理有工程深度** — LRU 缓存避免重复哈希，容量根据设备物理内存动态调整，缓存键用 MD5，去重键用 Hasher。
7. **重试策略设计完善** — 协议 + 指数退避/固定间隔两种实现 + 抖动因子，覆盖常见重试场景。

---

## 问题清单

### 严重 (Critical)

#### C-1: `requestWithCache()` 创建两个独立 Executor，拦截器状态不共享
- **文件**: `NtkNetwork.swift:234-301`
- **问题**: `requestWithCache()` 在 TaskGroup 中调用 `self.loadCache()`（内部调用 `makeExecutor()`）和 `self.makeExecutor().execute()`，每次 `makeExecutor()` 都创建新的 `NtkNetworkExecutor` 实例，两个 executor 各自持有 `mutableRequest` 的独立拷贝。如果拦截器在 execute 路径中修改了 `context.mutableRequest`，这些修改不会反映到 loadCache 路径。
- **修复方向**: 在 `requestWithCache()` 入口处创建共享 executor，或将 cache 和 network 的执行统一到同一个 executor 内部。
- **状态**: ✅ 已修复 — `makeExecutor()` 改为 lazy `getOrCreateExecutor()`，首次调用创建并缓存 executor，所有执行路径共享同一实例

#### C-2: `makeExecutor()` 每次调用都创建新实例，语义上容易误用
- **文件**: `NtkNetwork.swift:149-166`, `NtkNetwork+TransferProgress.swift:42-51`
- **问题**: `makeExecutor()` 是 `func` 而非 lazy 属性，每次调用都创建新实例。`requestWithProgress()` 同样存在多 executor 风险。
- **修复方向**: 将 executor 创建收敛为一次性操作（在 `markRequestConsumedOrThrow` 时冻结配置并创建 executor）。
- **状态**: ✅ 已修复 — 同 C-1，`getOrCreateExecutor()` 统一解决

### 重要 (Important)

#### I-1: `iNtkClient` 协议强制所有后端提供缓存存储
- **文件**: `iNtkClient.swift:18`
- **问题**: `var storage: iNtkCacheStorage { get }` 意味着每个后端都必须提供 `iNtkCacheStorage` 实现，即使不需要缓存。`AFClient` 通过 `AFNoCacheStorage()` 空实现来满足，违反接口隔离原则。
- **修复方向**: 将缓存相关方法分离到独立的 `iNtkCacheableClient` 协议。
- **状态**: ✅ 已修复 — 缓存方法分离到 `iNtkCacheableClient` 协议，`iNtkClient` 只保留 `execute` + `cancel`；`AFClient` 不再需要 `AFNoCacheStorage`；缓存能力通过独立的 `AFCacheClient` 提供

#### I-2: `iAFRequest` 协议过于庞大，混合多种职责
- **文件**: `AFRequest.swift:27-81`
- **问题**: `checkLogin`、`isEncrypt`、`toastRetErrorMsg` 等属于业务逻辑，不应在网络库的请求协议中。
- **修复方向**: 将业务属性移到业务层的协议扩展中；将序列化配置保留在 AF 特定协议中；将数据解码考虑用拦截器模式替代。
- **状态**: ⏸️ 暂缓 — `iAFRequestToast` 已是独立协议；`checkLogin`/`isEncrypt` 仅用于日志输出，影响有限；当前设计在 AlamofireClient 模块内合理。建议在添加第二个后端时再拆分。

#### I-3: 拦截器排序逻辑不一致
- **文件**: `NtkNetworkExecutor.swift:51-76`
- **问题**: 用户拦截器没有排序，核心拦截器经过 `sortInterceptors` 排序。最终合并是 `config.interceptors + sortInterceptors(executionCoreInterceptors)`，用户拦截器始终排在核心拦截器之前，且用户拦截器之间的顺序取决于添加顺序而非优先级。`NtkInterceptorPriority` 的设计意图不生效。
- **修复方向**: 对所有拦截器统一排序：`sortInterceptors(config.interceptors + executionCoreInterceptors)`。
- **状态**: ✅ 已修复 — `execute()` 中对所有拦截器（用户 + 核心）统一按优先级排序

#### I-4: `Ntk<ResponseData, Keys>` 的 `Keys` 泛型参数泄漏到核心模块
- **文件**: `Ntk.swift:15`
- **问题**: `Keys: iNtkResponseMapKeys` 在核心模块中完全未使用，只在 `AlamofireClient` 模块有意义。添加不使用 `iNtkResponseMapKeys` 的后端时仍需提供无意义的 `Keys` 类型参数。
- **修复方向**: 将 `Keys` 从 `Ntk` 移到 `AlamofireClient` 模块的便捷入口中，核心 `Ntk` 只需 `<ResponseData>` 一个泛型参数。
- **状态**: ✅ 已修复 — `Ntk` 简化为 `Ntk<ResponseData>`，`iNtkClient` 移除 `associatedtype Keys`，`AFClient` 和 `AFCacheClient` 移除 `Keys` 泛型参数，`Keys` 仅在 `withAF` 的数据解析拦截器中使用

#### I-5: 核心路径测试覆盖不足
- **问题**: 缺少 `NtkInterceptorChainManager` 链式执行、`NtkNetworkExecutor` execute/loadCache 流程、`NtkNetwork.request()` / `requestWithCache()` 端到端流程、`NtkDataParsingInterceptor` 各种解析路径的测试。
- **修复方向**: 优先补充拦截器链集成测试和 NtkNetwork 端到端测试。
- **状态**: ⬜ 待修复（工作量较大，建议单独迭代）

#### I-6: `NtkCacheMeta.init?(coder:)` 中 `data` 字段使用不安全的 `decodeObject(forKey:)`
- **文件**: `NtkCacheMeta.swift:58`
- **问题**: 虽然声明了 `supportsSecureCoding = true`，但 `data` 字段解码使用了 `coder.decodeObject(forKey:)` 而非 `coder.decodeObject(of:forKey:)`，绕过了 NSSecureCoding 的类型安全检查。
- **修复方向**: 使用 `decodeObject(of: [...], forKey: "data")` 明确指定允许的类型。
- **状态**: ✅ 已修复 — 使用 `decodeObject(of: [NSString, NSDictionary, NSArray, NSNumber, NSData], forKey:)` 明确指定允许的类型

### 建议 (Minor)

#### M-1: `NtkReturnCode` 是 `final class` 而非 `struct`
- **文件**: `NtkReturnCode.swift:13`
- **问题**: 所有属性都是 `let`，值语义类型用 class 导致不必要的堆分配。
- **状态**: ✅ 已修复 — 改为 `struct`

#### M-2: `NtkLogger` 中 iOS 10 以下的 fallback 分支可以移除
- **文件**: `NtkLogger.swift:123-135`
- **问题**: Package.swift 最低支持 iOS 13，fallback 代码永远不会执行。
- **状态**: ✅ 已修复 — 移除 `@available(iOS 10.0, *)` 标注、`stringValue` 属性和 fallback 分支

#### M-3: `AFDetaultResponseValidation` 拼写错误
- **文件**: `Ntk+AF.swift:53`
- **问题**: `Detault` → `Default`。公开 API 的拼写错误后续修复是 breaking change。
- **状态**: ✅ 已修复 — 重命名为 `AFDefaultResponseValidation`

#### M-4: `NtkDynamicData` 有 `subscript(dynamicMember:)` 但缺少 `@dynamicMemberLookup`
- **文件**: `NtkDynamicData.swift:335-338`
- **问题**: 该下标永远不会被动态成员查找语法调用。
- **状态**: ✅ 已修复 — 添加 `@dynamicMemberLookup` 标注

---

## 扩展性评估：添加纯 URLSession 后端

| 维度 | 评估 |
|------|------|
| 需要实现的协议 | `iNtkClient`（execute 方法）、可选实现 `iNtkCacheableClient`（仅需缓存时）、数据解析拦截器 |
| 核心模块需要修改吗 | **不需要** — 这是架构的最大优势 |
| 拦截器链能复用吗 | 大部分可以（重试、去重、缓存保存、Loading），解析拦截器需要新写（正确的） |
| 主要摩擦点 | `NtkResponseDecoder` 硬编码 code/data/msg 结构（其余摩擦点已修复） |

---

## 总体评估

**架构扩展性评分：8.5 / 10**（修复前 7.5）

修复后的改进：`iNtkClient` 缓存职责已分离到 `iNtkCacheableClient`（新后端无需提供空缓存实现）、`Keys` 泛型已从核心模块移除（新后端无需提供无意义的类型参数）、拦截器排序已统一（优先级设计意图生效）、`requestWithCache()` 共享同一 executor（状态一致性保证）。剩余扣分点：`NtkResponseDecoder` 硬编码 code/data/msg 结构、核心路径测试覆盖不足。

---

## 修复优先级

1. C-1 / C-2: 修复 `requestWithCache()` 多 executor 问题
2. I-1: 协议瘦身 — 分离 `iNtkCacheableClient`
3. I-4: 泛型简化 — `Keys` 下沉到 AlamofireClient
4. I-3: 拦截器统一排序
5. I-6: NSSecureCoding 安全修复
6. I-2: `iAFRequest` 协议职责拆分
7. I-5: 补充核心路径测试
8. M-1 ~ M-4: Minor 修复
