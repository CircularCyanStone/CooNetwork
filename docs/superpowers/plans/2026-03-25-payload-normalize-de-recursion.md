# Payload Normalize 去递归化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 去掉 `StrictPayloadNormalizer` 的默认全树递归归一化，只保留顶层结构 gate，消除大列表 payload 的默认递归性能开销，同时保证现有 payload pipeline 主流程不回归。

**Architecture:** 保留 `NtkPayload` 的 `.data / .dynamic` 模型与 `NtkDataParsingInterceptor` 的 normalize → transform → decode 执行流不变。将 `StrictPayloadNormalizer` 收敛为仅处理顶层 root 的轻量 gate，删除深层节点递归 normalize 和 `NtkDynamicData.strictObject/strictArray` 这条中间往返路径；测试改为验证顶层 gate 仍成立、默认递归已移除、decoder 主路径仍可工作。

**Tech Stack:** Swift 6.1 / SwiftPM / Foundation / Swift Testing (`import Testing`)

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/model/StrictPayloadNormalizer.swift` | 删除默认全树递归归一化，改为顶层 object/array gate 与浅桥接 |
| `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift` | 删除 `strictObject` / `strictArray` |
| `Sources/CooNetwork/NtkNetwork/model/NtkPayload.swift` | 更新 normalize 注释，明确仅做顶层结构校验 |
| `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift` | 调整用例，移除“深层严格归一化”预期，新增“深层 Foundation 值未被预处理”验证 |
| `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift` | 保留 decoder 主路径回归验证 |

---

### Task 1: 调整 payload normalize 实现

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/model/StrictPayloadNormalizer.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkDynamicData.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkPayload.swift`

- [ ] **Step 1: 修改 `StrictPayloadNormalizer`，删除递归 normalize 逻辑**
- [ ] **Step 2: 删除 `NtkDynamicData.strictObject/strictArray`**
- [ ] **Step 3: 更新 `NtkPayload.normalize(from:)` 注释，明确只做顶层 gate**
- [ ] **Step 4: 运行构建验证实现可编译**

### Task 2: 调整测试以匹配新语义

**Files:**
- Modify: `Tests/CooNetworkTests/NtkPayloadNormalizationTests.swift`
- Verify: `Tests/CooNetworkTests/NtkPayloadDecoderTests.swift`

- [ ] **Step 1: 删除依赖深层递归严格化的旧测试预期**
- [ ] **Step 2: 增加“深层 NSNumber 保持 Foundation 形态、未被入口预处理”的测试**
- [ ] **Step 3: 保留并运行 decoder 回归测试**
- [ ] **Step 4: 运行 payload normalization 相关测试并确认通过**

### Task 3: 完整验证

**Files:**
- Verify only

- [ ] **Step 1: 运行 `swift test --filter NtkPayloadNormalizationTests`**
- [ ] **Step 2: 运行 `swift test --filter NtkPayloadDecoderTests`**
- [ ] **Step 3: 运行 `swift test` 全量回归**
- [ ] **Step 4: 检查工作区 diff，确认只包含本次目标改动**

---

## Verification Checklist

- [ ] `StrictPayloadNormalizer` 不再递归遍历整棵 payload
- [ ] `NtkDynamicData` 不再包含 `strictObject/strictArray`
- [ ] `NtkPayload.normalize(from:)` 注释明确仅做顶层结构 gate
- [ ] `NtkPayloadNormalizationTests` 覆盖新的浅 gate 语义
- [ ] `NtkPayloadDecoderTests` 仍然通过
- [ ] `swift test` 全量通过
