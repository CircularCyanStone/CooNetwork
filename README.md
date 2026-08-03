# CooNetwork

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" />
  <img src="https://img.shields.io/badge/platform-iOS%2013%2B%20%7C%20macOS%2010.15%2B-lightgrey.svg" />
  <img src="https://img.shields.io/badge/version-0.0.18-blue.svg" />
  <img src="https://img.shields.io/badge/license-MIT-green.svg" />
</p>

类型安全、并发安全的 Swift 网络抽象层。

## 为什么需要它？

如果你的项目遇到这些问题：

- **网络库切换成本高** — 直接依赖 Alamofire/URLSession，后续想换库或接入内部组件（如 mPaaS）改动巨大
- **Swift 6 并发检查过不了** — 手动管理线程和锁，代码到处是 warning 和编译错误
- **每个项目重复写** — 缓存、重试、鉴权、日志这些逻辑每次都要重新实现
- **类型不安全容易崩** — 字典传参、运行时类型转换，线上偶尔出现解析崩溃

**CooNetwork 的做法：**

✅ **统一抽象** — 业务代码只依赖协议，底层可以随时换 Alamofire、URLSession 或自定义实现

✅ **Swift 6 原生支持** — 不可变请求快照与 `Sendable` 值流负责跨并发域传递，共享状态由独立 actor 或短临界区锁按所有权隔离

✅ **通用功能内置** — 拦截器链、缓存、重试、去重、进度监听，直接用不用自己写

✅ **编译期类型检查** — 泛型约束 + 协议，类型错误编译时就能发现

✅ **职责清晰** — 解析流水线（normalize → transform → decode → validate）每个环节独立，不会混在一起

---

## 快速开始

**第一步：项目中创建统一扩展**（只需配置一次）

```swift
// Ntk+MyApp.swift
import CooNetwork
import AlamofireClient

extension Ntk {
    static func api<T: Decodable>(_ request: iAFRequest) -> NtkNetwork<T> {
        let network = NtkAF<T>.withAF(request)
        // 统一添加日志拦截器
        network.addInterceptor(LoggingInterceptor())
        // 稳定公共参数通过 interceptor 同时参与网络请求和缓存 key
        network.addInterceptor(CommonParameterInterceptor())
        return network
    }
}

// 定义项目的基础请求协议
protocol MyAppRequest: iAFRequest {}

extension MyAppRequest {
    var baseURL: URL? { URL(string: "https://api.myapp.com") }
    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
```

**第二步：业务代码只需定义接口**

```swift
// 定义登录接口
struct LoginRequest: MyAppRequest {
    var path: String { "/auth/login" }
    var method: NtkHTTPMethod { .post }
    var parameters: [String: Any]? {
        ["username": username, "password": password]
    }
    
    let username: String
    let password: String
}

// 发起请求（只需 2 行）
let request = LoginRequest(username: "user", password: "pass")
let response: LoginResponse = try await Ntk.api(request).request()
```

**这就是全部代码。** baseURL、拦截器、日志、鉴权都在扩展中统一配置好了，业务代码只关注接口本身。

---

## ✨ 核心特性

- **统一抽象** — 协议驱动设计，支持 Alamofire、URLSession、mPaaS 等多种后端
- **Swift 6 并发** — Actor 隔离 + 双层设计，编译期保证线程安全
- **类型安全** — 泛型响应类型，编译期检查，避免运行时错误
- **拦截器链** — 洋葱模型，三层优先级（outer/standard/inner），支持请求/响应全流程拦截
- **缓存系统** — 内存/磁盘缓存，支持自定义存储策略和过期时间
- **重试策略** — 内置固定间隔和指数退避策略，可自定义重试逻辑
- **请求去重** — 自动合并相同请求，避免重复调用
- **进度监听** — 上传/下载进度实时回调
- **分层错误** — 域错误优先（Validation/Serialization/Client/Cache），精准捕获和处理

---

## 📦 安装

### Swift Package Manager（推荐）

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/CircularCyanStone/CooNetwork.git", from: "0.0.18")
]
```

在目标中引入：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "CooNetwork", package: "CooNetwork"),
        .product(name: "AlamofireClient", package: "CooNetwork")
    ]
)
```

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'CooNetwork/Alamofire', '~> 0.0.18'
```

执行安装：

```bash
pod install
```

---

## 📖 基础使用

### 1. 定义请求

实现 `iAFRequest` 协议，描述请求的基本信息：

```swift
struct LoginRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/auth/login" }
    var method: NtkHTTPMethod { .post }
    var parameters: [String: Any]? {
        ["username": username, "password": password]
    }
    
    let username: String
    let password: String
}
```

### 2. 发起请求

使用 `NtkAF` 创建网络请求并执行：

```swift
// 定义响应模型
struct LoginResponse: Codable {
    let token: String
    let userId: Int
}

// 发起请求
let request = LoginRequest(username: "user@example.com", password: "password")
let network = NtkAF<LoginResponse>.withAF(request)

do {
    let response = try await network.request()
    print("登录成功，Token: \(response.token)")
} catch {
    print("登录失败: \(error)")
}
```

### 3. 错误处理

CooNetwork 提供分层的错误模型，可以精准捕获特定错误：

```swift
do {
    let response = try await network.request()
    // 处理成功响应
} catch let error as NtkError.Validation {
    // 业务层验证失败（如后端返回 code != 0）
    print("业务错误: \(error.message)")
} catch let error as NtkError.Serialization {
    // 数据解析失败
    print("解析错误: \(error)")
} catch {
    // 其他错误
    print("未知错误: \(error)")
}
```

### 4. 响应验证

默认验证器认为 `code == 0` 或 `code == "0"` 为成功。你可以自定义验证规则：

```swift
struct CustomValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        // 自定义成功条件
        return response.code.int == 200
    }
}

let network = NtkAF<User>.withAF(request, validation: CustomValidation())
```

### 5. 取消请求

```swift
let network = NtkAF<User>.withAF(request)
let task = Task {
    try await network.request()
}

// 取消请求
network.cancel()
// 或
task.cancel()
```

---

## 🎯 常见场景

### GET 请求（带查询参数）

```swift
struct SearchRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/search" }
    var method: NtkHTTPMethod { .get }
    var parameters: [String: Any]? {
        ["q": keyword, "page": page]
    }
    
    let keyword: String
    let page: Int
}

let request = SearchRequest(keyword: "Swift", page: 1)
let network = NtkAF<SearchResult>.withAF(request)
let result = try await network.request()
```

### POST 请求（JSON Body）

```swift
struct CreatePostRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/posts" }
    var method: NtkHTTPMethod { .post }
    var parameters: [String: Any]? {
        ["title": title, "content": content]
    }
    var encoding: ParameterEncoding { JSONEncoding.default }
    
    let title: String
    let content: String
}
```

### 自定义请求头

```swift
struct AuthenticatedRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/profile" }
    var method: NtkHTTPMethod { .get }
    var headers: [String: String]? {
        ["Authorization": "Bearer \(token)"]
    }
    
    let token: String
}
```

### 使用缓存与稳定请求 key

缓存配置只决定是否读写缓存及其有效期；请求 key 单独决定哪些字段代表同一资源。先在启动时声明确认安全的公共动态字段：

```swift
NtkConfiguration.configure {
    $0.requestIdentityPolicy = .init(
        excludedHeaderNames: ["X-Request-ID"],
        excludedParameterNames: ["nonce", "sign"]
    )
}

struct ProfileRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/profile" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? { .custom(duration: 300) }
}

let storage = NtkMemoryCacheStorage()
for try await response in NtkAF<User>.withAF(ProfileRequest(), storage: storage)
    .requestWithCache() {
    print(response.data)
}
```

用 `requestIdentityRule` 明确动态鉴权字段是否写入请求 key；稳定的业务主体使用只在本地生效的 `setRequestIdentityValue`：

```swift
struct AuthenticationModifier: iNtkRequestModifyingInterceptor {
    let token: String
    let userID: String

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.setHeader(
            "Bearer \(token)",
            forField: "Authorization",
            requestIdentityRule: .exclude
        )
        request.setParameter(
            Date().timeIntervalSince1970,
            forKey: "timestamp",
            requestIdentityRule: .exclude
        )
        request.setRequestIdentityValue(userID, forKey: "user")
        return request
    }
}
```

排除鉴权凭证却不通过 `setRequestIdentityValue` 加入稳定的 user/tenant 值，可能让不同用户共享缓存或正在执行的结果；默认 `.strict` 不会替业务推断主体。`.include` 与 `.exclude` 会覆盖策略中的字段转换闭包，附加请求 key 值不会发送到服务器；请求 key 构建失败只关闭本次缓存和去重，网络请求仍继续。

完整接入点、构建顺序以及缓存/去重两个终点见 [Request Identity 代码阅读路线](docs/request-identity-code-walkthrough.md)。

### 文件上传

```swift
struct UploadRequest: iAFUploadRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/upload" }
    var method: NtkHTTPMethod { .post }
    
    func makeUploadable() -> UploadRequest {
        // 返回实现了 UploadConvertible 的对象
        // 可以是 Data、文件路径或 MultipartFormData
        return .data(fileData)
    }
    
    let fileData: Data
}

let request = UploadRequest(fileData: imageData)
let network = NtkAF<UploadResponse>.withAF(request)
let response = try await network.request()
```

### 进度监听

```swift
let network = NtkAF<Data>.withAF(downloadRequest)

// 监听下载进度
network.downloadProgress { progress in
    print("下载进度: \(progress.fractionCompleted * 100)%")
}

// 监听上传进度
network.uploadProgress { progress in
    print("上传进度: \(progress.fractionCompleted * 100)%")
}

let data = try await network.request()
```

### 添加拦截器

```swift
struct LoggingInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority { .high }

    func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        print("📤 请求: \(context.request.method) \(context.request.path)")
        let response = try await next.handle(context: context)
        print("📥 响应: \(response.code)")
        return response
    }
}
```

---

## 🔧 高级特性

### 自定义请求修改拦截器

稳定公共参数通过显式请求修改能力参与请求构建：

```swift
struct CommonParameterInterceptor: iNtkRequestModifyingInterceptor {
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        var request = request
        request.setHeader("iOS", forField: "X-App-Channel")
        return request
    }
}

let network = NtkAF<User>.withAF(request)
network.addInterceptor(LoggingInterceptor())
network.addInterceptor(CommonParameterInterceptor())
let user = try await network.request()
```

`intercept(context:next:)` 中的请求是只读快照。请求头和参数只能在
`iNtkRequestModifyingInterceptor.modifyRequest(_:)` 中通过明确方法构建：改单个字段使用
`setHeader` / `setParameter`，批量合并并保留旧字段使用 `mergeHeaders` / `mergeParameters`，
完整替换使用 `setHeaders` / `setParameters`。动态字段通过全局或请求级
`NtkRequestIdentityPolicy`，或写入时的 `requestIdentityRule` 控制字段是否写入请求 key；请求级策略非空时完整替换全局策略。

### 自定义响应解析

实现 `iNtkResponseParser` 协议来自定义解析逻辑：

```swift
struct CustomParser: iNtkResponseParser {
    var priority: NtkInterceptorPriority { .innerHigh }
    
    func parse(response: any iNtkResponse) async throws -> any iNtkResponse {
        // 自定义解析逻辑
        return response
    }
}

let network = NtkAF<User>.withAF(request, responseParser: CustomParser())
```

### 配置重试策略

```swift
// 使用指数退避重试策略
let retryPolicy = NtkExponentialBackoffRetryPolicy(
    maxRetries: 3,
    initialDelay: 1.0,
    multiplier: 2.0
)

let network = NtkAF<User>.withAF(request)
network.setRetryPolicy(retryPolicy)
let user = try await network.request()
```

### 禁用去重

某些场景（如文件上传）需要禁用请求去重：

```swift
let network = NtkAF<UploadResponse>.withAF(uploadRequest)
network.disableDeduplication()  // 禁用去重
let response = try await network.request()
```

---

## 💡 示例项目

项目提供了完整的示例代码，演示各种使用场景：

- **CocoaPods 示例**: `Examples/PodExample`
- **SPM 示例**: `Examples/SPMExample`

运行示例项目：

```bash
# CocoaPods 示例
cd Examples/PodExample
pod install
open PodExample.xcworkspace

# SPM 示例
cd Examples/SPMExample
open Package.swift
```

---

## 🏗️ 架构概览

CooNetwork 采用双层设计：

- **配置层 (NtkNetwork)** — 非 Actor 的 Builder 模式，支持链式调用
- **执行层 (NtkNetworkExecutor)** — Actor 隔离，保证并发安全

核心组件：

- **拦截器链** — 洋葱模型，三层优先级（outer / standard / inner）
- **缓存系统** — 支持内存和磁盘缓存，可自定义存储策略
- **重试机制** — 可配置的重试策略（固定间隔、指数退避）
- **去重机制** — 自动合并相同请求，避免重复调用
- **响应解析** — 多阶段流水线：normalize → transform → decode → validate

详细架构文档请查看 `docs/architecture.md`。

---

**Happy Coding! 🎉**
