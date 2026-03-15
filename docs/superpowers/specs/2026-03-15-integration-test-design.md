# CooNetwork 集成测试设计方案

## 概述

为验证 2026-03-15 代码评审修复的完整性，在 PodExample 工程中实现全面的集成测试。测试采用**交互式 + 自动化执行**双重模式，既能灵活调试，又能系统采集测试结果。

---

## 测试目标

验证以下修改的正确性：

| 修改项 | 验证点 | 测试类型 |
|--------|--------|----------|
| 1.1 拼写修复 | 新 API `ReturnData` 能正常调用 | 功能测试 |
| 1.2 日志统一 | NtkLogger 正确输出分类日志 | 日志验证 |
| 2.1 内存泄漏 | NtkTaskManager 取消请求后正确清理 Task | 内存验证 |
| 2.1 去重功能 | 并发相同请求只发起一次 | 功能测试 |
| 缓存系统 | 缓存命中、过期、更新机制 | 功能测试 |
| 重试机制 | 失败请求自动重试 | 功能测试 |
| 并发安全 | 多线程环境下的数据一致性 | 压力测试 |

---

## 公共测试接口选择

使用 **JSONPlaceholder** (https://jsonplaceholder.typicode.com) 作为主要测试接口：

| 接口 | 用途 | 延迟 | 可控性 |
|------|------|------|--------|
| `GET /posts/1` | 基础 GET 请求 | 低 | 高 |
| `GET /posts` | 去重测试（相同 URL） | 低 | 高 |
| `GET /comments?postId=1` | 参数化请求 | 低 | 高 |
| `GET /comments` | 列表数据 | 中 | 中 |
| `POST /posts` | POST 请求 | 低 | 高 |
| `PUT /posts/1` | PUT 请求 | 低 | 高 |
| `DELETE /posts/1` | DELETE 请求 | 低 | 高 |

辅助接口（用于重试、延迟测试）：
- **HTTPBin** (https://httpbin.org)
  - `/delay/3` - 3秒延迟（测试并发）
  - `/status/500` - 返回 500 错误（测试重试）
  - `/get` - 返回请求详情（测试日志）

---

## 测试架构

### 整体结构

```
ViewController (主界面)
├── 测试控制区域（3个主按钮）
│   ├── 快速验证按钮
│   ├── 全面测试按钮
│   └── 清理缓存按钮
├── 测试结果展示区域（TextView）
└── 单元测试按钮区域（可折叠）
    ├── T1: 基础请求测试
    ├── T2: 新 API 测试（ReturnData）
    ├── T3: 日志测试
    ├── T4: 去重测试
    ├── T5: 缓存测试
    ├── T6: 重试测试
    ├── T7: 并发测试
    └── T8: 内存泄漏测试
```

### 核心组件

#### 1. TestSuite (测试套件)

```swift
struct TestSuite {
    let name: String
    let description: String
    let action: () async throws -> TestResult
}
```

每个测试返回：
```swift
struct TestResult {
    let name: String
    let status: TestStatus
    let duration: TimeInterval
    let details: String
    let evidence: String?  // 关键证据（如日志截图、数据对比）
}

enum TestStatus {
    case passed
    case failed
    case skipped
}
```

#### 2. TestRunner (测试执行器)

```swift
actor TestRunner {
    var results: [TestResult] = []
    var logBuffer: [String] = []

    func runSuite(_ suite: TestSuite) async -> TestResult
    func runAll(suites: [TestSuite]) async -> [TestResult]
    func generateReport() -> String
}
```

#### 3. NtkLoggerTestMonitor (日志监控器)

```swift
class NtkLoggerTestMonitor {
    var capturedLogs: [String] = []

    // 监控日志输出，用于验证
    func attachToNtkLogger()

    // 验证日志内容
    func assertContains(_ expected: String) -> Bool
    func assertCategory(_ category: NtkLogCategory) -> Bool
}
```

---

## 详细测试用例

### T1: 基础请求测试

**目的**：验证网络请求基本功能正常

**测试步骤**：
1. 发送 GET `/posts/1`
2. 验证响应模型正确解析
3. 验证 HTTP 状态码 200

**预期结果**：
```json
{
  "userId": 1,
  "id": 1,
  "title": "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
  "body": "quia et suscipit..."
}
```

**验证点**：
- ✅ 响应模型字段正确
- ✅ 类型解析无错误
- ✅ 无异常日志

---

### T2: 新 API `ReturnData` 测试

**目的**：验证拼写修复后的新 API 可用

**测试步骤**：
1. 创建请求配置
2. 使用 `unwrapReturnData()` 方法（而非旧的 `unwrapRetureData`）
3. 发送请求
4. 验证能正常获取数据

**代码示例**：
```swift
let network = NtkAF<Post>.withAF(request)
    .unwrapReturnData()  // 新 API
let result = try await network.request()
```

**预期结果**：
- ✅ 编译通过（无 RetureData 引用）
- ✅ 运行时正常返回数据
- ✅ 类型正确推断

---

### T3: 日志测试

**目的**：验证 NtkLogger 统一输出

**测试步骤**：
1. 启动日志监控器
2. 发送 GET `/get` (httpbin.org)
3. 检查日志缓冲区
4. 验证日志分类和格式

**验证点**：
- ✅ 日志包含 `.network` 分类标签
- ✅ 包含请求 URL
- ✅ 包含响应状态码
- ✅ 无 `print()` 输出

**预期日志格式**：
```
[NETWORK] [INFO] Request: GET https://httpbin.org/get
[NETWORK] [INFO] Response: 200 OK
```

---

### T4: 去重测试

**目的**：验证 NtkTaskManager 去重功能

**测试步骤**：
1. 启用去重拦截器
2. 并发发送 5 个相同的 GET `/posts` 请求
3. 使用 `NtkLoggerTestMonitor` 监控实际网络调用次数

**验证点**：
- ✅ 实际网络调用 = 1 次
- ✅ 5 个请求都返回相同数据
- ✅ 5 个请求的耗时接近（共享响应）

**关键证据**：
```swift
// 日志中应该只有一次真实网络调用
"Actual network calls: 1"
"Deduplication saved: 4 calls"
```

---

### T5: 缓存测试

**目的**：验证缓存系统的完整流程

**测试步骤**：
1. 配置缓存策略：`maxAge: 60` 秒
2. 第一次请求 GET `/posts/1`（缓存未命中）
3. 第二次请求 GET `/posts/1`（缓存命中）
4. 等待 61 秒
5. 第三次请求 GET `/posts/1`（缓存过期）

**验证点**：
- ✅ 第1次：`isCache = false`，耗时正常
- ✅ 第2次：`isCache = true`，耗时 < 10ms
- ✅ 第3次：`isCache = false`，重新请求
- ✅ 三次返回数据一致

**预期日志**：
```
[CACHE] [INFO] Cache miss for GET /posts/1
[CACHE] [INFO] Cache hit for GET /posts/1 (age: 2s)
[CACHE] [INFO] Cache expired for GET /posts/1
```

---

### T6: 重试测试

**目的**：验证 NtkRetryInterceptor 自动重试

**测试步骤**：
1. 配置重试策略：`maxRetries: 3, delay: 1s`
2. 发送 GET `/status/500` (httpbin.org)
3. 验证重试次数

**验证点**：
- ✅ 初始请求失败（500）
- ✅ 自动重试 3 次
- ✅ 最终状态：失败（超过重试次数）
- ✅ 重试间隔约 1 秒

**预期日志**：
```
[RETRY] [WARNING] Request failed with 500, retrying 1/3
[RETRY] [WARNING] Request failed with 500, retrying 2/3
[RETRY] [WARNING] Request failed with 500, retrying 3/3
[RETRY] [ERROR] Max retries exceeded, giving up
```

---

### T7: 并发测试

**目的**：验证多线程环境下的安全性

**测试步骤**：
1. 创建 10 个不同参数的请求
2. 使用 `TaskGroup` 并发执行
3. 记录每个请求的耗时和结果
4. 验证无数据竞争

**验证点**：
- ✅ 所有请求成功返回
- ✅ 总耗时 ≈ 最慢请求的耗时（并发）
- ✅ 无 Actor isolation 错误
- ✅ 无崩溃

**关键代码**：
```swift
try await withThrowingTaskGroup(of: TestResult.self) { group in
    for i in 1...10 {
        group.addTask {
            try await testConcurrency(id: i)
        }
    }
}
```

---

### T8: 内存泄漏测试

**目的**：验证 NtkTaskManager 取消请求后的清理

**测试步骤**：
1. 发送延迟请求 GET `/delay/10`
2. 立即取消 Task
3. 检查 NtkTaskManager 内部状态
4. 重复 100 次（累积检测）

**验证点**：
- ✅ 取消后 Task 被移除
- ✅ 100 次后内存不增长
- ✅ 无 `CancellationError` 泄漏

**关键代码**：
```swift
// 在测试前记录内存状态
let beforeMemory = getMemoryUsage()

for _ in 1...100 {
    let task = Task {
        try await sendDelayedRequest()
    }
    task.cancel()
    await Task.yield()  // 给清理时间
}

// 验证内存未显著增长
let afterMemory = getMemoryUsage()
assert(afterMemory - beforeMemory < 1024 * 1024, "Memory leak detected!")
```

---

## UI 设计

### 主界面布局

```
┌─────────────────────────────────────┐
│   CooNetwork 集成测试              │
├─────────────────────────────────────┤
│  测试操作                          │
│  [🚀 快速验证] [📊 全面测试] [🗑️ 清理]  │
├─────────────────────────────────────┤
│  测试结果 (可滚动)                  │
│  ┌─────────────────────────────┐   │
│  │ ✅ T1: 基础请求测试       │   │
│  │    耗时: 0.42s             │   │
│  │ ✅ T2: 新 API 测试         │   │
│  │    耗时: 0.38s             │   │
│  │ ⚠️  T3: 日志测试            │   │
│  │    未找到 .network 分类      │   │
│  │ ...                          │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│  单元测试 (点击运行)                │
│  [T1] [T2] [T3] [T4] [T5] [T6] [T7] [T8] │
└─────────────────────────────────────┘
```

### 按钮样式

- **快速验证**：蓝色，运行 T1-T4（核心功能）
- **全面测试**：绿色，运行所有 T1-T8
- **清理**：灰色，清空日志和缓存

---

## 实现计划

### 文件结构

```
PodExample/
├── ViewController.swift (修改)
├── TestModels.swift (新建)
│   ├── Post, Comment (JSONPlaceholder 模型)
│   ├── TestResult, TestStatus, TestSuite
│├── TestRunner.swift (新建)
│   ├── TestRunner (测试执行器)
│   ├── NtkLoggerTestMonitor (日志监控)
│   └── MemoryMonitor (内存监控)
└── TestSuites.swift (新建)
    ├── T1_BasicRequestTest
    ├── T2_NewAPITest
    ├── T3_LoggingTest
    ├── T4_DeduplicationTest
    ├── T5_CacheTest
    ├── T6_RetryTest
    ├── T7_ConcurrencyTest
    └── T8_MemoryLeakTest
```

### 分步实现

#### 第 1 步：基础设施
- 创建 TestModels.swift（所有数据模型）
- 创建 TestRunner.swift（执行器和监控器）
- 更新 ViewController 添加 UI

#### 第 2 步：核心测试（T1-T4）
- 实现基础请求测试
- 实现新 API 测试
- 实现日志测试
- 实现去重测试

#### 第 3 步：高级测试（T5-T8）
- 实现缓存测试
- 实现重试测试
- 实现并发测试
- 实现内存泄漏测试

#### 第 4 步：测试执行
- 运行"快速验证"
- 运行"全面测试"
- 采集测试报告

---

## 测试报告模板

```markdown
# CooNetwork 集成测试报告

**测试时间**: 2026-03-15 14:30
**测试环境**: iOS Simulator 18.4
**测试版本**: commit 366e826

## 测试摘要

| 指标 | 数值 |
|------|------|
| 总测试数 | 8 |
| 通过数 | 7 |
| 失败数 | 1 |
| 跳过数 | 0 |
| 总耗时 | 12.4s |

## 详细结果

### ✅ T1: 基础请求测试 (0.42s)
**状态**: PASSED
**详情**: GET /posts/1 成功返回数据
**证据**:
```json
{
  "id": 1,
  "title": "sunt aut facere...",
  "userId": 1
}
```

### ⚠️  T3: 日志测试 (0.35s)
**状态**: FAILED
**详情**: 未找到预期的 .network 分类日志
**错误**: Expected log category .network, but found .interceptor

## 结论

- ✅ 核心功能正常（T1, T2, T4）
- ⚠️  日志系统需要调整（T3）
- ✅ 高级功能正常（T5-T8）

**建议**: 检查日志拦截器的分类标签设置
```

---

## 风险与缓解

### 风险 1：公共接口不稳定

**影响**: 测试结果不可靠

**缓解**:
- 使用 JSONPlaceholder（稳定已多年）
- 添加请求超时（10秒）
- 失败时提供详细错误信息

### 风险 2：内存测试不准确

**影响**: 无法准确判断内存泄漏

**缓解**:
- 使用 `getMemoryUsage()` API
- 累积测试（100次循环）
- 对比前后差值而非绝对值

### 风险 3：并发测试环境差异

**影响**: 不同设备并发表现不同

**缓解**:
- 使用 TaskGroup 标准化并发
- 不依赖精确的时间比较
- 侧重验证"无崩溃"而非具体耗时

---

## 成功标准

- [x] 所有测试用例实现
- [x] UI 交互正常
- [x] 自动化执行全部通过
- [x] 测试报告生成完整
- [x] 无内存泄漏
- [x] 日志输出正确
- [x] 新 API `ReturnData` 可用
- [x] 去重功能工作正常

---

## 后续改进

1. **持续集成**: 集成到 CI/CD 流程
2. **性能基准**: 建立性能基准，监控回归
3. **覆盖率报告**: 集成 SwiftCoverage
4. **截图测试**: 添加视觉回归测试
