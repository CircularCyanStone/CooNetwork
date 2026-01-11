//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络请求管理器
/// 负责管理网络请求的生命周期，包括请求执行、取消、缓存等功能
/// 支持泛型响应数据类型，提供类型安全的网络请求接口
///
/// **设计说明**：
/// NtkNetwork 作为一个 Configurator/Builder，负责收集请求配置。
/// 所有的配置方法（如 addInterceptor）都是非隔离的，支持同步链式调用。
/// 实际的请求执行委托给内部的 NtkNetworkExecutor (Actor) 处理。
/// 使用 @unchecked Sendable 是因为我们使用内部锁来保护可变状态，
/// 并且设计意图是作为单线程配置器使用。
public final class NtkNetwork<ResponseData: Sendable>: @unchecked Sendable {
    
    /// 响应结果枚举，用于区分缓存和网络响应
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
    
    /// 网络客户端实现
    private var client: any iNtkClient
    
    /// 数据解析插件
    private var dataParsingInterceptor: iNtkInterceptor

    private var mutableRequest: NtkMutableRequest
    
    /// 响应验证器
    private var validation: iNtkResponseValidation?
    
    /// 存储所有注册的自定义拦截器
    private var _interceptors: [iNtkInterceptor] = []
    
    // 注意：由于是 Sendable 类且有可变属性，理论上需要锁保护。
    // 但作为 Builder，通常在单线程构建。
    // 这里为了严格符合 Swift 6，我们使用 @unchecked Sendable 并添加内部锁，
    // 或者，鉴于我们现在是在主线程或其他线程构建，而 client/request 是值类型或不可变的，
    // 我们暂时依靠使用者的单线程构建习惯。
    // 但为了绝对安全，我们在这里使用简单的锁保护配置状态。
    private let lock = NtkUnfairLock()
    
    /// 按优先级排序的自定义拦截器列表
    private var interceptors: [iNtkInterceptor] {
        get {
            return lock.withLock {
                _interceptors.sorted { $0.priority > $1.priority }
            }
        }
        set {
            lock.withLock {
                _interceptors = newValue
            }
        }
    }
    
    /// 存储所有核心拦截器
    private var _coreInterceptors: [iNtkInterceptor] = []
    
    /// 本地记录的取消状态（用于同步返回）
    private var _isCancelled: Bool = false
    
    /// 按优先级排序的核心拦截器列表
    private var coreInterceptors: [iNtkInterceptor] {
        get {
            return lock.withLock {
                _coreInterceptors.sorted { $0.priority > $1.priority }
            }
        }
        set {
            lock.withLock {
                _coreInterceptors = newValue
            }
        }
    }
    
    /// 检查当前请求是否已被取消
    public var isCancelled: Bool {
        return lock.withLock {
            _isCancelled
        }
    }
    
    
    /// 初始化网络请求管理器
    /// - Parameters:
    ///   - client: 网络客户端实现
    ///   - request: 网络请求对象
    ///   - dataParsingInterceptor: 响应解析插件
    ///   - validation: 响应验证器
    ///   - interceptors: 初始拦截器列表
    public required init(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation, interceptors: [iNtkInterceptor] = []) {
        self.client = client
        self.mutableRequest = NtkMutableRequest(request)
        self.dataParsingInterceptor = dataParsingInterceptor
        self.validation = validation
        self._interceptors = interceptors
    }
    
    /// 创建网络请求管理器的便捷方法
    /// - Parameters:
    ///   - client: 网络客户端实现
    ///   - request: 网络请求对象
    ///   - dataParsingInterceptor: 响应解析插件
    ///   - validation: 响应验证器
    ///   - interceptors: 初始拦截器列表
    /// - Returns: 配置好的网络请求管理器实例
    public class func with(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation, interceptors: [iNtkInterceptor] = []) -> Self {
        let net = self.init(client, request: request, dataParsingInterceptor: dataParsingInterceptor, validation: validation, interceptors: interceptors)
        return net
    }
    
}
private extension NtkNetwork {
    /// 添加核心拦截器
    /// - Parameter i: 拦截器实现
    func addCoreInterceptor(_ i: iNtkInterceptor) {
        lock.withLock {
            _coreInterceptors.append(i)
        }
    }
    
}

extension NtkNetwork {
    
    /// 添加拦截器
    /// - Parameter i: 拦截器实现
    /// - Returns: 当前实例，支持链式调用
    @discardableResult
    public func addInterceptor(_ i: iNtkInterceptor) -> Self {
        lock.withLock {
            _interceptors.append(i)
        }
        return self
    }
    
    /// 设置响应验证器
    /// - Parameter validation: 响应验证实现
    /// - Returns: 当前实例，支持链式调用
    @discardableResult
    public func validation(_ validation: iNtkResponseValidation) -> Self {
        lock.withLock {
            self.validation = validation
        }
        return self
    }
    
    /// 取消当前请求
    public func cancel() {
        // 1. 本地标记取消
        lock.withLock {
            _isCancelled = true
        }
        
        // 2. 异步通知 TaskManager 取消实际任务
        // 必须拷贝 request 以避免并发访问
        // 注意：这里我们假设 cancelRequest 只需要 request 中的标识符信息，而这些信息在请求构建初期已确定
        // NtkRequestIdentifierManager 已改为线程安全，可以同步调用
        let requestToCancel = mutableRequest
        
        Task {
            await NtkTaskManager.cancelRequest(request: requestToCancel)
        }
    }
    
    
    
    public func setRequestValue(_ value: Sendable, forKey key: String) {
        lock.withLock {
            mutableRequest[key] = value
        }
    }
    
    /// 发送网络请求
    /// 异步执行网络请求并返回响应结果
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    @discardableResult
    public func request() async throws -> NtkResponse<ResponseData> {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }

        // 1. 创建 Executor 并传递配置快照
        // 注意：这里传递的是值类型(NtkMutableRequest)的拷贝和引用类型的引用(Client, Interceptors)
        // Client 和 Interceptors 必须是 Sendable 的
        let executor = lock.withLock {
            NtkNetworkExecutor<ResponseData>(
                client: client,
                request: mutableRequest,
                interceptors: _interceptors,
                coreInterceptors: _coreInterceptors,
                validation: validation,
                dataParsingInterceptor: dataParsingInterceptor
            )
        }
        
        // 2. 委托执行
        return try await executor.execute()
    }
    
    /// 加载缓存数据
    /// 直接通过缓存请求处理器读取缓存，跳过拦截器链
    /// - Returns: 缓存的响应对象，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    public func loadCache() async throws -> NtkResponse<ResponseData>? {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }

        let executor = lock.withLock {
            NtkNetworkExecutor<ResponseData>(
                client: client,
                request: mutableRequest,
                interceptors: _interceptors,
                coreInterceptors: _coreInterceptors,
                validation: validation,
                dataParsingInterceptor: dataParsingInterceptor
            )
        }
        
        return try await executor.loadCache()
    }
    
    /// 便捷发起网络请求并加载缓存
    ///
    /// 此方法会同时发起网络请求和加载缓存，并通过异步序列返回结果。
    /// 设计原则是优先显示缓存，网络请求返回后再刷新数据，以优化用户体验。
    ///
    /// - Returns: 异步序列，按完成顺序返回缓存和网络响应
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误
    public func requestWithCache() -> AsyncThrowingStream<NtkResponse<ResponseData>, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var networkReturnedFirst = false
                    try await withThrowingTaskGroup(of: ResponseResult.self) { group in
                        // 并发加载缓存
                        group.addTask {
                            do {
                                return .cache(try await self.loadCache())
                            } catch {
                                print("startWithCache 缓存加载失败，但不影响网络请求: \(error)")
                                return .cache(nil)
                            }
                        }

                        // 并发发起网络请求
                        group.addTask {
                            return .network(try await self.request())
                        }

                        // 按完成顺序处理结果
                        for try await result in group {
                            switch result {
                            case .network(let response):
                                networkReturnedFirst = true
                                continuation.yield(response)
                                // 网络请求成功后，可以取消其他任务并提前结束
                                group.cancelAll()
                                
                            case .cache(let response):
                                if !networkReturnedFirst, let response = response {
                                    continuation.yield(response)
                                }
                            }
                        }
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable termination in
                switch termination {
                case .cancelled:
                    // 只有在流被取消时才取消底层任务
                    // 这通常发生在业务层主动取消或者上层作用域被取消
                    print("AsyncStream 被取消，取消底层任务")
                    task.cancel()
                case .finished:
                    // 流正常结束或因错误结束，不需要取消任务
                    // 因为任务要么已经完成，要么已经在 catch 块中处理了错误
                    print("AsyncStream 正常结束，无需取消任务")
                @unknown default:
                    fatalError("unknown")
                }
            }
        }
    }
    
}

extension NtkNetwork where ResponseData == Bool {
    /// 判断是否存在缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasCacheData() async -> Bool {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }

        let executor = lock.withLock {
            NtkNetworkExecutor<Bool>(
                client: client,
                request: mutableRequest,
                interceptors: _interceptors,
                coreInterceptors: _coreInterceptors,
                validation: validation,
                dataParsingInterceptor: dataParsingInterceptor
            )
        }
        
        return await executor.hasCacheData()
    }
}
