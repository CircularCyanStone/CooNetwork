# Remove Parser Validation Requirement Design

## 背景

当前 parsing 重构已经把 `validation` 的实际业务裁决职责收口到 `NtkDefaultResponseParsingPolicy`，`NtkDataParsingInterceptor` 仅负责 `Acquire -> Prepare -> Interpret -> Decide` 的流程编排。

但协议层和实现表面仍残留旧结构：

- `iNtkResponseParser` 仍要求实现 `var validation: iNtkResponseValidation { get }`
- `NtkDataParsingInterceptor` 仍公开 `public let validation`
- 若干测试/示例 parser 仍为了 conform 协议而声明 `validation`

这会制造错误的职责暗示：看起来 parser 仍然拥有 validation 责任，但当前运行时实际并非如此。

## 问题定义

当前问题不是 `validation` 是否还存在，而是它是否还应作为 **parser 协议契约** 和 **parser 公开表面** 存在。

经代码链路核对：

1. `NtkDataParsingInterceptor` 不再直接读取 `self.validation` 做运行时判断
2. `validation` 的真实运行时业务裁决消费方已经收口到 `NtkDefaultResponseParsingPolicy`；`NtkDataParsingInterceptor` 当前仅保留构造期传递与表面暴露
3. `NtkResponseParserBox`、`NtkNetwork` 等框架路径没有任何地方读取 `parser.validation`
4. 多个自定义 parser 的 `validation` 已沦为“为了 conform protocol 才存在”的死要求

因此，`iNtkResponseParser.validation` 已经不是必要协作契约，而是历史包袱。

## 设计目标

1. 让 parser 协议只保留真正参与运行时协作的能力
2. 把 `validation` 的职责表达彻底收口到 policy
3. 删除仅用于 conform protocol 的无效属性
4. 在不引入兼容层的前提下完成最干净的 API 收口
5. 保证解析行为、错误语义和现有测试语义不变

## 非目标

本次不处理以下内容：

- 不重设计 `iNtkResponseValidation`
- 不引入新的 public policy protocol
- 不调整 parser 的主流程阶段结构
- 不改变 validation failure / decode failure / serviceDataEmpty 的现有行为
- 不做与本次职责收口无关的 parsing API 清理

## 方案选型

### 方案 A：只删除协议要求

删除 `iNtkResponseParser.validation`，但保留 `NtkDataParsingInterceptor.public let validation`。

**优点：** 改动最小。
**缺点：** parser 公开表面仍残留错误职责暗示，收口不彻底。

### 方案 B：协议与 parser 表面一起收紧（采用）

- 删除 `iNtkResponseParser.validation`
- 删除 `NtkDataParsingInterceptor.public let validation`
- 保留 init 参数 `validation`，但仅作为构造 policy 的内部输入
- 删除所有仅为 conform protocol 而存在的 `validation` 实现

**优点：** 职责表达最一致、最干净。
**缺点：** 需要同步修复所有 conformer；这是一次源码级 API breaking change：外部若依赖 `iNtkResponseParser.validation` 或直接读取 `NtkDataParsingInterceptor.validation`，将需要同步迁移。当前无兼容压力，可接受。

### 方案 C：保留协议属性并标记过渡废弃

保留 `iNtkResponseParser.validation`，只通过注释或 deprecated 说明它将来删除。

**优点：** 兼容性最保守。
**缺点：** 持续保留无效契约，继续误导职责边界。

## 采用方案

采用 **方案 B**。

理由：

1. 当前项目确认还无人使用，没有公开 API 兼容压力
2. 运行时语义已经完成迁移，协议面应该同步对齐
3. 若继续保留 parser.validation，会继续制造“parser 仍负责 validation”的错误认知
4. 本次调整属于职责收口，不应引入过渡层或兼容包袱

## 具体设计

### 1. 协议层变更

修改 `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift`：

- 删除 `var validation: iNtkResponseValidation { get }`
- 保留 `intercept(context:next:)` 作为唯一协议要求

调整后，`iNtkResponseParser` 表达的能力将只剩“如何接收上下文并产出解析结果”。

### 2. parser 实现层变更

修改 `Sources/CooNetwork/NtkNetwork/parsing/NtkDataParsingInterceptor.swift`：

- 删除 `public let validation`
- 保留现有 init 参数 `validation`
- 在 init 内直接用该参数创建 `NtkDefaultResponseParsingPolicy`
- parser 本体不再暴露 validation 状态

这可以保持现有外部构造方式不变，同时删除 parser 表面的错误职责暗示。

### 3. conformer 清理

修改所有实现 `iNtkResponseParser` 的自定义类型：

- 删除仅用于 conform protocol 的 `validation` 属性
- 若某个实现内部确实仍需使用 validation，可改为私有实现细节，而不是协议要求
- 以全仓 `iNtkResponseParser` conformer 检索结果为准逐项清理，并在实现提交中列出最终处理清单

预期受影响位置包括：

- `Tests/CooNetworkTests/NtkNetworkSingleUseTests.swift`
- `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`
- `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- `Examples/PodExample/PodExample/TestModels.swift`
- `Examples/PodExample/PodExample/ViewController.swift`
- 以及仓库中其他通过检索发现的自定义 parser conformer

### 4. 文档注释同步

修改 `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseParser.swift` 的协议注释：

- 移除“parser 持有自己的 validation，无需通过 context 传递”这类表述
- 让注释与当前职责保持一致，即 parser 协议只表达拦截/解析能力
- 检查示例注释，避免继续暗示 parser 必须提供 `validation`

### 5. policy 职责保持不变

`NtkDefaultResponseParsingPolicy` 继续持有并消费 `validation`：

- 保持 `validation.isServiceSuccess(...)`
- 保持 validation failure 抛出 `.validation`
- 保持 `NtkNever` / `serviceDataEmpty` / headerRecovered 等既有语义
- `NtkDataParsingInterceptor` 对 `validation` 的剩余角色仅是构造输入承接，不承担运行时判定职责

也就是说，本次只做 **职责表达收口**，不改 **行为语义**。

## 行为不变性要求

实现后必须保持以下行为不变：

1. 正常 decode + validation pass 仍返回成功响应
2. validation fail 仍抛出 `NtkError.validation`
3. `data == nil` + validation pass 仍抛出 `NtkError.serviceDataEmpty`
4. `data == nil` + validation fail 仍优先抛出 `NtkError.validation`
5. `NtkNever` 分支行为不变
6. headerRecovered / unrecoverableDecodeFailure 分支行为不变
7. typed passthrough 行为不变

## 测试策略

本次采用最小 TDD 回归策略：

1. 先补或确认一组能覆盖行为不变性的测试
2. 删除协议属性与公开属性
3. 修复 conformer 编译错误
4. 先跑 focused tests，确认行为未漂移
5. 再跑一次全量 `swift test` 兜底协议/API 影响面

重点测试集：

- `NtkDataParsingInterceptorTests`
- `NtkNetworkExecutorTests`
- `NtkNetworkIntegrationTests`
- `NtkNetworkSingleUseTests`

除现有行为测试外，需补一条协议收口回归测试，明确证明：

- 一个**不声明 `validation` 成员**的自定义 `iNtkResponseParser` 仍可正常 conform 协议
- 该自定义 parser 仍可通过 `NtkNetwork` / executor 正常接入执行链
- 删除 `iNtkResponseParser.validation` 后，默认 data parsing 仍由 policy 驱动 validation

如 CI 或本地验证流程覆盖示例工程编译，也应把 `Examples` 的编译可用性纳入检查。

## 风险与控制

### 风险 1：遗漏某个 conformer

**表现：** 编译失败。
**控制：** 全量检索 `iNtkResponseParser` conformer 并逐个清理。

### 风险 2：public API 收紧带来源码级 breaking change

**表现：** 外部若依赖 `iNtkResponseParser.validation` 或直接读取 `NtkDataParsingInterceptor.validation`，会编译失败。
**控制：** 当前仓库检索未发现直接读取点，且当前项目确认无人使用、无兼容压力；若后续对外发布，应在变更说明中明确标注该 breaking change。

### 风险 3：协议注释或示例说明与实现脱节

**表现：** 代码已删除 validation requirement，但注释或示例仍暗示 parser 必须持有 validation。
**控制：** 同步修正 `iNtkResponseParser` 注释，并检查示例代码/说明文本的一致性。

### 风险 4：误删后改变运行时行为

**表现：** validation / parsing 相关测试失败。
**控制：** 仅做协议和表面 API 收口，不改 policy 逻辑；通过 focused tests + 全量测试验证。

## 验收标准

完成后应满足：

- [ ] `iNtkResponseParser` 不再声明 `validation`
- [ ] `iNtkResponseParser` 协议注释不再描述 parser 持有 validation
- [ ] `NtkDataParsingInterceptor` 不再公开 `validation`
- [ ] 所有 parser conformer 不再因协议要求而声明无效 `validation`
- [ ] 至少一条回归测试证明“不声明 validation 的自定义 parser”仍可正常接入执行链
- [ ] `validation` 的真实运行时业务裁决消费方仍然只在 policy 中
- [ ] parsing 相关核心测试全部通过
- [ ] 全量 `swift test` 通过
- [ ] 若后续面向外部发布，本次 public API 收紧已在变更说明中标注

## 最终结论

本次改动应将 `validation` 从 **parser 协议契约** 和 **parser 公开表面** 中完全移除，只保留其作为 policy 内部依赖的角色。

这样可以让当前 parsing 架构的职责表达与真实运行时语义保持一致：

- parser 负责 orchestration
- policy 负责 decision 与 validation
- `validation` 不再作为历史包袱泄漏到 parser 协议层
