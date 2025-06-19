//
//  iNtkResponseValidation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

protocol iNtkResponseValidation {
    
    /// 接口在服务端是否验证成功
    /// - note:针对个别接口如果使用到response.data，可以强制类型转换
    /// - Parameter response: 响应
    /// - Returns: true服务端验证通过，false服务端验证失败
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool
    
}
