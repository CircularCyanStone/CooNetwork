# Remove Parser Validation Requirement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除 `iNtkResponseParser.validation` 协议要求与 `NtkDataParsingInterceptor` 的公开 `validation` 暴露，同时保持现有 parsing 行为与错误语义完全不变。

**Architecture:** 保持当前 parsing 架构不变：`NtkDataParsingInterceptor` 继续只负责 orchestration，`NtkDefaultResponseParsingPolicy` 继续独占 validation / decision。此次实现只收紧协议与公开 API 表达，不改变 policy 逻辑、parser 主流程或任何解析分支行为。

**Tech Stack:** Swift 6.1 / Swift Package Manager / Swift Testing / CooNetwork parsing module

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift` | 删除 `validation` 协议要求，并同步修正文档注释，移除 parser 持有 validation 的描述。 |
| `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift` | 删除 `public let validation`，保留 init 参数并仅用于构造 policy。 |
| `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` | 作为 data parsing 行为不变性的主回归集，覆盖 decode / validation / nil data / `NtkNever` / fallback 等核心语义。 |
| `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift` | 删除仅为 conform 协议存在的 `validation` 属性，并保留原有 single-use 行为验证。 |
| `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift` | 删除 mock parser 的 `validation` 属性，并补一条“无 validation 成员的 parser 仍可接入执行链”的回归测试。 |
| `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift` | 删除 mock parser 的 `validation` 属性；如 integration 覆盖不足，可在此补协议收口回归。 |
| `Examples/PodExample/PodExample/TestModels.swift` | 删除仅因协议要求而存在的 `validation` 属性。 |
| `Examples/PodExample/PodExample/ViewController.swift` | 删除仅因协议要求而存在的 `validation` 属性。 |

### Expected search sweep

实现时需做两类全仓检索，不要只改上表列出的文件后就停止搜索：

1. `iNtkResponseParser` conformer 检索：确认所有实现类型是否仍保留无效 `validation` 属性。
2. API 读取点 / 文本残留检索：确认仓内不存在对以下已删除表面的直接依赖，或已全部修复：
   - `parser.validation`
   - `NtkDataParsingInterceptor.validation`
   - `var validation: iNtkResponseValidation { get }`
   - 注释/示例中“parser 持有 validation”的描述

---

## Task 1: 先锁定协议收口后的接入行为（RED）

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Read if needed: `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`
- Read if needed: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

- [ ] **Step 1.1: 定位现有自定义 parser 测试落点**

阅读并确认最适合放置协议收口回归测试的位置。优先使用已经存在自定义 `iNtkResponseParser` test double 的文件。

优先候选：
- `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`

验收标准：选定一个测试文件，在该文件中新增/调整一个不声明 `validation` 的 parser test double。

- [ ] **Step 1.2: 写一个 RED 测试，证明“不声明 validation 的自定义 parser”是目标状态**

推荐放在 `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`，新增一个 parser test double，形态类似：

```swift
private struct IntegMockParsingInterceptor: iNtkResponseParser {
    @NtkActor
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        return NtkResponse<Bool>(
            code: response.code,
            data: true,
            msg: response.msg,
            response: response.response,
            request: response.request,
            isCache: response.isCache
        )
    }
}
```

并新增一条 runtime integration test，类似：

```swift
@Test
func customParserWithoutValidationRequirementStillWorks() async throws {
    let network = NtkNetwork<Bool>.with(
        IntegJSONClient(data: try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ])),
        request: IntegDummyRequest(path: "/integration/custom-parser-no-validation"),
        responseParser: IntegMockParsingInterceptor()
    )

    let response = try await network.request()
    #expect(response.data == true)
}
```

这条测试的 RED 重点不是“业务行为失败”，而是“当前协议 requirement 仍阻止目标 parser 形态成立”。

- [ ] **Step 1.3: 运行受影响测试，验证当前状态无法满足目标**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected:
- 在删除协议 requirement 前，新的“不声明 validation”的 parser conformer 无法通过编译，或测试无法通过当前实现状态。
- 失败原因必须与本次协议收口目标直接相关，而不是拼写或无关错误。

- [ ] **Step 1.4: 记录 RED 结果，不做红态提交**

在实现记录中明确写下：
- 当前失败点是协议 requirement 阻止目标 parser 形态成立
- 该 RED 仅用于锁定协议阻塞点，不进入红态 git commit
- 完成记录后立即进入协议删除步骤，避免编译失败状态停留过久

---

## Task 2: 删除协议 requirement 并同步修正文档注释（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 2.1: 删除 `iNtkResponseParser.validation` 协议要求**

修改 `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift`，删除：

```swift
var validation: iNtkResponseValidation { get }
```

确保协议只保留：

```swift
@NtkActor
func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse
```

- [ ] **Step 2.2: 同步修正协议注释**

删除或改写所有暗示“parser 持有自己的 validation”的说明，特别是：

- `/// 响应验证器`
- `/// parser 持有自己的 validation，无需通过 context 传递`

保留关于 parser 作为解析器、以及 `NtkResponseParserBox` 包装逻辑的说明，但不要继续暗示 validation 是协议职责。

- [ ] **Step 2.3: 运行 integration 子集，确认协议收口测试转绿**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected:
- 新增的“无 validation 成员 parser 仍可接入”测试 PASS
- 不出现新的协议层编译错误

- [ ] **Step 2.4: 提交协议层收口变更**

```bash
git add Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift \
        Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift
git commit -m "refactor: remove parser validation requirement"
```

---

## Task 3: 先检索 blast radius，再建立行为不变性覆盖矩阵并收紧 `NtkDataParsingInterceptor` 公开表面（GREEN）

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 3.1: 在删除公开属性前先检索 blast radius**

在修改 `NtkDataParsingInterceptor` 前，先全仓检索以下读取点与残留描述：

- `NtkDataParsingInterceptor.validation`
- `parser.validation`
- `var validation: iNtkResponseValidation { get }`
- 注释/示例中“parser 持有 validation”的描述

验收标准：
- 明确当前仓内是否存在对 `NtkDataParsingInterceptor.validation` 的直接读取依赖
- 若存在，先把这些读取点纳入改动清单，再继续删除公开属性

- [ ] **Step 3.2: 建立 spec 行为不变性覆盖矩阵**

在动生产代码前，先把 spec 中的 7 条行为不变性逐项映射到现有测试：

- 正常 decode + validation pass -> 对应测试名
- validation fail -> 对应测试名
- `data == nil` + validation pass -> 对应测试名
- `data == nil` + validation fail -> 对应测试名
- `NtkNever` -> 对应测试名
- headerRecovered / unrecoverableDecodeFailure -> 对应测试名
- typed passthrough -> 对应测试名

优先从 `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift` 建立这张矩阵。

- [ ] **Step 3.3: 对矩阵空白项先补测试，再运行基线**

如果矩阵中有任一行为没有现成覆盖，先补对应测试。

然后运行：

```bash
swift test --filter NtkDataParsingInterceptorTests
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected:
- 在修改 `NtkDataParsingInterceptor` 前，现有行为基线全部可验证
- 若有新增测试，它们先在旧实现下锁定当前语义

- [ ] **Step 3.4: 删除 `NtkDataParsingInterceptor.public let validation`**

修改 `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`：

删除：

```swift
public let validation: iNtkResponseValidation
```

并将 init 中的 `validation` 只用于构造 policy，例如保持：

```swift
self.policy = NtkDefaultResponseParsingPolicy(
    validation: validation,
    dispatcher: dispatcher
)
```

不要改变：
- init 参数列表
- `intercept` 主流程
- `policy` 的构造时机与使用方式

- [ ] **Step 3.5: 确认 parser 本体不再直接暴露或持有 validation 状态**

如果删除公开属性后不再需要额外存储 `validation`，则不要保留私有冗余字段。

验收标准：
- parser 内部不再有单独的 `validation` stored property
- `validation` 只作为 init 输入转交给 policy

- [ ] **Step 3.6: 运行 parsing 相关 focused tests，验证行为未漂移**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected:
- 所有既有 parsing 行为测试 PASS
- 行为不变性矩阵中的每一项都仍然成立

- [ ] **Step 3.7: 提交 parser 表面收口变更**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift \
        Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift \
        Tests/CooNetworkTests/NtkNetworkExecutorTests.swift \
        Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift
git commit -m "refactor: hide parser validation state"
```

---

## Task 4: 先检索读取点，再清理所有 conformer 的无效 `validation` 属性（GREEN）

**Files:**
- Modify: `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- Modify: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Modify: `Examples/PodExample/PodExample/TestModels.swift`
- Modify: `Examples/PodExample/PodExample/ViewController.swift`
- Search sweep: all remaining `iNtkResponseParser` conformers and API read sites in repo

- [ ] **Step 4.1: 全仓检索 conformer、读取点和文本残留**

使用代码搜索列出以下三类结果，并形成最终处理清单：

1. 所有实现 `iNtkResponseParser` 的类型
2. 所有对以下表面的直接读取或依赖点：
   - `parser.validation`
   - `NtkDataParsingInterceptor.validation`
   - `var validation: iNtkResponseValidation { get }`
3. 所有仍描述“parser 持有 validation”的注释/示例文本

至少确认这些位置：
- `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`
- `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- `Examples/PodExample/PodExample/TestModels.swift`
- `Examples/PodExample/PodExample/ViewController.swift`

交付物：
- 最终处理清单（文件 + 类型/符号 + 删除/保留结论）

- [ ] **Step 4.2: 删除仅为 conform protocol 而存在的 `validation` 属性**

在每个 conformer 中，删除类似：

```swift
let validation: iNtkResponseValidation = ...
```

或：

```swift
var validation: iNtkResponseValidation { ... }
```

判断标准：
- 如果该属性只是为了满足旧协议 requirement，则删除
- 如果该属性仍被实现内部实际使用，则不要恢复协议 requirement，而应转为该类型自己的实现细节

- [ ] **Step 4.3: 修正读取点与文本残留**

如果搜索发现以下残留，逐项修正：
- 对 `iNtkResponseParser.validation` 的直接依赖
- 对 `NtkDataParsingInterceptor.validation` 的直接读取
- 注释/示例中对 parser validation 职责的旧描述

- [ ] **Step 4.4: 运行受影响测试子集与示例验证**

Run:

```bash
swift test --filter NtkNetworkSingleUseTests
swift test --filter NtkNetworkIntegrationTests
swift test --filter NtkNetworkExecutorTests
```

Expected:
- 所有基于自定义 parser 的测试仍通过
- 不再出现“为了 conform protocol 必须声明 validation”的遗留代码

若仓库存在示例工程现成构建命令，必须执行；若当前没有自动化命令，则至少在结果中明确记录：
- 已完成示例源码静态一致性检查
- 示例工程完整编译需作为人工补验项

- [ ] **Step 4.5: 提交 conformer 与读取点清理**

```bash
git add Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift \
        Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift \
        Tests/CooNetworkTests/NtkNetworkExecutorTests.swift \
        Examples/PodExample/PodExample/TestModels.swift \
        Examples/PodExample/PodExample/ViewController.swift
git commit -m "refactor: remove redundant parser validation properties"
```

---

## Task 5: 全量验证与最终收尾

**Files:**
- Verify only: whole repo

- [ ] **Step 5.1: 再次运行关键 focused tests**

说明：当前文件名是 `AFDataParsingInterceptorTests.swift`，但仓内实际 suite 名是 `NtkDataParsingInterceptorTests`；`swift test --filter` 统一以 suite 名为准。

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
swift test --filter NtkNetworkSingleUseTests
swift test --filter NtkNetworkExecutorTests
swift test --filter NtkNetworkIntegrationTests
```

Expected: 全部 PASS。

- [ ] **Step 5.2: 运行全量测试**

Run:

```bash
swift test
```

Expected: 全部 PASS。

- [ ] **Step 5.3: 检查工作区状态**

Run:

```bash
git status
```

Expected:
- 只有本次协议/API 收口相关改动
- 没有遗漏的半成品测试或无关文件

- [ ] **Step 5.4: 如该变更将进入对外发布版本，补充 breaking change 说明**

若此改动后续面向外部发布，需要在 release notes / changelog 中明确标注：
- 删除了 `iNtkResponseParser.validation` 协议 requirement
- 删除了 `NtkDataParsingInterceptor.validation` 公开表面
- 这是源码级 breaking change，但不改变 runtime parsing semantics

---

## Deferred Work (Not In This Plan)

以下内容明确不在本计划中：

- 重设计 `iNtkResponseValidation`
- 将 `NtkDefaultResponseParsingPolicy` 提升为 public protocol
- 调整 parser 的 Acquire / Prepare / Interpret / Decide 阶段结构
- 改动 `NtkNever` / `serviceDataEmpty` / decode failure 的既有行为
- 更大范围的 parsing API 清理或重命名

---

## Verification Checklist

实现完成后，必须满足：

- [ ] `iNtkResponseParser` 不再声明 `validation`
- [ ] `iNtkResponseParser` 注释不再描述 parser 持有 validation
- [ ] `NtkDataParsingInterceptor` 不再公开 `validation`
- [ ] parser 本体不再保留冗余 validation stored property
- [ ] 至少一条测试证明不声明 `validation` 的自定义 parser 仍可接入执行链
- [ ] spec 行为不变性 7 项均已映射到现有测试或新增测试
- [ ] 所有 `iNtkResponseParser` conformer 已完成检索与清理
- [ ] 仓内不存在对 `iNtkResponseParser.validation` 或 `NtkDataParsingInterceptor.validation` 的直接读取依赖，或已全部修复
- [ ] 默认 data parsing 仍由 policy 驱动 validation
- [ ] parsing 相关 focused tests 全部通过
- [ ] 全量 `swift test` 通过
- [ ] 若对外发布，breaking change 说明已补充
