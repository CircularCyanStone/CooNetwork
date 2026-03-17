# Architecture

## 设计目标

CooNetwork 的核心设计目标是为不同的网络组件提供统一的接入方式，使用 Swift 6 并发模型确保线程安全。

## 核心架构

### 双层设计

1. **配置层 (NtkNetwork)** - 非 Actor 的 Builder 模式类
   - 负责收集请求配置和拦截器
   - 支持同步链式调用
   - 使用 `@unchecked Sendable` 配合内部锁保护可变状态
2. **执行层 (NtkNetworkExecutor)** - Actor 类
   - 处理实际的请求执行
   - 管理拦截器链调用
   - 所有执行逻辑在隔离域内，保证线程安全

### NtkActor 机制

项目使用自定义的 `@NtkActor` 宏/标记来管理并发隔离：

- 拦截器方法标记为 `@NtkActor`
- 客户端执行方法标记为 `@NtkActor`
- 执行器和上下文是 `@NtkActor` 隔离的

这种设计允许：

- 配置层支持同步链式调用（非隔离）
- 执行层保持线程安全和并发隔离（Actor 隔离）

## 模块划分

### CooNetwork (核心库)

```
Sources/CooNetwork/
├── NtkNetwork/
│   ├── iNtk/           # 核心协议定义
│   ├── model/          # 数据模型
│   ├── interceptor/      # 拦截器基础设施
│   ├── cache/          # 缓存系统
│   ├── retry/          # 重试机制
│   ├── deduplication/   # 去重机制
│   ├── UI/             # UI 相关拦截器
│   └── lock/           # 并发锁
```

### AlamofireClient (Alamofire 实现)

```
Sources/AlamofireClient/
├── Client/         # AF 客户端实现
├── Interceptor/    # AF 特定拦截器
└── Error/          # AF 错误处理
```

## 关键设计决策

### 为什么使用双层设计？

配置方法需要支持链式调用，而执行逻辑需要并发隔离。单层设计要么无法链式调用，要么无法保证线程安全。

### 为什么使用 @NtkActor 而不是全局 Actor？

这里的“不是全局 Actor”指的不是 Swift 语法层面的 `@globalActor` 定义方式，而是避免直接依赖默认全局并发上下文。  
`@NtkActor` 本身是一个自定义 `@globalActor`，用于把网络相关执行收敛到统一隔离域，同时将隔离范围限制在网络模块内部，减少不必要的跨域传递。

### 拦截器优先级设计

```
高优先级 (1000):  先执行（请求流）或后执行（响应流）
中等优先级 (750):   默认
低优先级 (250):    后执行（请求流）或先执行（响应流）
```

这种设计允许灵活控制拦截器执行顺序，例如认证拦截器可以在请求前添加 token，日志拦截器在最后记录完整请求。

## 模块职责

### iNtk/ (接口层)

定义所有核心协议：

- `iNtkClient` - 网络客户端抽象
- `iNtkRequest` - 请求定义
- `iNtkResponse` - 响应抽象
- `iNtkInterceptor` - 拦截器接口
- `iNtkResponseValidation` - 响应验证

### model/ (数据层)

定义可变的数据结构：

- `NtkMutableRequest` - 可修改的请求对象
- `NtkClientResponse` - 客户端原始响应
- `NtkResponse<T>` - 类型安全的响应包装

### interceptor/ (拦截器基础设施)

提供拦截器链的基础设施：

- `NtkInterceptorChainManager` - 责任链管理
- `NtkInterceptorContext` - 请求上下文
- `iNtkRequestHandler` - 请求处理器接口

### cache/ (缓存系统)

完整的缓存解决方案：

- `iNtkCacheStorage` - 存储抽象
- `NtkNetworkCache` - 缓存管理
- `NtkCacheMeta` - 缓存元数据
- `NtkRequestIdentifierManager` - 缓存键管理

## 扩展性

项目设计支持多种网络实现：

1. 实现 `iNtkClient` 协议
2. 提供 `iAFRequest` 等请求定义
3. 实现 `iNtkResponseMapKeys` 响应映射

Alamofire 实现是官方提供的参考实现。

## 相关策略

- [fatalError 使用策略](./fatal-error-policy.md)
