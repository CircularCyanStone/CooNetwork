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
    
    var checkLogin: Bool { get }
    
    /// 是否启用自定义响应数据解码
    /// 当设置为true时，将使用customResponseDataDecode方法进行手动解码
    /// 当设置为false时，将使用默认的JSONDecoder自动解码
    /// 当 开发者设置retData的类型是String、 Bool、Int、[String: Sendable]类型时，默认为true
    var enableCustomRetureDataDecode: Bool { get }
    
    /// 自定义RPC响应数据解码器
    /// 用于处理无法使用Decodable协议统一解析的场景，如：
    /// 1. 需要兼容OC版本的接口
    /// 2. 返回值是基础类型而非模型对象
    /// 3. 需要特殊的数据转换逻辑
    /// 提供开发者最大的控制权限进行数据解析
    /// - Parameter retData: 接口返回的retData数据
    /// - Returns: 解析后的数据
    func customRetureDataDecode(_ retData: Sendable) throws -> Sendable
    
}

extension iRpcRequest  {
    
    var checkLogin: Bool {
        true
    }
    
    /// 默认不启用自定义响应数据解码，使用JSONDecoder自动解码
    var enableCustomRetureDataDecode: Bool {
        false
    }
    
    var toastRetErrorMsg: Bool {
        true
    }
    
    var toastSystemErrorMsg: Bool {
        true
    }
    
    /// 默认的自定义解码实现，直接返回原始数据
    func customRetureDataDecode(_ retData: Sendable) throws -> Sendable {
        return retData
    }
}
