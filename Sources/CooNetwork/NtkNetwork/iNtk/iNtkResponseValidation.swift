//
//  iNtkResponseValidation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 响应业务成功判定协议
/// 供解析策略在形成 `NtkResponse` 后判断该响应是否表示业务成功
public protocol iNtkResponseValidation: Sendable {

    /// 判断接口在服务端是否业务成功
    /// - Note: 如需依赖 `response.data`，可在实现中自行做类型转换
    /// - Parameter response: 已构建完成的响应对象
    /// - Returns: true 表示业务成功，false 表示业务失败
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool
    
}
