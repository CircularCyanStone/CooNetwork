//
//  iNtkInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

enum iNtkInterceptorPriority: Int {
    case low    = 250
    case medium = 750
    case high   = 1000
}
extension Int {
    static let low: Int = .low
    static let medium: Int = .medium
    static let high: Int = .high
}

class NtkInterceptorPriority: Comparable {
    private(set) var value: Int = .medium
    
    required
    init() {
        
    }
    
    class func priority(_ value: Int) -> Self {
        var pValue: Int = value
        if pValue > .high {
            pValue = .high
        }
        let p = self.init()
        p.value = pValue
        return p
    }
    
    // 实现 Comparable 协议
    static func < (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        return lhs.value < rhs.value
    }

    static func == (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        return lhs.value == rhs.value
    }
}


protocol iNtkInterceptor {
    
    /// 拦截器优先级，默认iNtkInterceptorPriority.medium
    /// - note:对于请求流：值越大执行越早。
    ///        对于响应流：值越小执行越早
    var priority: NtkInterceptorPriority { get }
    
    func intercept(context: NtkRequestContext, next: NtkRequestHandler) async throws -> any iNtkResponse
    

    // 如果你需要更复杂的重试机制，可能需要一个单独的重试方法
    /// **（可选）错误重试判断方法**
    /// 在请求失败时调用，判断是否需要重试以及如何重试。
    /// - Parameters:
    ///   - error: 导致请求失败的错误。
    ///   - request: 原始的 `URLRequest`。
    ///   - retryCount: 当前已重试的次数。
    /// - Returns: `(shouldRetry: Bool, delay: TimeInterval?)` 指示是否重试以及重试前的延迟。
    func shouldRetry(error: Error, for request: iNtkRequest, retryCount: Int) -> (Bool, TimeInterval?)
}

// 为协议方法提供默认实现，以便具体拦截器可以只实现它们关心的部分
extension iNtkInterceptor {
    var priority: NtkInterceptorPriority {
        .priority(.medium)
    }
    
    func intercept(context: NtkRequestContext, next: NtkRequestHandler) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
    
    func shouldRetry(error: Error, for request: iNtkRequest, retryCount: Int) -> (Bool, TimeInterval?) {
        (false, nil)
    }
}
