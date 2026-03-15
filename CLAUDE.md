# CLAUDE.md

CooNetwork - 统一的网络工具库，为 Swift 项目提供类型安全的网络抽象。

## 快速开始

```bash
# 构建
swift build

# 运行测试
swift test

# 清理
swift package clean
```

## 项目结构

```
Sources/
├── CooNetwork/      # 核心网络抽象
└── AlamofireClient/  # Alamofire 集成
```

## 架构文档

详细的架构设计和决策记录见: [docs/architecture.md](docs/architecture.md)

## 模块说明

- **Sources/CooNetwork/** - 核心库，包含协议定义、拦截器链、缓存系统
- **Sources/AlamofireClient/** - Alamofire 实现，提供 `NtkAF<T>` 便捷别名

## 使用示例

```swift
struct MyRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/endpoint" }
    var method: NtkHTTPMethod { .get }
}

let network = NtkAF<MyModel>.withAF(request)
let response = try await network.request()
```
