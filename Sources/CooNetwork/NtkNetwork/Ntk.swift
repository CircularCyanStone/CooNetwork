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
    ///   - responseParser: 数据解析拦截器
    ///   - cacheStorage: 缓存存储器（可选）
    /// - Returns: 配置好的 NtkNetwork 实例
    public static func with(_ client: iNtkClient, request: iNtkRequest, responseParser: iNtkResponseParser, cacheStorage: iNtkCacheStorage? = nil) -> NtkNetwork<ResponseData> {
        var interceptors: [iNtkInterceptor] = []
        if let storage = cacheStorage {
            interceptors.append(NtkCacheInterceptor(storage: storage))
        }

        let net = NtkNetwork<ResponseData>.with(client, request: request, responseParser: responseParser, interceptors: interceptors)
        return net
    }

}
