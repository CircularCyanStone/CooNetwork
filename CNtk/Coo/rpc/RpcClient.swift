//
//  RpcClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation
import NtkNetwork

/// RPC客户端实现
/// 负责执行RPC网络请求，支持泛型响应键映射和缓存功能
/// 集成了DTRpc框架进行底层网络通信
class RpcClient<Keys: iNtkResponseMapKeys>: iNtkClient {
    
    /// 缓存存储实现
    var storage: any iNtkCacheStorage = RpcCacheStorage()
    
    /// 请求包装器
    var requestWrapper: NtkRequestWrapper = NtkRequestWrapper()
    
    /// 当前请求对象
    private var request: iNtkRequest? {
        requestWrapper.request
    }
    
    /// 执行网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    func execute() async throws -> NtkClientResponse {
        try await sendRpcRequest()
    }
    
    /// 发送RPC请求
    /// 使用DTRpc框架执行底层网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    private func sendRpcRequest() async throws -> NtkClientResponse {
        guard let request = requestWrapper.request as? iRpcRequest else {
            fatalError("request must be iRpcRequest")
        }
        let method = DTRpcMethod()
        method.operationType = request.path
        method.checkLogin = request.checkLogin
        method.timeoutInterval = request.timeout
        method.returnType = "@\"NSDictionary\""
        let parameters = request.parameters ?? [:]
        let headers = request.headers ?? [:]
        
        try Task.checkCancellation()
        let response: Sendable = try await withUnsafeThrowingContinuation { continuation in
            DTRpcAsyncCaller.callSwiftAsyncBlock {
                let responseObject = DTRpcClient.default().execute(method, params: [parameters], requestHeaderField: headers) { headerFile in
                    
                }
                if let responseObject {
                    if let responseDict = responseObject as? [String: any Sendable] {
                        continuation.resume(returning: responseDict)
                    }else if let responseArray = responseObject as? [any Sendable] {
                        continuation.resume(returning: responseArray)
                    }else {
                        continuation.resume(throwing: NtkError.Rpc.responseTypeError)
                    }
                }else {
                    continuation.resume(throwing: NtkError.Rpc.responseEmpty)
                }
            } completion: { error in
                if let error {
                    // 接口报错时会走这里
                    let nsError = error as NSError
                    if nsError.domain == kDTRpcException, let sysError = nsError.userInfo[kDTRpcErrorCauseError] as? URLError {
                        /// mPaaS错误类型
                        if sysError.code == .timedOut {
                            /// 统一超时的错误码
                            continuation.resume(throwing: NtkError.requestTimeout)
                        }else {
                            continuation.resume(throwing: NtkError.other(sysError))
                        }
                    }else {
                        continuation.resume(throwing: NtkError.other(error))
                    }
                }
            }
        }
        try Task.checkCancellation()
        return NtkClientResponse(data: response, msg: nil, response: response, request: request, isCache: false)
    }
}
