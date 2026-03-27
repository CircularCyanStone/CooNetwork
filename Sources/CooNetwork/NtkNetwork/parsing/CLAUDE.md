# parsing

响应解析子模块。

## 职责

承载响应解析流程相关的协议、实现和中间模型，包括：
- payload 顶层结构检查与统一入口
- payload 改造协议与解码协议
- 解析流程中的生命周期通知
- 业务成功判定与默认结果判定
- 数据解析拦截器主流程
- 解析中间结果与内置 payload decoder

## 核心类型

- `NtkDataParsingInterceptor` - 通用响应解析拦截器，负责串联各个解析阶段
- `NtkPayload` - 解析流程使用的统一 payload 中间层
- `PayloadRootGate` - payload 顶层结构检查
- `iNtkResponsePayloadTransforming` - payload 前置改造协议
- `iNtkResponsePayloadDecoding` - payload 解码协议
- `iNtkParsingHooks` - 解析流程中的生命周期通知协议，不参与业务裁决
- `NtkParsingHookDispatcher` - 负责向多个 hooks 分发生命周期通知，不负责结果判定
- `iNtkResponseValidation` - 业务成功判定协议
- `NtkInterpretation` - 解释阶段产生的中间结果，包含 `Decoded` / `DecodeFailure` 两类上下文
- `NtkDefaultResponseParsingPolicy` - 默认解析判定策略，负责结果判定
- `NtkDataPayloadDecoder` / `NtkJSONObjectPayloadDecoder` - 内置 payload decoder
