# 网络执行可观测性 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 CooNetwork 在详细日志开启时输出完整执行诊断，在常规模式保留 warning/error/fault，并记录请求身份和去重的关键决策而不泄露敏感数据。

**Architecture:** `NtkLogger` 在每次写入时根据 `NtkConfiguration` 动态选择最低等级，并提供仅供 `@testable` 测试安装的同步日志接收器。执行器负责记录请求身份、超时和去重键的准备结果；任务管理器负责共享任务的生命周期；缓存和重试记录各自拥有的结果。所有日志使用固定事件名和最小必要上下文，外部错误只记录动态类型。

**Tech Stack:** Swift 6.1、Swift Testing、Foundation、OSLog、现有 `NtkUnfairLock`。

---

## 文件结构

- Modify: `Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift` - 动态等级策略、受控测试接收器和统一输出。
- Modify: `Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift` - 将布尔配置注释明确为详细诊断开关。
- Create: `Tests/CooNetworkTests/NtkLoggerTests.swift` - 验证两档等级过滤和配置动态生效。
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift` - 记录最终请求、超时、identity、去重键及缓存路径决策。
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift` - 记录 owner/follower、取消、超时和清理。
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift` - 记录缓存读写命中、跳过与存储故障。
- Modify: `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift` - 移除外部错误详情并使用稳定事件名。
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift` - 将缓存并发读取失败记为 warning，且只记录错误类型。
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift` - 不再打印完整请求和参数。
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift` - 不再打印 hook 抛出的原始错误文本。
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` - 覆盖 identity 成功、跳过、失败降级与去重键日志。
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift` - 覆盖共享任务生命周期、取消、超时日志。

### Task 1: 建立动态等级与可观察日志输出

**Files:**
- Create: `Tests/CooNetworkTests/NtkLoggerTests.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift`

- [ ] **Step 1: 写入失败测试，定义关闭详细日志时的保留等级**

在 `NtkLoggerTests.swift` 新建串行测试套件和线程安全收集器。测试保存原始 `NtkConfiguration.current`，安装测试接收器，设置 `isLoggingEnabled = false`，依次记录五个等级，并断言只得到后三条：

```swift
@Suite(.serialized)
struct NtkLoggerTests {
    @Test
    func disabledDetailedLoggingKeepsWarningAndAbove() {
        let original = NtkConfiguration.current
        defer { NtkConfiguration.configure { $0 = original.builder } }

        let collector = LogRecordCollector()
        let restoreSink = NtkLogger.installTestSink { collector.append($0) }
        defer { restoreSink() }
        NtkConfiguration.configure { $0.isLoggingEnabled = false }

        logger.debug("debug")
        logger.info("info")
        logger.warning("warning")
        logger.error("error")
        logger.fault("fault")

        #expect(collector.records.map(\.message) == ["warning", "error", "fault"])
    }
}

final class LogRecordCollector: @unchecked Sendable {
    private let lock = NtkUnfairLock()
    private var storage: [NtkLogger.LogRecord] = []

    var records: [NtkLogger.LogRecord] { lock.withLock { storage } }
    var joinedMessages: String { records.map(\.message).joined(separator: "\n") }

    func append(_ record: NtkLogger.LogRecord) {
        lock.withLock { storage.append(record) }
    }
}
```

- [ ] **Step 2: 运行测试，确认它因现有全局开关过滤失败**

Run: `swift test --filter NtkLoggerTests.disabledDetailedLoggingKeepsWarningAndAbove`

Expected: FAIL，收集记录为空，因为当前 `NtkLogger.log` 在 `isLoggingEnabled == false` 时直接返回。

- [ ] **Step 3: 补充失败测试，定义详细模式和运行期配置刷新**

在同一文件新增测试，先以 `false` 写入一条 debug，再切为 `true` 写入一条 debug，断言仅后一条被接收：

```swift
@Test
func enablingDetailedLoggingImmediatelyAllowsDebug() {
    let original = NtkConfiguration.current
    defer { NtkConfiguration.configure { $0 = original.builder } }
    let collector = LogRecordCollector()
    let restoreSink = NtkLogger.installTestSink { collector.append($0) }
    defer { restoreSink() }

    NtkConfiguration.configure { $0.isLoggingEnabled = false }
    logger.debug("before")
    NtkConfiguration.configure { $0.isLoggingEnabled = true }
    logger.debug("after")

    #expect(collector.records.map(\.message) == ["after"])
}
```

- [ ] **Step 4: 实现最小日志观察点和动态最低等级**

在 `NtkLogger.swift`：

1. 删除冻结的 `currentLevel` 存储属性和带 `currentLevel` 的初始化器。
2. 新增内部 `LogRecord: Sendable, Equatable`，包含 `level`、`category`、`message`。
3. 使用 `NtkUnfairLock` 保护一个 `nonisolated(unsafe)` 的静态测试 sink；新增内部 `installTestSink(_:) -> @Sendable () -> Void`，返回恢复原 sink 的闭包。
4. 新增计算属性：

```swift
private var minimumLevel: Level {
    isLoggingEnabled ? .debug : .warning
}
```

5. 在 `log` 中先执行 `guard level >= minimumLevel else { return }`，构造 `LogRecord`；存在测试 sink 时只交给 sink，否则沿用现有 `OSLog` 与 `os_log` 输出。

测试收集器以 `NtkUnfairLock` 保护 `[NtkLogger.LogRecord]`，避免 `@Sendable` 闭包捕获可变数组。测试 sink 只在 `@Suite(.serialized)` 中安装，所有测试以 `defer` 恢复 sink 和配置。

- [ ] **Step 5: 更新配置注释**

在 `NtkConfiguration.Builder.isLoggingEnabled` 的文档注释中写明：`true` 输出 debug 到 fault 的完整框架诊断；`false` 仍输出 warning、error 和 fault。不要改动属性名或公开 API。

- [ ] **Step 6: 运行日志测试，确认转绿**

Run: `swift test --filter NtkLoggerTests`

Expected: PASS，关闭详细日志时保留 warning/error/fault，开启后立即输出 debug。

- [ ] **Step 7: 提交该独立改动**

```bash
git add Sources/CooNetwork/NtkNetwork/utils/NtkLogger.swift Sources/CooNetwork/NtkNetwork/NtkConfiguration.swift Tests/CooNetworkTests/NtkLoggerTests.swift
git commit -m "feat: make framework log levels observable"
```

### Task 2: 为 executor 记录请求身份与执行准备结果

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`

- [ ] **Step 1: 写入 identity 成功和跳过的失败测试**

复用 Task 1 的 `LogRecordCollector`，在测试开始处开启详细日志并安装 sink。对带缓存 provider 的 `NtkNetworkExecutor<Bool>` 执行请求，断言 `.requestIdentity` 分类存在以下消息前缀，且包含该测试已计算出的 `expectedRequestIdentity.value`：

```swift
#expect(records.contains {
    $0.category == .requestIdentity &&
    $0.level == .debug &&
    $0.message.hasPrefix("[RequestIdentity] built ") &&
    $0.message.contains(expectedRequestIdentity.value)
})
```

再对无缓存 provider 且请求级禁用去重的 executor 执行请求，断言存在 `[RequestIdentity] skipped reason=no-consumer` 的 debug 事件。

- [ ] **Step 2: 运行测试，确认 identity 成功/跳过事件尚不存在**

Run: `swift test --filter NtkNetworkExecutorTests.requestIdentity`

Expected: FAIL，现有代码仅在构建失败时输出 warning。

- [ ] **Step 3: 写入 identity 失败脱敏的失败测试**

扩展既有 `requestIdentityBuildFailureSkipsCacheButStillExecutesNetwork`：设置一个可识别的敏感参数值，例如 `secret-identity-value`，并断言存在 `.warning` 的 `[RequestIdentity] unavailable` 事件，同时其消息不包含该值。保留现有网络仍成功、缓存未访问的断言。

- [ ] **Step 4: 实现 executor 日志**

在 `makeContext(includeDeduplication:includeCache:)` 中，在解析有效 timeout 和请求级去重覆盖后记录：

```swift
logger.debug(
    "[RequestExecution] prepared requestID=\(request.instanceIdentifier.uuidString) method=\(request.method.rawValue) path=\(request.path) timeout=\(effectiveTimeout) cache=\(cacheEnabled) deduplication=\(deduplicationEnabled)",
    category: .network
)
```

在 identity 分支中记录：

```swift
logger.debug(
    "[RequestIdentity] built requestID=\(request.instanceIdentifier.uuidString) identity=\(requestIdentity.value)",
    category: .requestIdentity
)
logger.debug(
    "[RequestIdentity] skipped requestID=\(request.instanceIdentifier.uuidString) reason=no-consumer",
    category: .requestIdentity
)
logger.warning(
    "[RequestIdentity] unavailable requestID=\(request.instanceIdentifier.uuidString) reason=\(error.logMessage) cache=false deduplication=false",
    category: .requestIdentity
)
```

在派生 `deduplicationKey` 后记录 `[Deduplication] key-ready` 或 `[Deduplication] disabled`。`key-ready` 仅包含 requestID、identity、effective timeout 和 namespace；不要序列化 `ObjectIdentifier(ResponseData.self)`。不改变 key 构建、缓存或返回值逻辑。

- [ ] **Step 5: 运行 executor 定向测试，确认转绿**

Run: `swift test --filter NtkNetworkExecutorTests.requestIdentity`

Expected: PASS，成功、跳过和降级事件的等级、identity 关联和脱敏断言全部通过。

- [ ] **Step 6: 提交该独立改动**

```bash
git add Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "feat: log request identity preparation"
```

### Task 3: 为去重调度记录共享任务生命周期

**Files:**
- Modify: `Tests/CooNetworkTests/NtkTaskManagerTests.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift`

- [ ] **Step 1: 写入共享命中与清理的失败测试**

扩展 `testEnabledDeduplicationSharesSingleExecution`，在 gate 放行后检查收集器中存在 `.deduplication` 分类的三条 debug 事件：

```swift
#expect(messages.contains { $0.hasPrefix("[Deduplication] owner-created ") })
#expect(messages.contains { $0.hasPrefix("[Deduplication] follower-joined ") })
#expect(messages.contains { $0.hasPrefix("[Deduplication] entry-removed ") })
```

断言每条共享事件均包含 `identity=ntk-identity-v2-test`，且不包含 dummy request 的 Header 或参数值。

- [ ] **Step 2: 运行测试，确认生命周期事件尚不存在**

Run: `swift test --filter NtkTaskManagerTests.testEnabledDeduplicationSharesSingleExecution`

Expected: FAIL，当前 task manager 不输出日志。

- [ ] **Step 3: 写入取消和超时的失败测试**

在 `testDedupFollowerCancelReceivesRequestCancelledNotNetworkError` 断言 `[Deduplication] follower-cancelled` debug 事件。新增 `testFrameworkTimeoutEmitsDeduplicationError`：以 `effectiveTimeout: 0.01` 调用 `executeWithDeduplication`，执行闭包等待足够久以触发 framework timeout，并断言 `[Deduplication] execution-timeout` error 事件包含 `timeout=0.01`，但不包含任意外部错误描述。

- [ ] **Step 4: 实现任务管理器事件**

新增私有 helper，将 `request.instanceIdentifier.uuidString` 与可选 `deduplicationKey.requestIdentity.value` 格式化为日志上下文；隔离任务只记录 requestID。为 `executeWithTimeout` 增加这个已格式化上下文参数，使 timeout 事件能够保留 owner 的 requestID 与共享 identity，而无需读取可变状态。

在以下位置记录 `.deduplication` 事件：

```swift
// executeNewRequestWithTimeout，在登记 owner 后
logger.debug("[Deduplication] owner-created \(context) timeout=\(effectiveTimeout)", category: .deduplication)

// awaitOngoingResultIfAvailable，在 follower 登记后
logger.debug("[Deduplication] follower-joined \(context)", category: .deduplication)

// cancelWaiter，分别处理 owner 与 follower
logger.debug("[Deduplication] owner-cancelled \(context)", category: .deduplication)
logger.debug("[Deduplication] follower-cancelled \(context)", category: .deduplication)

// removeEntryIfNoWaiters，取消底层任务前
logger.debug("[Deduplication] entry-removed \(context) reason=no-waiters", category: .deduplication)
```

在 `executeWithTimeout` 的超时 task 抛错前记录 `[Deduplication] execution-timeout timeout=...`。在 `executeNewRequestWithTimeout` 捕获非取消、非框架超时的失败时只记录 `[Deduplication] execution-failed errorType=\(String(reflecting: type(of: error)))`，然后按原逻辑抛出。不得改变 actor 状态更新、取消顺序、`defer` 清理或错误类型。

- [ ] **Step 5: 运行 task manager 定向测试，确认转绿**

Run: `swift test --filter NtkTaskManagerTests`

Expected: PASS，现有共享、取消和超时行为不变，新增日志断言通过。

- [ ] **Step 6: 提交该独立改动**

```bash
git add Sources/CooNetwork/NtkNetwork/deduplication/NtkTaskManager.swift Tests/CooNetworkTests/NtkTaskManagerTests.swift
git commit -m "feat: log deduplication task lifecycle"
```

### Task 4: 补齐缓存、重试与既有日志的脱敏

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetwork.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 写入缓存日志与错误脱敏的失败测试**

在 `NtkNetworkExecutorTests.swift` 中使用包含 `Authorization: token-for-log-test` 的请求和一个抛出 `SensitiveStorageError("cache-secret")` 的 storage。断言：

```swift
#expect(records.contains { $0.message.hasPrefix("[Cache] write-succeeded ") })
#expect(records.contains { $0.level == .warning && $0.message.hasPrefix("[Cache] load-failed ") })
#expect(!records.joinedMessages.contains("token-for-log-test"))
#expect(!records.joinedMessages.contains("cache-secret"))
```

- [ ] **Step 2: 运行测试，确认缓存事件和脱敏断言失败**

Run: `swift test --filter NtkNetworkExecutorTests.cache`

Expected: FAIL，当前缓存日志没有稳定事件名、未附带 identity，外部错误路径会插值原始错误。

- [ ] **Step 3: 实现缓存事件**

在 `NtkCacheInterceptor` 中：

1. 守卫条件失败时，若 cache 配置启用但 identity 缺失，记录 `[Cache] write-skipped requestID=... reason=identity-unavailable` debug。
2. 写入后以 `[Cache] write-succeeded` 或 `[Cache] write-failed` debug 记录 requestID 和 identity。
3. `loadCacheData` 捕获 storage 抛错，记录 `[Cache] load-failed requestID=... identity=... errorType=...` warning 后重新抛出；成功返回 nil 时记录 `load-miss` debug，非 nil 时记录 `load-hit` debug。
4. `hasCacheData` 记录 `availability=hit`/`availability=miss` debug。

日志不得打印 request、response、cache data 或 storage error 的描述。

- [ ] **Step 4: 写入重试与解析日志脱敏的失败测试**

在现有重试测试中使 retry policy 接收一个 `Error`，其描述包含 `retry-secret`；收集日志后断言重试错误事件含 `errorType=` 而不含 `retry-secret`。对抛错 hook 重复断言其 warning 不包含 `hook-secret`。测试中使用 `[Retry]` 和 `[NtkParsingHookDispatcher]` 的稳定事件前缀。

- [ ] **Step 5: 实现其余模块日志清理**

1. `NtkRetryInterceptor` 的三处 `\(error)`/`\(finalError)` 改为 `errorType=\(String(reflecting: type(of: error)))`，事件分别为 `[Retry] scheduled`、`[Retry] succeeded`、`[Retry] exhausted`。
2. `NtkNetwork.requestWithCache()` 的缓存读取 catch 改用 `.warning`，消息为 `[Cache] concurrent-load-failed errorType=...`。
3. `NtkDataParsingInterceptor.logDecodedHeader` 不再插值 `request` 或 `request.parameters`，只输出 `[Response] decoded method=... path=... code=... isCache=...`。
4. `NtkParsingHookDispatcher.notify` 的 warning 仅输出 event 名称和 error type。

- [ ] **Step 6: 运行相关定向测试，确认转绿**

Run: `swift test --filter NtkNetworkExecutorTests`

Expected: PASS，缓存、identity 和原有 executor 行为保持不变，日志不泄露测试敏感文本。

Run: `swift test --filter NtkRetry`

Expected: PASS，重试语义不变，错误日志不含原始描述。

- [ ] **Step 7: 提交该独立改动**

```bash
git add Sources/CooNetwork/NtkNetwork/interceptor/NtkCacheInterceptor.swift Sources/CooNetwork/NtkNetwork/retry/NtkRetryInterceptor.swift Sources/CooNetwork/NtkNetwork/NtkNetwork.swift Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift Sources/CooNetwork/NtkNetwork/parsing/NtkParsingHookDispatcher.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "feat: add safe network lifecycle logs"
```

### Task 5: 完整验证与文档同步

**Files:**
- Modify: `README.md`（仅当日志开关已有用户文档时）
- Modify: `docs/design-decisions.md` - 记录两档日志策略和脱敏不变量。

- [ ] **Step 1: 检查公开日志开关文档**

Run: `rg -n "isLoggingEnabled|日志" README.md docs -g '*.md'`

Expected: 若 README 已说明该开关，更新为“详细诊断开关”，写明关闭时仍保留 warning/error/fault；若不存在公开说明，不创建无关 README 段落。

- [ ] **Step 2: 更新设计决策**

在 `docs/design-decisions.md` 的 `NtkLogger 日志级别` 条目补充：最低等级动态取自配置，`true -> .debug`，`false -> .warning`；非框架控制错误只记录类型；身份和去重日志不记录请求字段值。

- [ ] **Step 3: 运行完整测试**

Run: `swift test`

Expected: PASS，所有已有测试与新增日志测试通过，输出无编译 warning。

- [ ] **Step 4: 检查变更质量与敏感信息**

Run: `git diff --check && rg -n 'logger\\.(debug|info|warning|error|fault).*\\\\\(error\\)|logger\\.(debug|info|warning|error|fault).*request\\.parameters|logger\\.(debug|info|warning|error|fault).*\\\\(request\\)' Sources/CooNetwork/NtkNetwork -g '*.swift'`

Expected: `git diff --check` 无输出；新增或修改的日志不插值 `error`、完整 request 或参数。

- [ ] **Step 5: 提交验证与文档改动**

```bash
git add README.md docs/design-decisions.md
git commit -m "docs: describe network logging policy"
```

仅在 Step 1 或 Step 2 产生文档改动时执行该提交；否则跳过提交并在交付说明中明确说明。
