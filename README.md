# CooNetwork

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" />
  <img src="https://img.shields.io/badge/platform-iOS%2013%2B%20%7C%20macOS%2010.15%2B-lightgrey.svg" />
  <img src="https://img.shields.io/badge/version-0.0.17-blue.svg" />
  <img src="https://img.shields.io/badge/license-MIT-green.svg" />
</p>

统一的网络工具库，为 Swift 项目提供类型安全的网络抽象层。

**CooNetwork** 采用 Swift 6 并发模型，通过统一的协议抽象支持多种网络后端（如 Alamofire），提供类型安全的请求构建、灵活的拦截器链、内置缓存和重试等开箱即用的功能。

---

## ✨ 核心特性

- ✅ **Swift 6 并发安全** — 基于 Actor 隔离模型，线程安全无需手动管理
- ✅ **类型安全** — 编译期类型检查，避免运行时类型错误
- ✅ **统一抽象** — 支持多种网络后端（当前支持 Alamofire），可扩展
- ✅ **灵活拦截器链** — 洋葱模型，支持请求/响应全流程拦截
- ✅ **开箱即用** — 内置缓存、重试、去重、进度监听
- ✅ **完善的错误处理** — 分层错误模型，精准捕获和处理

---

## 🚀 快速开始

定义请求并发起调用，只需几行代码：

```swift
import CooNetwork
import AlamofireClient

// 1. 定义请求
struct UserRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/users/123" }
    var method: NtkHTTPMethod { .get }
}

// 2. 发起请求
let network = NtkAF<User>.withAF(UserRequest())
let user = try await network.request()
print("用户名: \(user.name)")
```

---

## 📦 安装

### Swift Package Manager（推荐）

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/CircularCyanStone/CooNetwork.git", from: "0.0.17")
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
pod 'CooNetwork/Alamofire', '~> 0.0.17'
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

### 使用缓存

```swift
// 启用缓存
let storage = NtkMemoryCacheStorage()
let network = NtkAF<User>.withAF(request, storage: storage)

// 带缓存的请求
let cacheConfig = NtkRequestConfiguration(
    cachePolicy: .cacheElseNetwork,  // 优先使用缓存
    expiration: .seconds(300)         // 5 分钟过期
)
let user = try await network.requestWithCache(configuration: cacheConfig)
```

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

### 添加拦截器（日志、鉴权）

```swift
// 自定义日志拦截器
struct LoggingInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority { .high }
    
    func intercept(chain: NtkInterceptorChain) async throws -> any iNtkResponse {
        let request = chain.request
        print("📤 请求: \(request.method) \(request.url?.absoluteString ?? "")")
        
        let response = try await chain.proceed(request)
        print("📥 响应: \(response.code)")
        
        return response
    }
}

// 添加到请求
let network = NtkAF<User>.withAF(request)
network.addInterceptor(LoggingInterceptor())
let user = try await network.request()
```

---

## 🔧 高级特性

### 自定义拦截器

拦截器采用洋葱模型，按优先级顺序执行：

```swift
struct TokenRefreshInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority { .medium }
    
    func intercept(chain: NtkInterceptorChain) async throws -> any iNtkResponse {
        var request = chain.request
        
        // 在请求前添加 token
        if let token = await TokenManager.shared.getToken() {
            request.headers["Authorization"] = "Bearer \(token)"
        }
        
        do {
            return try await chain.proceed(request)
        } catch {
            // Token 过期时自动刷新
            if isTokenExpiredError(error) {
                try await TokenManager.shared.refreshToken()
                return try await chain.proceed(request)
            }
            throw error
        }
    }
    
    private func isTokenExpiredError(_ error: Error) -> Bool {
        // 检查是否为 token 过期错误
        return false
    }
}
```

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
