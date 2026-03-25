# Parsing Directory Organization Design

## 背景

当前 data parsing 相关代码已经跨越 `iNtk/`、`interceptor/`、`model/` 三个目录：协议、主流程实现、中间结果与 payload gate 被拆散，理解和维护一条 parsing 职责链时需要频繁跨目录跳转。随着 `NtkDataParsingInterceptor` 被重构为包含 transformer / decoder / policy / hooks / validation checker 的完整 parsing pipeline，这组代码已经不再只是“一个拦截器文件”，而是一个清晰的 feature 子域。

## 目标

1. 将 parsing feature 的专属协议、实现与中间模型收拢到单一平级目录
2. 保持通用网络模型与通用基础设施留在原有目录，避免误伤全局边界
3. 只做目录组织调整，不改变 parsing 语义、不新增扩展点、不顺带推进第二阶段 hooks/public policy 设计
4. 通过测试证明迁移仅影响文件组织，不影响行为

## 结论

采用 A 方案：新建 `Sources/CooNetwork/NtkNetwork/parsing/` 平级目录，只搬迁 parsing feature 本身的文件。

### 搬入 `parsing/`

#### parsing 协议
- `iNtkParsingHooks.swift`
- `iNtkResponsePayloadDecoding.swift`
- `iNtkResponsePayloadTransforming.swift`
- `iNtkResponseValidation.swift`

#### parsing 实现
- `NtkDataParsingInterceptor.swift`
- `NtkPayloadDecoders.swift`
- `NtkParsingResult.swift`
- `NtkDefaultResponseParsingPolicy.swift`

#### parsing 专属模型
- `NtkPayload.swift`
- `PayloadRootGate.swift`

### 保持原位

#### 通用模型
- `NtkResponse.swift`
- `NtkClientResponse.swift`
- `NtkReturnCode.swift`
- `NtkDynamicData.swift`
- `NtkNever.swift`
- `NtkResponseDecoder.swift`

#### 通用拦截器基础设施
- `NtkInterceptorContext.swift`
- `NtkInterceptorChainManager.swift`
- `iNtkRequestHandler.swift`
- `NtkCacheInterceptor.swift`

#### 通用抽象协议
- `iNtkRequest.swift`
- `iNtkResponse.swift`
- `iNtkClient.swift`
- `iNtkInterceptor.swift`
- `iNtkResponseParser.swift`

## 为什么不选更彻底的 feature 化方案

不采用“把所有 parsing 相关类型都搬进去”的方案。原因是 `NtkResponse`、`NtkReturnCode`、`NtkDynamicData` 等是全局网络模型，而不是 parsing 私有资产。强行搬迁会把目录整理升级为模块边界重构，改动范围和回撤成本都会明显上升。

## 边界原则

1. **收拢 feature，不重画领域边界**
2. **通用模型不因这次整理改归属**
3. **public API 名称保持不变**
4. **仅修复因目录变化导致的文档、注释与路径说明**

## 影响面

### 需要更新的内容
- 源文件物理路径
- 目录级 `CLAUDE.md` 说明
- 计划/设计文档中提及旧路径的文件说明（如有必要）
- 测试和代码中的路径认知注释

### 不应变化的内容
- 解析语义
- hook failure behavior
- policy 可见性
- 测试行为与对外接口

## 验证策略

迁移后至少验证：

1. `swift test --filter NtkDataParsingInterceptorTests`
2. `swift test --filter NtkNetworkExecutorTests`
3. `swift test --filter NtkNetworkIntegrationTests`
4. `swift test`
5. `swift build`

## 预期收益

1. 按 feature 阅读 parsing 代码时不再跨 `iNtk/`、`interceptor/`、`model/` 来回跳转
2. `parsing/` 成为后续 parsing 演进的单一落点
3. 保持通用模型层稳定，不把目录整理演变成领域重构

## 风险与控制

### 风险 1：迁移扩大为大重构
控制：严格只搬 parsing feature 专属文件，不碰通用模型归属。

### 风险 2：路径迁移引入漏改
控制：先补/依赖现有 parser、executor、integration 回归测试，再全量跑 `swift test` 与 `swift build`。

### 风险 3：目录说明与代码不一致
控制：同步更新相关 `CLAUDE.md`，明确 `parsing/` 的职责与边界。
