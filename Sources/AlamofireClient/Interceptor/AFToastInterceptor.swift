//
//  AFToastInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif

/// AF请求默认的Toast处理逻辑。
public struct AFToastInterceptor: iNtkInterceptor {
    
    /// Toast显示回调
    /// - Parameter msg: 需要显示的消息内容
    public typealias ToastHandler = @Sendable (String) -> Void
    
    /// Toast处理闭包
    private let toastHandler: ToastHandler
    
    /// 需要忽略的不做默认处理的code。
    public let ignoreCode: [Int]
    
    /// 初始化
    /// - Parameters:
    ///   - ignoreCode: 需要忽略的错误码
    ///   - toastHandler: Toast显示逻辑闭包
    public init(ignoreCode: [Int] = [], toastHandler: @escaping ToastHandler) {
        self.ignoreCode = ignoreCode
        self.toastHandler = toastHandler
    }
    
    /// 拦截请求并处理错误 Toast 提示
    public func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        guard let afRequest = context.mutableRequest.originalRequest as? iAFRequest else {
            return try await next.handle(context: context)
        }
        do {
            let response = try await next.handle(context: context)
            return response
        } catch let error as NtkError {
            handleNtkError(error, request: afRequest)
            throw error
        } catch {
            throw error
        }
    }
    
    private func handleNtkError(_ error: NtkError, request: iAFRequest) {
        if case let .responseValidationFailed(reason) = error,
           case let .serviceRejected(_, response) = reason {
            if ignoreCode.contains(response.code.intValue) {
                return
            }
            if request.toastRetErrorMsg(response.code.stringValue), let msg = response.msg {
                toastHandler(msg)
            }
        } else if case .requestTimeout = error {
            toastHandler("连接超时~")
        } else if case let .clientFailed(clientError) = error {
            handleClientError(clientError)
        }
    }

    private func handleClientError(_ failure: NtkClientError) {
        switch failure {
        case let .external(reason, _, _, underlyingError, message):
            guard reason is NtkClientError.AF else { return }
            if let urlError = underlyingError as? URLError {
                handleSystemError(urlError as NSError)
                return
            }
            if let message {
                toastHandler(message)
            }
        }
    }
    
    private func handleSystemError(_ error: NSError) {
        // 这里处理系统错误消息
        // 简单使用 localizedDescription
        // 可以在这里根据 error.code 做更细致的错误文案映射
        let msg = error.localizedDescription
        toastHandler(msg)
    }
}
