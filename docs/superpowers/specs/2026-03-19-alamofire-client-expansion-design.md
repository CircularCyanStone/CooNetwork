# AlamofireClient 能力扩展设计

> 日期: 2026-03-19
> 状态: 设计阶段
> 范围: 本次实现 Upload，Download/Stream 仅记录能力缺口供后续参考

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

### 2. 独立上传请求协议

新增 `iAFUploadRequest`，继承 `iAFRequest`，将上传相关属性隔离在独立协议中：

```swift
/// AF 上传请求协议
/// 继承 iAFRequest，新增上传数据源和进度回调
public protocol iAFUploadRequest: iAFRequest {
    /// 上传数据源（必须实现）
    var uploadSource: AFUploadSource { get }

    /// 上传进度回调（可选，协议层定义）
    var onUploadProgress: (@Sendable (Progress) -> Void)? { get }
}

extension iAFUploadRequest {
    /// 默认无进度回调
    public var onUploadProgress: (@Sendable (Progress) -> Void)? { nil }

    /// 上传请求默认使用 POST
    public var method: NtkHTTPMethod { .post }
}
```

**设计理由：**
- `iAFRequest` 保持干净，普通请求零感知上传相关属性
- `uploadSource` 是必须实现的属性，编译器强制检查
- 协议名本身表达意图，业务层一看就知道要关注哪些属性

### 3. AFClient 内部分支

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

    // 挂载进度回调（协议属性 或 链式 API 传入）
    let progressHandler = mutableRequest["uploadProgress"] as? @Sendable (Progress) -> Void
                          ?? uploadRequest.onUploadProgress
    if let progressHandler {
        afRequest.uploadProgress(closure: progressHandler)
    }
} else {
    // 现有普通请求逻辑，不变
    afRequest = session.request(...)
}

// 后续 validation、serialization、响应处理 — 完全复用现有逻辑
```

**关键点：** `UploadRequest` 是 `DataRequest` 的子类，所以 `applyValidation`、`configureSerialization` 等后续步骤无需任何修改。

### 4. 进度回调：双通道支持

同时提供两种进度回调方式，适应不同使用场景：

**通道 a：协议属性（请求定义时绑定）**

适合封装好的、可复用的请求类型：

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
    // 进度回调在请求定义时绑定
    var onUploadProgress: (@Sendable (Progress) -> Void)?
}
```

**通道 b：链式 API（调用时临时挂载）**

适合同一请求类型在不同场景下灵活控制：

```swift
// NtkNetwork 扩展（AlamofireClient 模块内）
extension NtkNetwork {
    @discardableResult
    public func onUploadProgress(
        _ handler: @escaping @Sendable (Progress) -> Void
    ) -> Self {
        setRequestValue(handler, forKey: "uploadProgress")
        return self
    }
}
```

使用示例：

```swift
let response = try await NtkAF<UploadResult>.withAF(req)
    .onUploadProgress { progress in
        print("上传进度: \(progress.fractionCompleted)")
    }
    .request()
```

**优先级：** 链式 API（b）> 协议属性（a）。如果两者都提供了，以调用时传入的为准。

### 5. 业务层使用示例

```swift
// 示例 1：Multipart 上传头像
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
    .onUploadProgress { print("进度: \($0.fractionCompleted)") }
    .request()

// 示例 2：Raw Binary 上传到 presigned URL
struct S3UploadRequest: iAFUploadRequest {
    let fileURL: URL
    let presignedURL: URL

    var baseURL: URL? { presignedURL }
    var path: String { "" }
    var method: NtkHTTPMethod { .put }
    var uploadSource: AFUploadSource { .fileURL(fileURL) }
}
```

### 6. 改动范围

| 文件 | 改动内容 |
|---|---|
| `AFRequest.swift` | 新增 `AFUploadSource` 枚举、`iAFUploadRequest` 协议及默认实现 |
| `AFClient.swift` | `sendRequest` 内部新增 upload 分支 + 进度挂载逻辑 |
| `Ntk+AF.swift` | `NtkNetwork` 扩展 `onUploadProgress` 链式 API |
| 其他文件 | **不动** — 拦截器链、去重、重试、解析、Toast 全部自动复用 |

### 7. 错误处理

Upload 的错误处理完全复用现有逻辑：
- 超时 → `NtkError.requestTimeout`
- Alamofire 错误 → `NtkError.AF.afError`
- 响应解析 → `AFDataParsingInterceptor` 处理

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

**接入思路：**
- 类似 Upload，新增 `iAFDownloadRequest: iAFRequest` 协议
- 新增 `downloadDestination` 和 `onDownloadProgress` 属性
- AFClient 内部新增 `session.download(...)` 分支
- 断点续传需要额外的 `resumeData` 存储机制
- 响应类型不同：返回的是文件 URL 而非 Data，`AFDataParsingInterceptor` 可能需要适配

**与 Upload 的关键差异：**
- 响应不是 `Data` 而是文件 `URL`，解析拦截器需要新的处理路径
- 断点续传引入状态管理（resumeData 的保存和恢复）

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
