# 请求级去重覆盖 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让请求能继承、强制开启或强制关闭全局去重默认值。

**Architecture:** 在 `NtkMutableRequest` 的去重扩展中以公开三态枚举表达请求意图，并继续将该值存入请求快照的 `extraData`。执行器在请求修改器完成后一次性解析该策略；`includeDeduplication` 仍是内部路径保护，最终只决定是否创建 `NtkDeduplicationKey`。

**Tech Stack:** Swift 6、Swift Testing、Swift Package Manager。

---

## 文件结构

- 修改：`Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift` — 定义策略枚举、请求级设置方法和继承默认值。
- 修改：`Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift` — 将全局默认与请求策略解析为本次执行的有效去重值。
- 修改：`Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` — 通过捕获的 interceptor context 验证有效去重键。

### Task 1: 写出请求策略覆盖的失败测试

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift:612-661`

- [ ] **Step 1: 添加全局关闭时的请求级开启测试**

在 `unsupportedRequestIdentityValueStillUsesFrameworkTimeout` 之后添加：

```swift
@Test
func requestCanEnableDeduplicationWhenGlobalDefaultIsDisabled() async throws {
    var builder = NtkConfiguration.Builder()
    builder.isDeduplicationEnabled = false
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/deduplication-override-enabled"))
    request.enableDeduplication()
    let capture = ExecPreparedContextCapture()
    let executor = NtkNetworkExecutor<Bool>(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecPreparedContextInterceptor(capture: capture)
        ],
        globalConfiguration: NtkConfiguration(builder: builder)
    ))

    _ = try await executor.execute()

    #expect(await capture.deduplicationKey() != nil)
}
```

- [ ] **Step 2: 运行测试并确认因缺少接口而失败**

Run: `swift test --filter NtkNetworkExecutorTests/requestCanEnableDeduplicationWhenGlobalDefaultIsDisabled`

Expected: 编译失败，提示 `NtkMutableRequest` 没有 `enableDeduplication()`。

### Task 2: 添加请求策略接口并使测试通过

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift:11-28`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift:612-638`

- [ ] **Step 1: 定义三态策略和写入方法**

将布尔 key 替换为策略 key，并在扩展前定义：

```swift
public enum NtkDeduplicationPolicy: Sendable {
    case inherit
    case enabled
    case disabled
}
```

在扩展内实现：

```swift
private static let deduplicationPolicyKey = "ntk_deduplication_policy"

@discardableResult
public mutating func enableDeduplication() -> NtkMutableRequest {
    extraData[Self.deduplicationPolicyKey] = NtkDeduplicationPolicy.enabled
    return self
}

@discardableResult
public mutating func disableDeduplication() -> NtkMutableRequest {
    extraData[Self.deduplicationPolicyKey] = NtkDeduplicationPolicy.disabled
    return self
}

var deduplicationPolicy: NtkDeduplicationPolicy {
    (extraData[Self.deduplicationPolicyKey] as? NtkDeduplicationPolicy) ?? .inherit
}
```

为枚举、两个方法与计算属性补齐现有风格的中文文档注释；`disableDeduplication()` 的公开签名保持不变。

- [ ] **Step 2: 运行同一测试并确认仍失败**

Run: `swift test --filter NtkNetworkExecutorTests/requestCanEnableDeduplicationWhenGlobalDefaultIsDisabled`

Expected: 断言失败，因为 executor 仍要求全局开关为 `true`。

### Task 3: 在执行器解析覆盖策略

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift:112-114`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift:612-638`

- [ ] **Step 1: 使用请求策略解析有效值**

用以下代码替换现有三项 `&&` 条件：

```swift
let requestDeduplicationEnabled: Bool
switch request.deduplicationPolicy {
case .inherit:
    requestDeduplicationEnabled = config.isDeduplicationEnabled
case .enabled:
    requestDeduplicationEnabled = true
case .disabled:
    requestDeduplicationEnabled = false
}
let deduplicationEnabled = includeDeduplication && requestDeduplicationEnabled
```

不要改变缓存开关与 request identity 的构建条件。

- [ ] **Step 2: 运行测试并确认通过**

Run: `swift test --filter NtkNetworkExecutorTests/requestCanEnableDeduplicationWhenGlobalDefaultIsDisabled`

Expected: PASS。

### Task 4: 锁定继承和强制关闭的回归行为

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift:612-661`

- [ ] **Step 1: 添加继承与强制关闭测试**

在 Task 1 的测试之后添加：

```swift
@Test
func requestInheritsDisabledGlobalDeduplicationDefault() async throws {
    var builder = NtkConfiguration.Builder()
    builder.isDeduplicationEnabled = false
    let request = NtkMutableRequest(ExecDummyRequest(path: "/executor/deduplication-inherit-disabled"))
    let capture = ExecPreparedContextCapture()
    let executor = makeExecutorCapturingPreparedContext(
        request: request,
        capture: capture,
        globalConfiguration: NtkConfiguration(builder: builder)
    )

    _ = try await executor.execute()

    #expect(await capture.deduplicationKey() == nil)
}

@Test
func requestCanDisableDeduplicationWhenGlobalDefaultIsEnabled() async throws {
    var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/deduplication-override-disabled"))
    request.disableDeduplication()
    let capture = ExecPreparedContextCapture()
    let executor = makeExecutorCapturingPreparedContext(request: request, capture: capture)

    _ = try await executor.execute()

    #expect(await capture.deduplicationKey() == nil)
}
```

扩展 `makeExecutorCapturingPreparedContext` 的参数，使其可传入测试专用全局配置：

```swift
private func makeExecutorCapturingPreparedContext(
    request: NtkMutableRequest,
    capture: ExecPreparedContextCapture,
    globalConfiguration: NtkConfiguration = .current
) -> NtkNetworkExecutor<Bool> { /* 将 globalConfiguration 传给 Configuration */ }
```

- [ ] **Step 2: 运行执行器测试**

Run: `swift test --filter NtkNetworkExecutorTests`

Expected: PASS，三个覆盖语义测试与既有 executor 测试全部通过。

### Task 5: 全量验证并提交

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1: 检查改动范围和空白错误**

Run: `git diff --check && git diff -- Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

Expected: `git diff --check` 无输出；diff 仅包含策略、解析和覆盖测试。

- [ ] **Step 2: 运行完整测试套件**

Run: `swift test`

Expected: 所有测试通过；如继续出现 `CLAUDE.md` 未声明资源警告，记录为既有 SwiftPM 警告而非本次失败。

- [ ] **Step 3: 提交实现**

```bash
git add Sources/CooNetwork/NtkNetwork/deduplication/NtkMutableRequest+deduplication.swift \
  Sources/CooNetwork/NtkNetwork/NtkNetworkExecutor.swift \
  Tests/CooNetworkTests/NtkNetworkExecutorTests.swift
git commit -m "feat: support request deduplication overrides"
```
