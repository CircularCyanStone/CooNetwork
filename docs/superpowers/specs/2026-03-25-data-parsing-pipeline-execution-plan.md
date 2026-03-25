# Data Parsing Pipeline Execution Plan

## 目标

将 `NtkDataParsingInterceptor` 从“解析 + 裁决 + 副作用 + 特判”混合体，重构为稳定的五阶段 parser pipeline，并引入 `policy` 作为唯一执行流裁决层。

执行计划以“先收敛概念，再重构结构，最后验证行为”为原则，避免边做边再次推翻职责边界。

---

## 阶段 1：收敛概念与接口边界

### 目标

在实现前先定清楚各扩展点的角色，避免后续代码重构再次漂移。

### 任务

1. 定义 `iNtkResponseParsingPolicy` 的职责边界与输入/输出契约
2. 定义封闭、穷尽的 parser 中间结果模型
3. 明确 `hooks` 只保留 observer 语义，并写清 hook failure contract
4. 明确 `validation` 的去向：并入 `policy` 或仅作为其内部依赖
5. 明确 `NtkNever`、`nil data`、header fallback 的统一规则
6. 明确 `extractHeader` 留在 `decoder` 的归属理由与边界原则

### 验收标准

- 每个扩展点的职责是单一且互斥的
- 能明确回答“这个规则应放在哪一层”
- `policy` 的输入/输出边界明确且可测试
- 中间结果空间被封闭建模，不依赖散乱 `if/else`
- hook failure 不再可能被误用为控制流信号
- 不再存在 hooks/validation/parser 中央共同裁决的情况

### 产出

- 设计文档
- 接口职责说明
- 中间结果模型草案

---

## 阶段 2：重构 parser 主流程为五阶段

### 目标

将 `NtkDataParsingInterceptor` 收敛为 orchestration object。

### 任务

1. 明确五阶段顺序：Acquire / Prepare / Interpret / Decide / Notify
2. 把 parser 中央硬编码的 `if/else` 规则逐步抽出
3. 引入 parser 中间结果模型
4. 接入 `policy` 作为唯一裁决层
5. 保留 `normalize -> transform -> decode` 主干不变

### 验收标准

- parser 主体只负责阶段编排
- 不再直接裁决 `NtkNever`、`serviceDataEmpty`、validation 结果
- 中央流程从“多分支规则体”变为“固定阶段 orchestrator”

### 涉及文件（预期）

- `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`
- `Sources/CooNetwork/NtkNetwork/iNtk/` 下新增 policy 协议与中间结果模型

---

## 阶段 3：引入 `policy` 并迁移裁决逻辑

### 目标

把所有执行流决定从 parser 中央和分散扩展点中收拢到 `policy`。

### 任务

1. 新增 `iNtkResponseParsingPolicy`
2. 定义 policy 消费的中间结果输入
3. 定义 policy 产出的最终 `ParsingOutcome`（response 或 error）
4. 明确规定 `policy` 不能修改 payload、不能重新 decode、不能做副作用、不能调用 hooks
5. 将以下逻辑迁入 policy：
   - `NtkNever`
   - `nil data` 是否允许
   - retCode success / fail
   - decode fail + header fallback 的处理
6. 让 parser 不再保留这些规则的最终裁决权

### 验收标准

- 所有执行流裁决只有一个出口
- `policy` 的职责边界足够硬，不会退化成新的“大而全 parser`
- 未来新增特殊规则只需扩展 policy，不需修改 parser 主流程
- parser 不再维护隐式成功态 / 失败态分支

---

## 阶段 4：收紧 hooks 为 observer

### 目标

让 `iNtkParsingHooks` 的语义与名字保持一致，不再承担控制流责任。

### 任务

1. 重写 `iNtkParsingHooks` 注释和文档
2. 删除“可吞错/可恢复”的暗示
3. 重新定义通知节点：允许少量中间只读事件与最终结果事件，但不允许任何事件参与裁决
4. 审查现有 hook 触发时机，确保它们是只读观测点，不再承担控制流责任
5. 明确 hook failure contract：默认不影响主流程 outcome，只做日志/监控处理

### 建议的通知时机

- header 已解释完成（只读里程碑）
- 最终成功结果已确定
- 最终失败结果已确定
- 成功流程完成后

### 验收标准

- hooks 不再是隐藏 policy
- 文档与实现一致
- 未来实现 hook 的人不会误以为它能改执行流
- hook failure 不会被重新解释成流程控制信号
- 保留必要观测点的同时，不再引入新的隐式裁决入口

### 涉及文件（预期）

- `Sources/CooNetwork/NtkNetwork/iNtk/iNtkParsingHooks.swift`
- `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`

---

## 阶段 5：处理 `validation` 的归位

### 目标

消除 `validation` 与 parser 中央规则共同裁决的双中心结构。

### 任务

1. 审查 `iNtkResponseValidation` 当前职责
2. 将其并入 `policy`，或降级为 `policy` 的内部依赖
3. 清理旧的 `Bool` 判定路径，避免重复裁决
4. 统一 retCode、empty data、decode fail fallback 的最终出口

### 推荐方向

优先选择：

- 对外不再保留 `validation` 作为独立裁决入口，统一并入 `policy`

如需过渡：

- `validation` 仅作为 `policy` 内部使用的 checker，不再直接由 parser 调用

### 验收标准

- 最终成功/失败判断只存在单一入口
- `validation` 不再和 parser 中央 if/else 并列存在

---

## 阶段 6：处理现有特殊分支

### 目标

把当前最容易导致设计反复推翻的特判，全部迁入稳定结构。

### 任务

1. `ResponseData == NtkNever` → 迁入 `policy`
2. `decoderResponse.data == nil` → 迁入 `policy`
3. `serviceDataEmpty` 的触发条件 → 迁入 `policy`
4. decode fail + `extractHeader` fallback → 迁入 `policy`
5. 明确“header-only 可继续/不可继续”的统一规则

### 验收标准

- parser 中央不再显式维护多个特殊成功态/失败态分支
- 特殊规则统一集中，后续新增规则不会再次污染 parser 主流程

---

## 阶段 7：测试与验证

### 目标

验证新分层模型在网络与缓存路径下都稳定、可扩展、无控制流越界。

### 单元测试建议

1. `normalize` 边界
   - Data
   - object
   - array
   - scalar rejection

2. transformer 串行执行
   - 顺序依赖
   - 中途失败
   - 上游结果是否正确传递

3. decoder 行为
   - decode success
   - decode fail
   - `extractHeader` success
   - `extractHeader` unavailable

4. policy 行为
   - 正常 success
   - retCode fail
   - `nil data` 允许/不允许
   - `NtkNever`
   - decode fail with header
   - decode fail without header

5. hooks 行为
   - 只通知
   - 不改变最终结果
   - hook 自身失败时的处理规则明确

### 集成测试建议

1. 网络路径完整解析
2. 缓存路径完整解析
3. decode fail + fallback
4. 空 data 协议
5. `NtkNever` 协议
6. 特殊 retCode 协议

### 回归验证重点

1. parser 优先级仍由框架锁死
2. `loadCache()` 仍只经过 parser 路径
3. hooks 不会偷偷改变最终 outcome
4. 新规则只需改 policy，不需再碰 parser 主流程

---

## 阶段 8：文档与设计决策同步

### 目标

避免未来 code review 再次把“刻意设计”误判为问题。

### 任务

1. 更新相关设计文档
2. 如确认采用该模型，将核心决策写入设计决策记录
3. 明确 parser 扩展模型的术语：
   - transformer = 输入改造
   - decoder = 协议解释
   - policy = 执行流裁决
   - hooks = 旁路副作用

### 验收标准

- 设计文档与代码语义一致
- 后续评审者能通过文档快速理解为何这样分层

---

## 推荐实施顺序

建议按以下顺序实施，避免先改代码再回头修概念：

1. 先完成概念与接口设计确认
2. 再引入中间结果模型与 policy
3. 再重构 parser 主流程
4. 再收紧 hooks 和 validation
5. 最后补测试与更新文档

---

## 风险与控制点

### 风险 1：`policy` 抽象过大，变成新的“大而全 parser”

控制点：

- 明确它只负责裁决，不改 payload，不做副作用，不持有解码逻辑

### 风险 2：`decoder` 和 `policy` 边界重新模糊

控制点：

- 明确 decoder 产出“解释结果”，policy 产出“最终 outcome”

### 风险 3：hooks 继续暗中承担控制流语义

控制点：

- 收紧文档、命名和触发时机，禁止在 hooks 中引入恢复语义

### 风险 4：保留旧 `validation` 后出现双裁决中心

控制点：

- 仅允许 `validation` 作为过渡期内部依赖存在，不能和 policy 并列裁决

---

## 最终验收标准

达到以下条件，视为本次重构完成：

1. `NtkDataParsingInterceptor` 已收敛为五阶段 orchestrator
2. 执行流裁决仅由 `policy` 提供
3. hooks 只承担旁路副作用
4. `validation` 不再是与 parser 中央并列的裁决入口
5. `NtkNever` / `nil data` / fallback 等特判已迁入稳定层
6. 测试覆盖网络路径、缓存路径和关键特判
7. 文档与实现保持一致

---

## 一句话总结

本执行计划的核心，是先用单一 `policy` 固化执行流裁决边界，再围绕它重构 parser 主流程、收紧 hooks 与 validation，最终把 `NtkDataParsingInterceptor` 稳定为一个可长期演进的五阶段 parser pipeline。