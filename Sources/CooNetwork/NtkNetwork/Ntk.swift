//
//  Ntk.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/3.
//

import Foundation

typealias NtkBool = Ntk<Bool>

/// 网络请求便捷入口
/// 封装 NtkNetwork 的创建逻辑，自动处理验证器选择和缓存拦截器注入
@NtkActor
public final class Ntk<ResponseData: Sendable> {

    nonisolated
    /// 创建配置好的网络请求管理器
    /// - Parameters:
    ///   - client: 网络客户端
    ///   - request: 请求对象
    ///   - dataParsingInterceptor: 数据解析拦截器
    ///   - validation: 响应验证器
    ///   - cacheStorage: 缓存存储器（可选）
    /// - Returns: 配置好的 NtkNetwork 实例
    public static func with(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation, cacheStorage: (any iNtkCacheStorage)? = nil) -> NtkNetwork<ResponseData> {
        var _validation: iNtkResponseValidation
        if let requestValidation = request as? iNtkResponseValidation {
            _validation = requestValidation
        }else {
            _validation = validation
        }

        var interceptors: [iNtkInterceptor] = []
        if let storage = cacheStorage {
            interceptors.append(NtkCacheInterceptor(storage: storage))
        }

        let net = NtkNetwork<ResponseData>.with(client, request: request, dataParsingInterceptor: dataParsingInterceptor, validation: _validation, interceptors: interceptors)
        return net
    }

}
