//
//  RpcRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/7.
//

import Foundation

protocol RpcRequestToast {
    
    var toastRetErrorMsg: Bool { get }
    
    var toastSystemErrorMsg: Bool { get }
    
}

protocol RpcRequest: iNtkRequest, RpcRequestToast {
    
    /// RPC接口模型解析，因需要兼容OC版本，无法使用Decodable协议统一解析，所以每个接口需要手动解析
    /// - Parameter retData: 接口返回的retData数据
    /// - Returns: 解析后的数据
    func OCResponseDataParse(_ retData: Any) throws -> Any
    
}

extension RpcRequest  {
    var toastRetErrorMsg: Bool {
        true
    }
    
    var toastSystemErrorMsg: Bool {
        true
    }
}
