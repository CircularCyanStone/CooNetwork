//
//  iNtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 在Swift6模式下需要关注Sendable协议。
/// 因为iNtkResponse必然要跨隔离域传递

/// 定义该抽象类，可以通过any iNtkResponse抹掉实际NtkResponse在网络框架中传递时的泛型约束。
/// 因为网络框架内不并不关心实际的响应类型。只有业务层才关心ResponseData的数据类型。
protocol iNtkResponse: Sendable {
    
    associatedtype ResponseData
    
    var code: NtkReturnCode { get }
    
    var data: ResponseData { get }
    
    var msg: String? { get }
    
    var response: Sendable { get }
    
    var request: iNtkRequest { get }
}
