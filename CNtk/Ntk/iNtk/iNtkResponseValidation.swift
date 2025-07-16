//
//  iNtkResponseValidation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 响应验证协议
/// 定义了网络响应的业务逻辑验证规则
protocol iNtkResponseValidation: Sendable {
    
    /// 判断接口在服务端是否验证成功
    /// 用于验证服务端返回的业务状态码是否表示成功
    /// - Note: 针对个别接口如果需要使用response.data，可以进行强制类型转换
    /// - Parameter response: 网络响应对象
    /// - Returns: true表示服务端验证通过，false表示服务端验证失败
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool
    
}
