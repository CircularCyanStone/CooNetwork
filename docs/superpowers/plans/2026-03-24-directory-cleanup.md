# NtkNetwork 目录整理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 NtkNetwork 目录中文件位置和命名不一致的问题，使目录语义清晰、命名规范一致。

**Architecture:** 逐步移动文件并更新对应 CLAUDE.md 索引，每步独立可验证。不修改任何逻辑，只做文件搬移和重命名，拆分混合职责文件。

**Tech Stack:** Swift 6, Swift Package Manager

---

## 变更文件总览

### Task 1：将 `NtkRequestConfiguration` 从 `iNtk/` 移到 `cache/`

- Delete: `Sources/CooNetwork/NtkNetwork/iNtk/NtkRequestConfiguration.swift`
- Create: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestConfiguration.swift`（内容完全相同）
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/CLAUDE.md`

### Task 2：重命名 `interceptor/NtkRequestHandler.swift` → `iNtkRequestHandler.swift`

- Delete: `Sources/CooNetwork/NtkNetwork/interceptor/NtkRequestHandler.swift`
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift`（内容相同，更新文件头注释中的文件名）
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`

### Task 3：从 `iNtkDecoderBuilding.swift` 拆出具体实现

- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkDecoderBuilding.swift`（保留协议 + `NtkExtractedHeader`，删除两个 Builder 实现）
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDecoderBuilders.swift`（含 `NtkDataDecoderBuilder` + `NtkJsonObjectDecoderBuilder`）
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`

### Task 4：将 `model/NtkResponse.swift` 拆分为多个单职责文件

- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkResponse.swift`（只保留 `NtkResponse<T>`）
- Create: `Sources/CooNetwork/NtkNetwork/model/NtkResponseDecoder.swift`（含 `iNtkResponseMapKeys` + `NtkCodingKeys` + `NtkResponseDecoder`）
- Modify: `Sources/CooNetwork/NtkNetwork/model/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`（移除 `iNtkResponseMapKeys` 条目，因其实际定义在 `model/`）

---

## Task 1：将 `NtkRequestConfiguration` 移到 `cache/`

**文件：**
- Delete: `Sources/CooNetwork/NtkNetwork/iNtk/NtkRequestConfiguration.swift`
- Create: `Sources/CooNetwork/NtkNetwork/cache/NtkRequestConfiguration.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/cache/CLAUDE.md`

**理由：** `iNtk/` 是纯协议层，`NtkRequestConfiguration` 是缓存策略的具体配置 struct，语义上属于 `cache/` 模块，且 `cache/CLAUDE.md` 已将其列为 cache 模块类型。

- [ ] **Step 1：将文件内容复制到 cache/ 目录**

```bash
cp 'Sources/CooNetwork/NtkNetwork/iNtk/NtkRequestConfiguration.swift' \
   'Sources/CooNetwork/NtkNetwork/cache/NtkRequestConfiguration.swift'
```

- [ ] **Step 2：从 iNtk/ 删除原文件**

```bash
rm 'Sources/CooNetwork/NtkNetwork/iNtk/NtkRequestConfiguration.swift'
```

- [ ] **Step 3：更新 `iNtk/CLAUDE.md`，删除对 NtkRequestConfiguration 的引用**

从 `iNtk/CLAUDE.md` 的核心协议列表中删除这一条（如有）。

- [ ] **Step 4：更新 `cache/CLAUDE.md`，确认 NtkRequestConfiguration 已列入**

确认 `cache/CLAUDE.md` 中有：`NtkRequestConfiguration - 缓存策略配置`（已存在，无需改动）。

- [ ] **Step 5：编译验证**

```bash
cd /Users/coomini/Desktop/CooLibraries/CooNetwork && swift build 2>&1 | tail -20
```

期望：`Build complete!`

- [ ] **Step 6：Commit**

```bash
git add -A
git commit -m "refactor: move NtkRequestConfiguration from iNtk/ to cache/"
```

---

## Task 2：重命名 `NtkRequestHandler.swift` → `iNtkRequestHandler.swift`

**文件：**
- Delete: `Sources/CooNetwork/NtkNetwork/interceptor/NtkRequestHandler.swift`
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`

**理由：** 文件内部定义的类型是 `public protocol iNtkRequestHandler`，文件名缺少 `i` 前缀，与项目所有协议文件命名规范不符（`iNtkClient.swift`、`iNtkInterceptor.swift` 等）。

- [ ] **Step 1：复制文件，使用新名称**

```bash
cp 'Sources/CooNetwork/NtkNetwork/interceptor/NtkRequestHandler.swift' \
   'Sources/CooNetwork/NtkNetwork/interceptor/iNtkRequestHandler.swift'
```

- [ ] **Step 2：更新新文件头部注释中的文件名**

将 `iNtkRequestHandler.swift` 开头的注释从：
```swift
// RequestHandler.swift
```
改为：
```swift
// iNtkRequestHandler.swift
```

- [ ] **Step 3：删除旧文件**

```bash
rm 'Sources/CooNetwork/NtkNetwork/interceptor/NtkRequestHandler.swift'
```

- [ ] **Step 4：更新 `interceptor/CLAUDE.md`，将条目 `NtkRequestHandler` 改为 `iNtkRequestHandler`**

将 CLAUDE.md 中 `NtkRequestHandler - 请求处理器协议实现` 的条目改为 `iNtkRequestHandler - 请求处理器协议（iNtkRequestHandler）`。

- [ ] **Step 5：编译验证**

```bash
cd /Users/coomini/Desktop/CooLibraries/CooNetwork && swift build 2>&1 | tail -20
```

期望：`Build complete!`

- [ ] **Step 6：Commit**

```bash
git add -A
git commit -m "refactor: rename NtkRequestHandler.swift to iNtkRequestHandler.swift"
```

---

## Task 3：将具体 Builder 实现从 `iNtkDecoderBuilding.swift` 移至 `interceptor/`

**文件：**
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkDecoderBuilding.swift`（删除两个 Builder struct）
- Create: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDecoderBuilders.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`

**理由：** `iNtk/` 应只含协议和最小辅助类型。`NtkDataDecoderBuilder`、`NtkJsonObjectDecoderBuilder` 是协议的具体实现，与 `NtkDataParsingInterceptor` 强关联，属于 `interceptor/` 模块。

- [ ] **Step 1：创建 `interceptor/NtkDecoderBuilders.swift`**

新文件包含从 `iNtkDecoderBuilding.swift` 迁移过来的两个 struct：

```swift
//
//  NtkDecoderBuilders.swift
//  CooNetwork
//

import Foundation

/// `[String: any Sendable]` / `NSDictionary` 数据源适配
///
/// 适用于内部已完成 JSON 反序列化、直接返回字典的客户端（如 mPaaS）。
public struct NtkJsonObjectDecoderBuilder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkDecoderBuilding {
    // ... 完整实现从 iNtkDecoderBuilding.swift 原样复制
}

/// 默认 `Data` 数据源适配（适用于 Alamofire 等返回 `Data` 的客户端）
public struct NtkDataDecoderBuilder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkDecoderBuilding {
    // ... 完整实现从 iNtkDecoderBuilding.swift 原样复制
}
```

- [ ] **Step 2：从 `iNtkDecoderBuilding.swift` 删除两个 Builder struct 实现**

保留：`NtkExtractedHeader`、`iNtkDecoderBuilding` 协议定义、`extension iNtkDecoderBuilding`（默认 extractHeader 实现）。
删除：`NtkJsonObjectDecoderBuilder` struct（77-126行）、`NtkDataDecoderBuilder` struct（128-158行）。

- [ ] **Step 3：更新 `iNtk/iNtkDecoderBuilding.swift` 内的 doc comment**

文件头部的 `/// ## 内置实现` 注释块仍引用两个 Builder struct，拆分后需更新，改为指向新位置：
```swift
/// ## 内置实现（位于 `interceptor/NtkDecoderBuilders.swift`）
/// - `NtkDataDecoderBuilder`：默认实现，适配 `Data` 数据源（如 Alamofire）
/// - `NtkJsonObjectDecoderBuilder`：适配 `[String: any Sendable]` / `NSDictionary` 数据源（如 mPaaS）
```

- [ ] **Step 4：更新 `iNtk/CLAUDE.md`**

在 `iNtkDecoderBuilding` 的描述中注明内置实现已移至 `interceptor/NtkDecoderBuilders.swift`。

- [ ] **Step 5：更新 `interceptor/CLAUDE.md`**

添加：
- `NtkDecoderBuilders` - `NtkDataDecoderBuilder`（Data 源）和 `NtkJsonObjectDecoderBuilder`（字典源）的内置适配实现

- [ ] **Step 6：编译验证**

```bash
cd /Users/coomini/Desktop/CooLibraries/CooNetwork && swift build 2>&1 | tail -20
```

期望：`Build complete!`

- [ ] **Step 7：Commit**

```bash
git add -A
git commit -m "refactor: move NtkDataDecoderBuilder and NtkJsonObjectDecoderBuilder to interceptor/"
```

---

## Task 4：拆分 `model/NtkResponse.swift` 为单职责文件

**文件：**
- Modify: `Sources/CooNetwork/NtkNetwork/model/NtkResponse.swift`（只保留 `NtkResponse<T>`）
- Create: `Sources/CooNetwork/NtkNetwork/model/NtkResponseDecoder.swift`
- Modify: `Sources/CooNetwork/NtkNetwork/model/CLAUDE.md`

**理由：** 当前文件混合了协议 `iNtkResponseMapKeys`、解码工具 `NtkCodingKeys`、泛型解码器 `NtkResponseDecoder`、响应模型 `NtkResponse<T>` 四种类型，违反单一职责。

**注意：** `iNtkResponseMapKeys` 与 `NtkResponseDecoder` 耦合紧密（作为泛型参数），两者一起移到 `NtkResponseDecoder.swift` 是合理的归组。

- [ ] **Step 1：创建 `model/NtkResponseDecoder.swift`**

将 `NtkResponse.swift` 中的以下类型剪切到新文件：
- `iNtkResponseMapKeys` 协议（第 12-19 行）
- `NtkCodingKeys` struct（第 24-58 行）
- `NtkResponseDecoder<ResponseData, Keys>` struct（第 62-97 行）

新文件头部：
```swift
//
//  NtkResponseDecoder.swift
//  CooNetwork
//

import Foundation

// iNtkResponseMapKeys + NtkCodingKeys + NtkResponseDecoder
// 三个类型放在一起是因为 NtkResponseDecoder 同时依赖两者
```

- [ ] **Step 2：修改 `model/NtkResponse.swift`**

删除已移走的三个类型定义，只保留 `NtkResponse<T>` struct 及其实现。

- [ ] **Step 3：更新 `model/CLAUDE.md`**

添加：
- `NtkResponseDecoder` - 泛型 JSON 解码器，依赖 `iNtkResponseMapKeys` 和 `NtkCodingKeys`

- [ ] **Step 4：更新 `iNtk/CLAUDE.md`**

`iNtk/CLAUDE.md` 的核心协议列表中有 `iNtkResponseMapKeys`，但它实际定义在 `model/NtkResponseDecoder.swift` 中（历史上混放在 `NtkResponse.swift`）。从列表中删除该条目，或加注说明：
```
- `iNtkResponseMapKeys` - 响应键映射协议（定义在 model/NtkResponseDecoder.swift，因与 NtkResponseDecoder 强绑定）
```

- [ ] **Step 5：编译验证**

```bash
cd /Users/coomini/Desktop/CooLibraries/CooNetwork && swift build 2>&1 | tail -20
```

期望：`Build complete!`

- [ ] **Step 6：Commit**

```bash
git add -A
git commit -m "refactor: split NtkResponse.swift into NtkResponse and NtkResponseDecoder"
```

---

## 执行顺序建议

Task 1 → Task 2 → Task 3 → Task 4，每个 Task 独立可验证，编译通过后再做下一个。
