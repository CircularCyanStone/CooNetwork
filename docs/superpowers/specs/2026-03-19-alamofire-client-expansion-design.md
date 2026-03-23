# AlamofireClient 能力扩展设计

> 日期: 2026-03-19（更新: 2026-03-20）
> 状态: 设计阶段
> 范围: 本次实现 Upload，Download/Stream 仅记录能力缺口供后续参考

## 变更记录

| 日期 | 内容 |
|---|---|
| 2026-03-19 | 初版设计：Upload 接入方案、进度双通道、Download/Stream 能力缺口记录 |
| 2026-03-20 | 整合进度回调方案对比；将 AsyncStream 提升为第三通道；提取通用传输进度模型（Upload/Download 共用）；去掉 `iAFTransferProgressRequest` 中间协议（过度设计） |
| 2026-03-20 | 技术评审：新增评审报告章节；修正 `requestWithProgress()` 单次使用保护；明确 Upload 去重策略；补充重试语义说明；补充 multipart 参数说明；标注 Download `configureSerialization` 适配点 |

## 背景

当前 `AlamofireClient` 模块仅封装了 Alamofire 的 `DataRequest`（普通请求）。
Alamofire 实际支持 4 种请求类型：

| Alamofire 请求类型 | 说明 | 当前支持 |
|---|---|---|
| `DataRequest` | 标准 HTTP 请求，响应数据在内存中 | ✅ 已支持 |
| `UploadRequest` | 文件/数据/Multipart 上传，支持进度回调 | ❌ 未支持 |
| `DownloadRequest` | 文件下载到磁盘，支持断点续传和进度回调 | ❌ 未支持 |
| `DataStreamRequest` | 流式响应（SSE、chunked），支持 AsyncSequence | ❌ 未支持 |

本次设计聚焦 **Upload 能力的接入**。

## 设计决策

### 方案选择：在 AFClient 内部扩展（方案 A）

**否决的方案：**
- 方案 B：新建独立 `AFUploadClient` — 大量重复代码（session管理、错误处理、validation 等）
- 方案 B+：提取 `AFClientCore` + 独立 Client — 当前 AFClient 仅 ~140 行，过度设计

**选择方案 A 的理由：**
1. Alamofire 的 `UploadRequest` 继承自 `DataRequest`，响应处理逻辑完全一致
2. 差异仅在请求构建阶段：`session.upload(...)` vs `session.request(...)`
3. 拦截器链、去重、重试、解析、Toast 全部自动复用，零改动
4. 改动范围最小（2 个文件），不影响现有 API
5. 未来若 AFClient 膨胀，再提取 Core 也很自然 — 共享逻辑已在同一文件中

## Upload 详细设计

### 1. 上传数据源枚举

新增 `AFUploadSource`，定义三种上传方式：

```swift
/// 上传数据源
public enum AFUploadSource: Sendable {
    /// 内存数据上传（如已加载到内存的图片 Data）
    case data(Data)
    /// 文件 URL 上传（如本地视频文件）
    case fileURL(URL)
    /// Multipart 表单上传（如图片 + 额外字段）
    case multipart(@Sendable (MultipartFormData) -> Void)
}
```

### 2. 通用传输进度模型

进度回调在 Upload 和 Download 中结构完全一致（`completedUnitCount` / `totalUnitCount` / `fractionCompleted`），差异仅在"谁产生进度"。因此将进度相关类型提取为通用模型，放在 CooNetwork 核心层：

```swift
/// 传输进度（封装 Foundation.Progress 的核心字段，Sendable 安全）
/// 放在 CooNetwork 模块，不依赖 Alamofire
public struct NtkTransferProgress: Sendable {
    /// 已完成字节数
    public let completedUnitCount: Int64
    /// 总字节数（未知时为 -1）
    public let totalUnitCount: Int64
    /// 完成比例 0.0 ~ 1.0
    public let fractionCompleted: Double

    /// Memberwise 初始化（便于测试和手动构造）
    public init(completedUnitCount: Int64, totalUnitCount: Int64, fractionCompleted: Double) {
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.fractionCompleted = fractionCompleted
    }

    /// 从 Foundation.Progress 构造
    public init(from progress: Progress) {
        self.init(
            completedUnitCount: progress.completedUnitCount,
            totalUnitCount: progress.totalUnitCount,
            fractionCompleted: progress.fractionCompleted
        )
    }
}

/// 传输事件（上传/下载通用）
/// 放在 CooNetwork 模块，不依赖 Alamofire
public enum NtkTransferEvent<ResponseData: Sendable>: Sendable {
    /// 传输进度
    case progress(NtkTransferProgress)
    /// 传输完成
    case completed(NtkResponse<ResponseData>)
}
```

**用 `NtkTransferProgress` 而不是直接传 `Double` 的理由：**
- `Foundation.Progress` 不是 `Sendable`，不能直接放进 `Sendable` 枚举
- 业务层经常需要 `completedUnitCount` / `totalUnitCount` 来显示 "已上传 3.2MB / 10MB"
- 单个 `Double` 丢失了这些信息

### 3. 独立上传请求协议

新增 `iAFUploadRequest`，继承 `iAFRequest`，将上传相关属性隔离在独立协议中：

```swift
/// AF 上传请求协议
/// 继承 iAFRequest，新增上传数据源和传输进度回调
public protocol iAFUploadRequest: iAFRequest {
    /// 上传数据源（必须实现）
    var uploadSource: AFUploadSource { get }
    /// 传输进度回调（可选）
    var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)? { get }
}

extension iAFUploadRequest {
    /// 默认无进度回调
    public var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)? { nil }
    /// 上传请求默认使用 POST
    public var method: NtkHTTPMethod { .post }
}
```

**设计理由：**
- `iAFRequest` 保持干净，普通请求零感知上传/进度相关属性
- `uploadSource` 是必须实现的属性，编译器强制检查
- `onTransferProgress` 属性名和类型与后续 `iAFDownloadRequest` 保持一致（各自声明、各自默认实现），无需额外的中间协议层

**去重策略：Upload 请求默认禁用去重。**

去重键由 `NtkRequestIdentifierManager.generateHashForDeduplication()` 基于 `method + baseURL + path + headers + parameters` 生成，`uploadSource`（Data/fileURL/multipart 闭包）不参与哈希计算。这意味着两个上传到同一 URL、相同 parameters 但携带不同文件内容的请求会被误判为"重复请求"。因此在 AFClient 的 upload 分支中，应在构建请求前自动禁用去重：

```swift
// AFClient upload 分支中，构建请求前禁用去重
var mutableReq = request  // NtkMutableRequest 是 struct，需要 var
mutableReq.disableDeduplication()
```

**重试语义：Upload 请求的重试是安全的。**

`NtkRetryInterceptor` 会在请求失败时自动重试。对于 `AFUploadSource.data` 和 `.fileURL`，数据源是幂等的，重试安全。对于 `.multipart`，重试会重新执行 builder 闭包来重建 multipart body — 只要闭包是幂等的（不依赖流式数据源或一次性资源），重试同样安全。业务方应确保 multipart builder 闭包的幂等性。

> **否决 `iAFTransferProgressRequest` 中间协议的理由：**
>
> 最初设计了 `iAFTransferProgressRequest` 基协议让 Upload/Download 共用 `onTransferProgress`。
> 审查后认定为过度设计：
> 1. Swift 协议扩展本身就能让两个协议各自声明同名属性 + 各自提供默认实现，效果一致
> 2. AFClient 内部必须先判断 `is iAFUploadRequest` 还是 `is iAFDownloadRequest` 来决定调用 `uploadProgress` 还是 `downloadProgress`，"通用参数类型"并没有减少分支逻辑
> 3. 多一层协议继承增加理解成本，业务方看到 `iAFUploadRequest` 还要去查它继承了什么

### 4. AFClient 内部分支

在 `AFClient.sendRequest()` 中，根据请求类型决定构建方式：

```swift
// 伪代码 — 展示核心分支逻辑
let afRequest: DataRequest

if let uploadRequest = mRequest as? iAFUploadRequest {
    // 走上传路径
    switch uploadRequest.uploadSource {
    case .data(let data):
        afRequest = session.upload(data, to: url, method: method,
                                   headers: headers, requestModifier: modifier)
    case .fileURL(let fileURL):
        afRequest = session.upload(fileURL, to: url, method: method,
                                   headers: headers, requestModifier: modifier)
    case .multipart(let builder):
        afRequest = session.upload(multipartFormData: builder, to: url,
                                   method: method, headers: headers,
                                   requestModifier: modifier)
    }

    // 挂载进度回调（链式 API > 协议属性）
    let progressHandler = resolveTransferProgressHandler(request, protocolHandler: uploadRequest.onTransferProgress)
    if let progressHandler {
        afRequest.uploadProgress { progress in
            progressHandler(NtkTransferProgress(from: progress))
        }
    }
} else {
    // 现有普通请求逻辑，不变
    afRequest = session.request(...)
}

// 后续 validation、serialization、响应处理 — 完全复用现有逻辑
```

进度回调解析逻辑提取为私有方法，接收可选闭包而非协议类型，Upload/Download 共用：

```swift
/// 解析传输进度回调（链式 API > 协议属性）
private func resolveTransferProgressHandler(
    _ request: NtkMutableRequest,
    protocolHandler: (@Sendable (NtkTransferProgress) -> Void)?
) -> (@Sendable (NtkTransferProgress) -> Void)? {
    request["transferProgress"] as? @Sendable (NtkTransferProgress) -> Void
        ?? protocolHandler
}
```

**关键点：** `UploadRequest` 是 `DataRequest` 的子类，所以 `applyValidation`、`configureSerialization` 等后续步骤无需任何修改。

**Multipart 上传的参数传递说明：**

Alamofire 的 `session.upload(multipartFormData:, to:, ...)` API 不接受 `parameters` 参数。对于 `.data` 和 `.fileURL` 的 upload 同理。因此 Upload 请求的 `parameters` 属性不会被传递给 Alamofire 的 upload 方法。业务方如需传递额外字段，应通过 multipart builder 闭包的 `form.append` 传入，或通过 URL query string 传递。

### 5. 进度回调方案

#### 候选方案对比

| 方案 | 思路 | 优点 | 缺点 |
|---|---|---|---|
| A. 协议属性 | `iAFUploadRequest` 定义 `onTransferProgress` 属性 | 简单直接，闭包跟着请求走 | 同一请求类型不同场景想要不同进度处理时不够灵活 |
| B. 拦截器 | 新建 `NtkProgressInterceptor`，通过 `extraData` 传递闭包 | 完全解耦，可插拔 | 闭包经 `[String: Sendable]` 字典传递需强转，类型安全性差；现有 `NtkLoadingInterceptor` 实际上是拦截器自身持有闭包、`extraData` 只传布尔标志，并非传闭包的先例 |
| C. 链式 API | `NtkNetwork` 扩展 `onTransferProgress()` 方法，内部写入 `extraData` | 调用时灵活挂载，API 入口类型明确 | 需要在 `AFClient` 中从 `extraData` 读取并强转 |
| D. `AsyncThrowingStream` | 新增 `requestWithProgress()` 返回 `AsyncThrowingStream<NtkTransferEvent, Error>` | 纯 async/await，与 `requestWithCache()` 模式一致 | 需要新增方法和枚举类型 |

#### 最终决策：三通道（A + C + D）

选择协议属性 + 链式 API + AsyncStream 的组合，仅否决拦截器方案。

三个通道解决不同层面的问题：
- A（协议属性）+ C（链式 API）：解决"进度回调怎么传进去" — 闭包式，命令式风格
- D（AsyncStream）：解决"调用方怎么消费进度" — 流式，声明式风格，拥抱 Swift 并发

所有通道的类型命名均为通用的 `Transfer`（非 `Upload`/`Download`），Upload 和 Download 共用同一套进度基础设施。

**否决拦截器方案（B）的理由：**

仔细审查现有代码后发现，`NtkLoadingInterceptor` 的模式是**拦截器自身持有 UI 闭包**（`interceptBefore` / `interceptAfter`），`extraData` 只传递简单的布尔标志（`showLoading`）和字符串（`loadingText`）。它并不是"通过 `extraData` 传递闭包"的先例。进度回调如果走拦截器，需要把闭包塞进 `[String: Sendable]` 字典再强转取出，这不是现有架构验证过的模式。

**纳入 AsyncStream 方案（D）的理由：**

1. Swift 并发是语言演进方向，Alamofire 5.5+ 已全面拥抱 async/await，库的 API 应跟进
2. 项目中 `requestWithCache()` 已返回 `AsyncThrowingStream`，`requestWithProgress()` 是同一模式的自然延伸
3. 闭包回调和 AsyncStream 不冲突 — 闭包是底层传递机制，AsyncStream 是上层消费接口
4. `for await` 天然支持 Task 取消、结构化并发，比闭包更安全
5. 为后续 Download 进度、Stream 响应等场景建立统一的流式 API 范式

#### 通道 a：协议属性（请求定义时绑定）

适合封装好的、可复用的请求类型，进度处理逻辑固定在请求定义中：

```swift
struct AvatarUploadRequest: iAFUploadRequest {
    let imageData: Data
    var path: String { "/upload/avatar" }
    var uploadSource: AFUploadSource {
        .multipart { form in
            form.append(imageData, withName: "file",
                       fileName: "avatar.jpg", mimeType: "image/jpeg")
        }
    }
    // 进度回调在请求定义时绑定（iAFUploadRequest 协议属性）
    var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)?
}
```

#### 通道 b：链式 API（调用时临时挂载）

适合同一请求类型在不同场景下灵活控制：

```swift
// NtkNetwork 扩展（AlamofireClient 模块内）
extension NtkNetwork {
    @discardableResult
    public func onTransferProgress(
        _ handler: @escaping @Sendable (NtkTransferProgress) -> Void
    ) -> Self {
        setRequestValue(handler, forKey: "transferProgress")
        return self
    }
}
```

使用示例：

```swift
let response = try await NtkAF<UploadResult>.withAF(req)
    .onTransferProgress { progress in
        print("进度: \(progress.fractionCompleted)")
        print("已传输: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
    }
    .request()
```

#### 通道 c：AsyncStream（结构化并发消费）

适合需要在 async 上下文中统一处理进度和结果的场景，与 `requestWithCache()` 模式一致：

```swift
// NtkNetwork 扩展（AlamofireClient 模块内）
extension NtkNetwork {
    /// 带进度的请求，返回 AsyncThrowingStream
    /// 与 requestWithCache() 同为流式 API 家族
    /// Upload 请求返回上传进度，Download 请求返回下载进度
    public func requestWithProgress() -> AsyncThrowingStream<NtkTransferEvent<ResponseData>, Error> {
        // 同步阶段：单次使用保护（与 requestWithCache() 保持一致）
        do {
            try markRequestConsumedOrThrow()
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        // 同步阶段：注入进度闭包到 extraData（在返回 stream 前完成，避免时序问题）
        // 注意：此处先创建 stream，闭包在 stream 构造时绑定到 continuation
        return AsyncThrowingStream { continuation in
            // 通过链式 API 通道注入进度闭包，桥接到 stream
            self.setRequestValue(
                { @Sendable (progress: NtkTransferProgress) in
                    continuation.yield(.progress(progress))
                } as @Sendable (NtkTransferProgress) -> Void,
                forKey: "transferProgress"
            )

            let task = Task {
                do {
                    let response = try await self.makeExecutor().execute()
                    continuation.yield(.completed(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
```

使用示例：

```swift
// 声明式消费进度 + 结果（Upload 和 Download 用法完全一致）
for try await event in NtkAF<AvatarResponse>.withAF(req).requestWithProgress() {
    switch event {
    case .progress(let transfer):
        viewModel.progress = transfer.fractionCompleted
        viewModel.statusText = "\(transfer.completedUnitCount / 1024)KB / \(transfer.totalUnitCount / 1024)KB"
    case .completed(let response):
        viewModel.result = response.data
    }
}

// 取消自动传播 — break 或 Task 取消即可
```

#### 三通道关系

```
通道 a（协议属性 onTransferProgress）──┐
                                       ├──→ AFClient.resolveTransferProgressHandler()
通道 b（链式 API onTransferProgress）──┘    → 挂载到 Alamofire uploadProgress / downloadProgress
                                                ↑
                                                │ 内部桥接
通道 c（AsyncStream requestWithProgress()）─────┘
    内部调用 setRequestValue("transferProgress") + request()
    将闭包回调桥接为 AsyncThrowingStream<NtkTransferEvent, Error>
```

- 通道 a/b 是底层机制，直接控制 Alamofire 的进度回调
- 通道 c 是上层封装，内部复用通道 b 的 `setRequestValue`，不引入新的底层路径
- 调用方根据场景选择：简单场景用 a/b，结构化并发场景用 c
- Upload 和 Download 共用全部三个通道，`AFClient` 内部根据请求类型决定挂载到 `uploadProgress` 还是 `downloadProgress`

#### 闭包通道优先级规则

链式 API（b）> 协议属性（a）。如果两者都提供了，以调用时传入的为准：

```swift
// AFClient 中的通用解析逻辑
private func resolveTransferProgressHandler(
    _ request: NtkMutableRequest,
    protocolHandler: (@Sendable (NtkTransferProgress) -> Void)?
) -> (@Sendable (NtkTransferProgress) -> Void)? {
    request["transferProgress"] as? @Sendable (NtkTransferProgress) -> Void
        ?? protocolHandler
}
```

> 注意：通道 c 内部使用通道 b 写入闭包，因此当使用 `requestWithProgress()` 时，
> 协议属性上的 `onTransferProgress` 会被覆盖。这是符合预期的 — 调用方选择了 Stream 消费方式，
> 进度数据应统一从 Stream 产出。

### 6. 业务层使用示例

```swift
// 示例 1：Multipart 上传头像（链式 API 闭包回调）
struct AvatarUploadRequest: iAFUploadRequest {
    let imageData: Data
    let userId: String

    var path: String { "/user/avatar" }
    var uploadSource: AFUploadSource {
        .multipart { form in
            form.append(imageData, withName: "file",
                       fileName: "avatar.jpg", mimeType: "image/jpeg")
            form.append(Data(userId.utf8), withName: "userId")
        }
    }
}

let req = AvatarUploadRequest(imageData: jpegData, userId: "123")
let result = try await NtkAF<AvatarResponse>.withAF(req)
    .onTransferProgress { progress in
        print("进度: \(progress.fractionCompleted)")
        print("已传输: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
    }
    .request()

// 示例 2：Raw Binary 上传到 presigned URL（无需进度）
struct S3UploadRequest: iAFUploadRequest {
    let fileURL: URL
    let presignedURL: URL

    var baseURL: URL? { presignedURL }
    var path: String { "" }
    var method: NtkHTTPMethod { .put }
    var uploadSource: AFUploadSource { .fileURL(fileURL) }
}

// 示例 3：AsyncStream 消费进度（SwiftUI ViewModel 场景）
@MainActor
func uploadAvatar(imageData: Data, userId: String) async {
    let req = AvatarUploadRequest(imageData: imageData, userId: userId)
    do {
        for try await event in NtkAF<AvatarResponse>.withAF(req).requestWithProgress() {
            switch event {
            case .progress(let transfer):
                self.uploadProgress = transfer.fractionCompleted
                self.statusText = "\(transfer.completedUnitCount / 1024)KB / \(transfer.totalUnitCount / 1024)KB"
            case .completed(let response):
                self.avatarURL = response.data.url
            }
        }
    } catch {
        self.error = error
    }
}
```

### 7. 改动范围

| 文件 | 模块 | 改动内容 |
|---|---|---|
| 新增 `NtkTransferProgress.swift` | CooNetwork | `NtkTransferProgress` 结构体 |
| 新增 `NtkTransferEvent.swift` | CooNetwork | `NtkTransferEvent<ResponseData>` 枚举 |
| `AFRequest.swift` | AlamofireClient | 新增 `AFUploadSource` 枚举、`iAFUploadRequest` 协议及默认实现 |
| `AFClient.swift` | AlamofireClient | `sendRequest` 内部新增 upload 分支 + `resolveTransferProgressHandler` 通用进度解析 |
| `Ntk+AF.swift` | AlamofireClient | `NtkNetwork` 扩展 `onTransferProgress` 链式 API + `requestWithProgress()` 方法 |
| 其他文件 | — | **不动** — 拦截器链、去重、重试、解析、Toast 全部自动复用 |

> 注意：`NtkTransferProgress` 和 `NtkTransferEvent` 放在 CooNetwork 核心模块而非 AlamofireClient，
> 因为它们不依赖 Alamofire，后续其他 Client 实现（如基于 URLSession 的）也可以复用。

### 8. 错误处理

Upload 的错误处理完全复用现有逻辑：
- 超时 → `NtkError.requestTimeout`
- Alamofire 错误 → `NtkError.AF.afError`
- 响应解析 → `NtkDataParsingInterceptor` 处理

无需新增错误类型。

---

## 未支持能力记录（后续参考）

### Download（文件下载）

**Alamofire 能力：**
- `DownloadRequest` — 下载文件到磁盘指定路径
- 下载进度回调（`downloadProgress`）
- 断点续传（`resumeData` + `AF.download(resumingWith:)`）
- 自定义下载目标路径（`DownloadRequest.Destination`）

**典型场景：**
- 大文件下载（视频、文档、安装包）
- 需要持久化到磁盘的资源
- 弱网环境下的断点续传

**可复用的基础设施（本次已建立）：**
- `NtkTransferProgress` / `NtkTransferEvent` — 直接复用，无需新增
- `onTransferProgress` 属性 — `iAFDownloadRequest` 自行声明同名同类型属性，与 `iAFUploadRequest` 保持一致
- `onTransferProgress()` 链式 API — 直接复用
- `requestWithProgress()` AsyncStream — 直接复用，Download 请求调用时返回下载进度
- `resolveTransferProgressHandler()` — AFClient 内部直接复用

**仅需新增：**
- `iAFDownloadRequest: iAFRequest` 协议 — 新增 `downloadDestination`、`onTransferProgress` 属性
- AFClient 内部新增 `session.download(...)` 分支，进度挂载到 `.downloadProgress(closure:)`
- 断点续传需要额外的 `resumeData` 存储机制

**与 Upload 的关键差异：**
- 响应不是 `Data` 而是文件 `URL`，`NtkDataParsingInterceptor` 可能需要适配
- 断点续传引入状态管理（resumeData 的保存和恢复）
- `configureSerialization(for: DataRequest)` 方法签名不兼容 `DownloadRequest` — Alamofire 中 `DownloadRequest` 和 `DataRequest` 都直接继承 `Request`，不是父子关系。接入 Download 时需要在 `iAFRequest` 中新增 `configureDownloadSerialization(for: DownloadRequest)` 方法，或将现有方法签名泛化

**预估接入示例：**

```swift
// 协议定义
public protocol iAFDownloadRequest: iAFRequest {
    var downloadDestination: DownloadRequest.Destination? { get }
    var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)? { get }
}

extension iAFDownloadRequest {
    public var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)? { nil }
}

// 业务使用（与 Upload 完全对称）
let result = try await NtkAF<FileInfo>.withAF(downloadReq)
    .onTransferProgress { print("下载: \($0.fractionCompleted)") }
    .request()

// 或 AsyncStream
for try await event in NtkAF<FileInfo>.withAF(downloadReq).requestWithProgress() {
    switch event {
    case .progress(let transfer):
        viewModel.downloadProgress = transfer.fractionCompleted
    case .completed(let response):
        viewModel.filePath = response.data.path
    }
}
```

### Stream（流式响应）

**Alamofire 能力：**
- `DataStreamRequest` — 流式接收响应数据
- 回调式：`responseStream { stream in ... }`
- 解码式：`responseStreamDecodable(of: T.self) { stream in ... }`
- AsyncSequence：`streamTask.streamingData()` 配合 `for await`
- 支持取消（break 循环或 throw 错误自动取消）

**典型场景：**
- SSE（Server-Sent Events）
- LLM 流式响应（AI 聊天接口）
- 实时数据推送

**接入思路：**
- 新增 `iAFStreamRequest: iAFRequest` 协议
- 返回类型从 `NtkResponse<T>` 变为 `AsyncThrowingStream<T, Error>` 或类似的流式接口
- 这是最复杂的扩展 — 当前 `iNtkClient.execute()` 的"请求进去、响应出来"模型不适用于流式场景
- 可能需要在 `NtkNetwork` 层新增 `stream()` 方法（类似现有的 `request()` 和 `requestWithCache()`）
- 拦截器链需要考虑：流式场景下拦截器是拦截每个 chunk 还是只拦截连接建立/结束

**与 Upload/Download 的关键差异：**
- 根本性地改变了请求-响应模型（一次请求、多次响应）
- 拦截器链的语义需要重新定义
- 建议作为独立设计专题处理

---

## 技术评审报告（2026-03-20）

> 评审方式：逐行对照设计文档与全部相关源码（AFClient、NtkNetwork、NtkMutableRequest、拦截器链、去重、重试、缓存键生成等），验证方案在设计、架构、运行逻辑上的正确性。

### 评审结论

设计方案整体可行，核心架构决策正确。以下问题已在本次更新中修正或补充到文档对应章节。

### 已修正的问题

#### [HIGH] H1. `requestWithProgress()` 单次使用保护时序

`requestWithCache()` 在返回 stream 之前同步调用 `markRequestConsumedOrThrow()`，但原设计中 `requestWithProgress()` 将保护延迟到 `Task { }` 内部的 `self.request()` 中。这导致两个问题：
1. 同一实例先调 `requestWithProgress()` 再调 `request()`，两者都进入异步阶段，保护时序不确定
2. 与 `requestWithCache()` 模式不一致

**修正：** 已更新通道 c 的代码，在返回 stream 前同步调用 `markRequestConsumedOrThrow()`，并将 `setRequestValue` 也提到同步阶段，Task 内部直接调用 `makeExecutor().execute()` 而非 `self.request()`（避免二次触发单次保护）。

#### [HIGH] H2. Upload 请求的去重行为

去重键基于 `method + baseURL + path + headers + parameters` 生成，`uploadSource`（Data/fileURL/multipart 闭包）不参与哈希。两个上传到同一 URL 但携带不同文件的请求会被误判为重复。当前去重默认开启（`isDeduplicationEnabled` 默认 `true`）。

**修正：** 已在 `iAFUploadRequest` 协议章节补充说明，AFClient 的 upload 分支应在构建请求前自动调用 `disableDeduplication()`。

#### [HIGH] H3. Upload 请求的重试语义

`NtkRetryInterceptor` 会自动重试失败请求。对于 `.multipart` 闭包，重试会重新执行 builder 闭包。

**修正：** 已在 `iAFUploadRequest` 协议章节补充说明重试安全性前提：业务方应确保 multipart builder 闭包的幂等性。

#### [MEDIUM] M1. Multipart 上传的参数传递

Alamofire 的 `session.upload(multipartFormData:)` 不接受 `parameters` 参数，Upload 请求的 `parameters` 属性不会被使用。

**修正：** 已在 AFClient 内部分支章节补充参数传递说明。

#### [MEDIUM] M2. Download 的 `configureSerialization` 兼容性

`DownloadRequest` 不是 `DataRequest` 的子类（两者都直接继承 `Request`），现有 `configureSerialization(for: DataRequest)` 无法接收 `DownloadRequest`。

**修正：** 已在 Download 能力记录的"关键差异"中标注此适配点。

#### [MEDIUM] M3. `NtkTransferProgress` 缺少 memberwise init

仅有 `init(from: Progress)` 不便于测试场景构造。

**修正：** 已在通用传输进度模型章节补充 memberwise 初始化器。

### 验证通过的设计决策

以下设计点经代码验证确认正确，无需修改：

| 设计决策 | 验证依据 |
|---|---|
| 方案 A（AFClient 内部扩展） | AFClient 仅 ~144 行，不需要提取 Core |
| `UploadRequest` 是 `DataRequest` 子类 | `applyValidation`、`configureSerialization` 无需修改 |
| 否决拦截器方案（B） | `NtkLoadingInterceptor` 自身持有闭包，`extraData` 只传布尔/字符串，不是传闭包的先例 |
| 否决中间协议 `iAFTransferProgressRequest` | AFClient 内部必须区分 upload/download 来决定挂载 `uploadProgress` 还是 `downloadProgress`，中间协议不减少分支 |
| `NtkTransferProgress`/`NtkTransferEvent` 放 CooNetwork 模块 | 不依赖 Alamofire，正确 |
| 链式 API 模式 | 与 `hud()`/`loadingText()` 完全一致（`NtkNetwork+loading.swift`），已验证 |
| `requestWithProgress()` 的 AsyncStream 模式 | 与 `requestWithCache()` 结构对称 |
| 错误处理完全复用 | upload 分支走到 `response.result` 后的处理逻辑与普通请求一致 |
| 改动范围（5 个文件） | 评估准确，其他文件确实不需要改动 |
| `iAFUploadRequest.method` 默认 `.post` | 与 `iNtkRequest` 默认值一致，无歧义 |

### 实现建议（非阻塞）

1. **`resolveTransferProgressHandler` 中的闭包强转**：建议为 `NtkMutableRequest` 添加计算属性封装类型转换（类似 `showLoading`），提高类型安全性：
   ```swift
   var transferProgressHandler: (@Sendable (NtkTransferProgress) -> Void)? {
       extraData["transferProgress"] as? @Sendable (NtkTransferProgress) -> Void
   }
   ```
2. **通道 c 覆盖通道 a 的行为**：在实现代码中加注释说明 `requestWithProgress()` 会覆盖协议属性的 `onTransferProgress`，避免维护者困惑。
