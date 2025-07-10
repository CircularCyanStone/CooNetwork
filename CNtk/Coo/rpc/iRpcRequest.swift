//
//  RpcRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/7.
//

import Foundation

protocol iRpcRequestToast {
    
    /// 是否显示后端的错误信息
    var toastRetErrorMsg: Bool { get }
    
    /// 是否显示系统的错误信息
    var toastSystemErrorMsg: Bool { get }
    
}

protocol iRpcRequest: iNtkRequest, iRpcRequestToast {
    
    /// RPC接口模型解析，因需要兼容OC版本，无法使用Decodable协议统一解析，所以每个接口需要手动解析
    /// - Parameter retData: 接口返回的retData数据
    /// - Returns: 解析后的数据
    func OCResponseDataParse(_ retData: Any) throws -> Any
    
}

extension iRpcRequest  {
    var toastRetErrorMsg: Bool {
        true
    }
    
    var toastSystemErrorMsg: Bool {
        true
    }
}
