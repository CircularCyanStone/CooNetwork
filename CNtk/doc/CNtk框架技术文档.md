# CNtk 网络框架技术文档

## 概述

CNtk 是一个基于 Swift 开发的现代化网络请求框架，采用协议导向编程和拦截器模式设计，提供了灵活、可扩展的网络请求解决方案。框架支持与 Moya 集成，具备完善的错误处理、响应验证和请求拦截功能。

## 核心架构

### 1. 分层架构设计

```
┌─────────────────────────────────────┐
│           NtkNetwork               │  ← 用户接口层
├─────────────────────────────────────┤
│           NtkOperation             │  ← 操作管理层
├─────────────────────────────────────┤
│      拦截器链 (Interceptors)        │  ← 请求处理层
├─────────────────────────────────────┤
│         NtkClient                  │  ← 网络客户端层
├─────────────────────────────────────┤
│         Moya/Alamofire            │  ← 底层网络库
└─────────────────────────────────────┘
```

### 2. 核心组件

#### 2.1 协议抽象层 (iNtk)

- **iNtkClient**: 网络客户端协议，定义了请求执行的基本接口
- **iNtkRequest**: 请求协议，封装了HTTP请求的所有必要信息
- **iNtkResponse**: 响应协议，定义了响应数据的标准结构
- **iNtkResponseValidation**: 响应验证协议，用于自定义响应验证逻辑
- **iNtkInterceptor**: 拦截器协议，支持请求/响应的拦截处理

#### 2.2 网络层实现

- **NtkNetwork**: 主要的用户接口类，提供链式调用API
- **NtkOperation**: 操作管理器，负责拦截器链的组织和执行
- **MoyaClient**: Moya集成实现，提供具体的网络请求能力

#### 2.3 拦截器系统

- **NtkInterceptorChainManager**: 拦截器链管理器
- **NtkValidationInterceptor**: 内置响应验证拦截器
- **NtkDefaultApiRequestHandler**: 默认API请求处理器

## 主要功能特性

### 1. 链式调用API

```swift
let network = NtkNetwork(client)
    .with(request)
    .validation(validator)
    .sendRequest<ResponseModel>()
```

### 2. 拦截器模式

- **优先级系统**: 支持高、中、低三级优先级
- **责任链模式**: 请求按优先级依次通过拦截器处理
- **可扩展性**: 支持自定义拦截器实现特定业务逻辑

### 3. 灵活的响应处理

#### 3.1 动态类型支持

- **NtkReturnCode**: 支持多种数据类型的返回码（String、Int、Bool、Double）
- **泛型响应**: 支持任意 Codable 类型的响应数据
- **空响应处理**: 通过 NtkNever 类型处理无数据响应

#### 3.2 自定义键映射

```swift
protocol NtkResponseMapKeys {
    static var code: String { get }
    static var data: String { get }
    static var msg: String { get }
}
```

### 4. 完善的错误处理

```swift
enum NtkError: Error {
    case validation(_ request: iNtkRequest, _ response: Any)
    case jsonInvalid(_ request: iNtkRequest, _ response: Any)
    case decodeInvalid(_ error: Error, _ request: iNtkRequest, _ response: Any)
    case retDataError
    case retDataTypeError
    case other(_ error: Error)
}
```

### 5. Objective-C 兼容性

- 所有主要类都继承自 NSObject
- 使用 @objcMembers 标记确保 OC 可访问性
- 提供 NtkOCError 类用于 OC 错误处理

## 技术特点

### 1. 协议导向设计

- 高度抽象的协议定义，便于测试和扩展
- 依赖注入友好，支持不同的网络库实现
- 清晰的职责分离

### 2. 异步编程支持

- 基于 Swift async/await 的现代异步API
- 支持请求取消和状态查询
- 线程安全的设计

### 3. 类型安全

- 强类型的泛型设计
- 编译时类型检查
- 避免运行时类型转换错误

### 4. 可扩展架构

- 插件化的拦截器系统
- 支持自定义网络客户端实现
- 灵活的响应验证机制

## 使用场景

### 1. 企业级应用

- 复杂的API交互需求
- 统一的错误处理和日志记录
- 多环境配置支持

### 2. 中间件开发

- 网络层抽象封装
- 第三方SDK集成
- 通用网络组件开发

### 3. 测试友好

- Mock数据支持
- 单元测试便利
- 集成测试支持

## 核心流程

### 请求执行流程

1. **初始化**: 创建 NtkNetwork 实例并配置客户端
2. **请求配置**: 通过链式调用设置请求和验证器
3. **拦截器链构建**: 按优先级组织拦截器链
4. **请求执行**: 通过拦截器链处理请求
5. **响应处理**: 解析响应数据并进行类型转换
6. **验证**: 执行响应验证逻辑
7. **结果返回**: 返回类型安全的响应对象

### 拦截器执行机制

```
请求 → 拦截器1 → 拦截器2 → ... → 网络请求 → 响应
     ←         ←         ← ... ←           ←
```

## 设计模式应用

1. **责任链模式**: 拦截器链的实现
2. **策略模式**: 不同的响应验证策略
3. **适配器模式**: Moya集成适配
4. **工厂模式**: 客户端和拦截器的创建
5. **观察者模式**: 请求状态的监听

## 性能特性

- **内存效率**: 协议引用和值类型的合理使用
- **并发安全**: 异步操作的线程安全保证
- **资源管理**: 自动的请求取消和资源释放
- **缓存支持**: 预留缓存扩展接口

## 总结

CNtk 框架通过现代化的 Swift 设计理念，提供了一个功能完善、架构清晰的网络请求解决方案。其协议导向的设计使得框架具有良好的可测试性和可扩展性，拦截器模式为复杂的业务需求提供了灵活的处理机制。框架既保持了类型安全，又提供了与 Objective-C 的良好兼容性，适合在各种 iOS 项目中使用。