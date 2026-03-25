# parsing

Data parsing feature 子模块。

## 职责

承载响应解析 pipeline 的专属协议、实现与 parsing-only 模型，包括：
- payload 入口归一化与 root gate
- payload transformer / decoder 抽象
- parsing hooks / validation checker
- data parsing interceptor 主流程
- parsing result / default parsing policy
- 内置 payload decoder

## 核心类型

- `NtkDataParsingInterceptor` - 通用响应解析拦截器，负责 parsing pipeline 编排
- `NtkPayload` - parsing pipeline 使用的统一 payload 中间层
- `PayloadRootGate` - payload 顶层结构 gate
- `iNtkResponsePayloadTransforming` - payload 前置改造协议
- `iNtkResponsePayloadDecoding` - payload 解释协议
- `iNtkParsingHooks` - parsing 生命周期观察协议
- `iNtkResponseValidation` - parsing policy 使用的业务成功判定协议
- `NtkParsingResult` - parsing interpret 阶段中间结果
- `NtkDefaultResponseParsingPolicy` - 默认解析裁决策略
- `NtkDataPayloadDecoder` / `NtkJSONObjectPayloadDecoder` - 内置 payload decoder
