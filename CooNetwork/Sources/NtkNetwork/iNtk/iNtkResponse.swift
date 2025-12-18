//
//  iNtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 网络响应协议
/// 在Swift6模式下需要关注Sendable协议，因为iNtkResponse必然要跨隔离域传递
/// 定义该抽象协议，可以通过any iNtkResponse抹掉实际NtkResponse在网络框架中传递时的泛型约束
/// 网络框架内部不关心实际的响应类型，只有业务层才关心ResponseData的数据类型
public protocol iNtkResponse: Sendable {
    
    /// 响应数据的关联类型
    associatedtype ResponseData
    
    /// 服务端返回的状态码
    /// - Returns: 业务状态码，用于判断请求是否成功
    var code: NtkReturnCode { get }
    
    /// 响应的业务数据
    /// - Returns: 解析后的业务数据
    var data: ResponseData { get }
    
    /// 服务端返回的消息
    /// - Returns: 错误信息或成功提示，可选
    var msg: String? { get }
    
    /// 原始响应数据
    /// - Returns: 未解析的原始响应数据
    var response: Sendable { get }
    
    /// 对应的请求对象
    /// - Returns: 产生此响应的原始请求
    var request: iNtkRequest { get }
    
    /// 是否是缓存
    var isCache: Bool { get }
}
