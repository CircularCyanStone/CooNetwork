# Data Parsing Pipeline Design

## 背景

近期 `NtkDataParsingInterceptor` 周边经历了多轮重构，主要目标是为 parser 提供可扩展能力，并允许扩展点在必要时对执行流产生影响。当前版本已经初步收敛出 `normalize -> transform -> decode` 的主线，但仍存在职责边界不稳定的问题：

- `transformer`、`decoder`、`hooks`、`validation` 与 parser 中央分支共同参与结果形成
- `hooks` 在命名上是观察者，但在实现与注释层面仍残留控制流语义
- `NtkNever`、`serviceDataEmpty`、decode fail fallback 等规则仍被硬编码在 parser 内部
- `validation` 作为独立 `Bool` 判定器，与 parser 内部规则共同参与裁决，导致最终责任边界模糊

由于当前组件没有兼容旧版本的压力，目标不是最小改动，而是一次性建立一个长期稳定、概念清晰、便于扩展的设计。

---

## 设计目标

1. 为 `NtkDataParsingInterceptor` 提供稳定的扩展模型
2. 将“执行流裁决权”集中到单一扩展点，避免职责漂移
3. 保留现有 `normalize -> transform -> decode` 主干结构
4. 将 `hooks` 收敛为纯旁路副作用机制
5. 使 `NtkNever`、`nil data`、header fallback、业务成功判定等特殊规则有固定归属
6. 让 parser 本身回归为 orchestration object，而不是规则汇聚点

---

## 核心结论

采用 **严格分层方案**：

1. `normalize`
2. `transformers`
3. `decoder`
4. `policy`
5. `hooks`

其中：

- `transformer` 只负责改造输入
- `decoder` 只负责解释 payload
- `policy` 是唯一允许影响执行流的扩展点
- `hooks` 只负责旁路副作用
- `NtkDataParsingInterceptor` 只负责阶段编排

这是当前复杂度下最优的设计平衡点：比继续修补现有 parser 更彻底，比拆成 success/failure 双 policy 更克制。

---

## 分层职责

### 1. `NtkPayload.normalize`

职责：

- 作为 payload pipeline 的入口结构 gate
- 接受 `Data`
- 接受顶层 object / array
- 拒绝顶层 scalar

不负责：

- 递归归一化整棵 payload
- 业务语义解释
- 成功失败判断

设计含义：

`normalize` 只定义“什么样的原始响应可以进入 parser pipeline”，不定义“这些结构意味着什么”。

---

### 2. `iNtkResponsePayloadTransforming`

职责：

- 对 payload 内容或结构做前置改造
- 支持解密、解包、结构重写、协议收敛
- 为后续 decoder 提供更合适的输入形态

不负责：

- 最终成功/失败裁决
- 最终错误映射
- 生命周期副作用协调

设计含义：

`transformer` 是主执行流的一部分，但它的能力只限于“改输入”，不裁决结果。

---

### 3. `iNtkResponsePayloadDecoding`

职责：

- 成功路径：将 payload 解释为协议层结果
- 失败路径：在 decode 失败时尽量 `extractHeader`

正式定位：

> `decoder` 是 payload 的协议解释器，既负责成功路径的强解码，也负责错误路径的最小 header 恢复。

不负责：

- 判断 `nil data` 是否允许
- 决定 retCode 是否放行
- 决定最终抛出的领域错误

设计含义：

`decoder` 负责“读懂协议”，但不负责“决定命运”。

#### `extractHeader` 为什么仍属于 `decoder`

边界原则如下：

- 只要某段逻辑在回答“从 payload 中还能解释出什么协议信息”，它属于 `decoder`
- 一旦逻辑开始回答“这些信息最终意味着返回什么结果 / 抛什么错误”，它就属于 `policy`

因此，`extractHeader` 仍是解释阶段的一部分，而不是裁决阶段的一部分。
它的职责是尽量恢复协议头信息，不负责决定 fallback 之后的最终 outcome。

---

### 4. `iNtkResponseParsingPolicy`

职责：

- 作为唯一允许影响执行流的扩展点
- 基于解析中间结果输出最终 response 或最终 error
- 统一承接原本分散在 parser 中央的裁决逻辑

它负责处理：

- `NtkNever`
- `serviceDataEmpty`
- 业务 retCode success / fail
- decode fail + header fallback 的最终落地
- 当前 `validation` 的业务成功语义

设计含义：

`policy` 是 parser 中唯一的裁决中心。所有“接下来应该返回什么 / 抛什么”的决定都只能由它给出。

#### `policy` 的硬边界

`policy` 的输入必须是 parser 的统一中间结果模型，输出必须是最终 `ParsingOutcome`：要么返回最终 response，要么返回最终 error。

`policy` **只能做**：

- 基于已解释完成的中间结果做业务裁决
- 统一输出最终 outcome

`policy` **不能做**：

- 不能修改 payload
- 不能重新 decode
- 不能做副作用
- 不能调用 hooks
- 不能回跳到 parser 的前置阶段

这个边界必须写死。否则 `policy` 会迅速退化成新的“大而全 parser”。

---

### 5. `iNtkParsingHooks`

职责：

- 埋点
- 日志
- token 持久化
- 广播
- 其他不参与裁决的旁路副作用

不负责：

- 恢复失败
- 吞掉 validation error
- 改变成功/失败判定
- 改变最终错误类型

设计含义：

`hooks` 是 observer，不是 control point。

#### hook failure contract

必须明确：

- hook 失败默认**不影响主流程的最终 outcome**
- hook 错误应作为日志、监控或调试信息处理，而不是流程控制信号
- 不允许借 hook failure 触发恢复、吞错或改写最终结果

这意味着：

- hooks 可以观测**少量中间里程碑**（例如 header 已解释完成）以及最终 outcome
- 这些观测点必须是**只读通知**，不能反向影响 parser / policy 的裁决
- hook 自身异常的处理策略必须与业务裁决彻底隔离

如果未来有极少数需要“失败必须上抛”的旁路逻辑，它也不应继续放在 `hooks` 语义下，而应显式设计为新的主流程组件。

---

## `NtkDataParsingInterceptor` 的新定位

`NtkDataParsingInterceptor` 应明确定位为：

> parser pipeline orchestrator

它只负责固定顺序的阶段编排，不再内部维护多个散落规则分支。

---

## 推荐的五阶段模型

### Phase 1: Acquire

- `next.handle(context:)`
- 确认下游返回的是 `NtkClientResponse`

### Phase 2: Prepare

- `NtkPayload.normalize(from:)`
- 依次执行 `transformers`

### Phase 3: Interpret

- `decoder.decode(...)`
- decode 失败时尝试 `extractHeader(...)`

### Phase 4: Decide

- 将解析结果交给 `policy`
- 由 `policy` 统一给出最终 response 或最终 error

### Phase 5: Notify

- 在有限的只读里程碑与最终结果节点通知 `hooks`
- `hooks` 可观测中间事件，但不能影响最终 outcome

这个五阶段模型的目标是：

- 每个阶段只有一个明确目的
- 任何新增能力都能找到稳定落点
- parser 不再成为临时规则汇聚点

---

## 解析中间结果模型

为避免 parser 内继续散落 `if/else`，建议引入 **封闭、穷尽** 的 parser 中间结果模型，而不是松散字段集合。

推荐统一术语：

- `ParsingResult`：Interpret 阶段产物
- `ParsingOutcome`：Decide 阶段产物

### `ParsingResult` 必须覆盖的封闭状态

#### 1. Decode 成功态

应包含：

- `code`
- `msg`
- `data`
- `request`
- `clientResponse`
- `isCache`

#### 2. Decode 失败但成功提取 header

应包含：

- `decodeError`
- `rawPayload`
- `extractedHeader`
- `request`
- `clientResponse`
- `isCache`

#### 3. Decode 失败且无法提取 header

应包含：

- `decodeError`
- `rawPayload`
- `request`
- `clientResponse`
- `isCache`

设计原则：

- 结果空间必须被显式建模，而不是靠后续 `if/else` 临时判别
- parser 只负责产生 `ParsingResult`
- `policy` 只消费 `ParsingResult` 并产出最终 `ParsingOutcome`
- parser 本体不再维护 `NtkNever` / `nil data` / fallback 这些隐式成功态与失败态分支

这样做的目标不是多一层类型，而是防止 parser 未来重新长出散乱条件分支。

---

## 需要迁移到 `policy` 的现有逻辑

以下逻辑不应再写死在 `NtkDataParsingInterceptor` 内部：

1. `ResponseData == NtkNever`
2. `decoderResponse.data == nil` 时是否抛 `serviceDataEmpty`
3. `validation.isServiceSuccess`
4. decode fail 后 header fallback 如何映射最终错误

这些规则都属于“裁决”，不是“解释”或“改造”。

---

## 对 `validation` 的处理建议

当前 `iNtkResponseValidation` 是独立的 `Bool` 判定器，但其本质属于结果裁决的一部分。

推荐方案：

- 对外不再保留 `validation` 作为独立裁决入口
- 将其业务语义并入 `policy`
- 如需平滑过渡，仅允许其作为 `policy` 的内部 checker 存在，而不是与 parser 中央并列存在

理由：

- 如果继续保留独立 `validation`，裁决责任会再次分裂
- `nil data`、`NtkNever`、header fallback 等规则无法自然归入 `Bool` 校验器
- 统一到 `policy` 后，所有最终判断只经过一个出口

---

## 推荐保留 / 收紧 / 新增项

### 保留

- `NtkPayload`
- `PayloadRootGate`
- `iNtkResponsePayloadTransforming`
- `iNtkResponsePayloadDecoding`
- `extractHeader`

### 收紧或重做

- `iNtkParsingHooks`
- `iNtkResponseValidation`
- `NtkDataParsingInterceptor` 中对 `NtkNever` / `serviceDataEmpty` / validation 的硬编码

### 新增

- `iNtkResponseParsingPolicy`
- parser 中间结果模型

---

## 预期收益

### 1. 概念稳定

未来新增规则都有固定落点：

- 改 payload → transformer
- 解释 payload → decoder
- 改执行流 → policy
- 副作用 → hooks

### 2. parser 结构变干净

`NtkDataParsingInterceptor` 回归阶段编排角色，不再成为规则垃圾桶。

### 3. 特殊场景有稳定归属

- 空 data 成功接口
- `NtkNever`
- 特殊 retCode
- decode fail fallback

这些场景都不再需要重新推翻整体模型。

### 4. 更适配当前“无兼容包袱”的状态

既然当前没有旧版本兼容压力，就应该一次把职责边界切干净，而不是继续在现有 parser 内打补丁。

---

## 不推荐的替代方案

### 方案 B：success / failure 双 policy

优点：

- 错误路径更显式
- 复杂协议场景更细致

缺点：

- 当前复杂度下偏过度设计
- 增加理解和使用成本
- 作为第一步不够克制

结论：

不建议作为当前版本的首选方案。

### 方案 C：保留现有 parser 骨架，只收紧 hooks

优点：

- 改动小
- 止血快

缺点：

- parser 中央硬编码仍然存在
- `NtkNever` / `nil data` / validation 归属仍模糊
- 后续仍容易继续推翻设计

结论：

只能算止血，不是长期稳定方案。

---

## 最终结论

推荐将 `NtkDataParsingInterceptor` 重构为五阶段 parser pipeline：

- Acquire
- Prepare
- Interpret
- Decide
- Notify

其中：

- `Decide` 由新增的 `iNtkResponseParsingPolicy` 独占
- `transformer` 只改输入
- `decoder` 只解释 payload
- `hooks` 只做旁路副作用
- `validation` 统一迁入 `policy`

这套方案能最大程度避免未来继续在 parser 扩展模型上反复推翻概念。