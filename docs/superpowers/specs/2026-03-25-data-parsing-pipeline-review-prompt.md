# Review Prompt for Agent

你正在对 CooNetwork 中 `NtkDataParsingInterceptor` 的新设计方案进行技术复核。请不要实现代码，只做设计评审。

## 你的任务

请严格围绕以下目标审阅设计方案与执行计划：

1. 判断该设计是否真正稳定了 parser 扩展模型
2. 判断职责边界是否清晰、是否会再次漂移
3. 判断 `policy` 作为唯一执行流裁决层是否合理
4. 判断 `hooks` 是否应该被彻底收敛为 observer
5. 判断 `validation` 是否应并入 `policy`
6. 判断该设计是否存在新的过度抽象、边界模糊或未来会再次推翻的风险

请给出：

- 你是否赞同该方案（赞同 / 有条件赞同 / 不赞同）
- 关键优点
- 关键风险
- 必须修改的问题
- 可以延后的问题
- 你推荐的最终设计方向

---

## 背景

当前项目是一个 Swift 网络库，`NtkDataParsingInterceptor` 是核心响应解析组件。最近围绕以下文件进行了多轮重构：

- `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`
- `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadDecoding.swift`
- `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadTransforming.swift`
- `Sources/CooNetwork/NtkNetwork/model/NtkPayload.swift`
- `Sources/CooNetwork/NtkNetwork/model/PayloadRootGate.swift`

目前已经初步形成：

- `normalize -> transform -> decode`

但仍存在问题：

- `hooks` 在命名上像 observer，语义上却仍残留控制流暗示
- `validation` 与 parser 中央逻辑共同参与裁决
- `NtkNever`、`serviceDataEmpty`、decode fail fallback 等规则仍硬编码在 parser 中
- 扩展点对执行流的影响缺少统一边界，导致概念反复推翻

当前没有旧版本兼容压力，因此目标不是最小改动，而是选择一个长期稳定、概念清晰、便于未来演进的设计。

---

## 当前推荐设计（待你评审）

采用严格分层方案：

1. `normalize`
2. `transformers`
3. `decoder`
4. `policy`
5. `hooks`

### 各层职责

#### `normalize`
- 只做 payload 入口结构 gate
- 不做业务语义解释

#### `transformers`
- 只改 payload 输入
- 不负责最终裁决

#### `decoder`
- 负责 payload 协议解释
- success path: decode
- failure path: extractHeader
- 不负责最终成功/失败判定

#### `policy`
- 新增层
- 作为唯一允许影响执行流的扩展点
- 统一负责：
  - retCode 成功/失败
  - `NtkNever`
  - `nil data`
  - `serviceDataEmpty`
  - decode fail + header fallback 的最终处理
  - 现有 `validation` 语义

#### `hooks`
- 只保留 observer 语义
- 只做旁路副作用
- 不参与恢复、吞错、改结果

### parser 新定位

`NtkDataParsingInterceptor` 只作为五阶段 orchestrator：

1. Acquire
2. Prepare
3. Interpret
4. Decide
5. Notify

其中只有 `Decide` 阶段能改变最终执行流，并且该能力被 `policy` 独占。

---

## 设计文档路径

请阅读以下文档后再评审：

1. 设计方案：
`/Users/coo/Desktop/CooLibrarys/CooNetwork/docs/superpowers/specs/2026-03-25-data-parsing-pipeline-design.md`

2. 执行计划：
`/Users/coo/Desktop/CooLibrarys/CooNetwork/docs/superpowers/specs/2026-03-25-data-parsing-pipeline-execution-plan.md`

---

## 重点复核问题

请重点回答以下问题：

1. **`policy` 独占执行流裁决权是否是最优选择？**
   - 是否足够清晰
   - 是否会变成新的“大而全组件”
   - 是否需要拆成 success/failure 双 policy

2. **`policy` 的输入/输出契约是否足够封闭、可测试？**
   - 输入是否应统一为封闭的 `ParsingResult`
   - 输出是否应统一为最终 `ParsingOutcome`
   - 边界是否足够严格到不会重新承担 decode / 副作用职责

3. **`hooks` 是否应该彻底收敛为 observer？**
   - 是否还应保留少量改流能力
   - 如果彻底收紧，是否会损失必要扩展性

4. **hook failure contract 是否完整？**
   - hook 失败是否应默认不影响主流程 outcome
   - 是否还存在被误用为流程控制信号的风险

5. **`validation` 是否应并入 `policy`？**
   - 独立保留是否还有合理性
   - 并入后是否更稳定

6. **parser 中间结果模型是否合理？**
   - 是否足够表达 decode success / fail / fallback
   - 是否应使用封闭、穷尽的状态模型
   - 是否还缺关键状态

7. **`extractHeader` 留在 `decoder` 是否合理？**
   - 这是否会让 decoder 职责过宽
   - 是否值得拆到独立组件
   - “解释协议信息”和“裁决最终 outcome”的边界是否足够清晰

8. **这套设计是否真的能避免未来继续反复推翻概念？**
   - 哪些地方仍存在漂移风险
   - 哪些命名或边界仍需要更严格定义

---

## 输出要求

请按以下结构输出：

### 1. 总体结论
- 赞同 / 有条件赞同 / 不赞同
- 一句话总结

### 2. 你认为最正确的地方
- 2~5 条

### 3. 你认为最大的风险
- 2~5 条

### 4. 必须修改的问题
- 如果没有，请明确写“无必须修改项”

### 5. 建议但可延后的问题
- 2~5 条

### 6. 你推荐的最终方向
- 明确说继续沿用当前方案，还是改成别的方案

请避免泛泛而谈，尽量直接针对该设计本身的职责边界、扩展性和长期稳定性给出判断。