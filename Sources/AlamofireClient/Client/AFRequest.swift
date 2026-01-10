//
//  AFRequest.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork
import Alamofire

/// AF请求的toast管理协议，用于定制不同接口在 后端/系统 错误信息时的默认处理方案。
public protocol iAFRequestToast {
    
    /// 是否显示后端的错误信息
    func toastRetErrorMsg(_ code: String) -> Bool
    
    /// 是否显示系统的错误信息
    var toastSystemErrorMsg: Bool { get }
    
}

/// AF请求的抽象描述，用于定义一个AF接口
/// 继承自 iNtkRequest 并扩展了对 Alamofire 高级特性的支持
public protocol iAFRequest: iNtkRequest, iAFRequestToast {
    
    /// 接口是否需要用户登录
    var checkLogin: Bool { get }
    
    /// 是否是加密接口
    var isEncrypt: Bool { get }
    
    /// 拆包返回值retData
    /// - Parameter retData: 后端的retData
    /// - Returns: 拆包后的数据
    func unwrapRetureData(_ retData: Sendable) -> Sendable
    
    /// 是否启用自定义响应数据解码
    /// 当设置为true时，将使用customResponseDataDecode方法进行手动解码
    /// 当设置为false时，将使用默认的JSONDecoder自动解码
    /// 当 开发者设置retData的类型是String、 Bool、Int、[String: Sendable]类型时，默认为true
    var enableCustomRetureDataDecode: Bool { get }
    
    /// 自定义AF响应数据解码器
    /// 用于处理无法使用Decodable协议统一解析的场景，如：
    /// 1. 返回值是基础类型而非模型对象
    /// 2. 需要特殊的数据转换逻辑
    /// 提供开发者最大的控制权限进行数据解析
    /// - Parameter retData: 接口返回的retData数据
    /// - Returns: 解析后的数据
    func customRetureDataDecode(_ retData: Sendable) throws -> Sendable
    
    // MARK: - Alamofire特定配置
    
    /// 参数编码方式
    /// 允许每个接口单独配置编码方式（JSON、URL、自定义等）
    var encoding: ParameterEncoding { get }
    
    /// 请求验证规则
    /// 自定义HTTP状态码验证逻辑
    var validation: DataRequest.Validation? { get }
    
    /// 请求修饰器
    /// 在发送前对URLRequest进行最后修改
    var requestModifier: Session.RequestModifier? { get }
}

extension iAFRequest  {
    
    public var checkLogin: Bool {
        true
    }
    
    public var isEncrypt: Bool {
        false
    }
    
    public func toastRetErrorMsg(_ code: String) -> Bool {
        true
    }
    
    public var toastSystemErrorMsg: Bool {
        true
    }
    
    public func unwrapRetureData(_ retData: Sendable) -> Sendable {
        retData
    }
    
    /// 默认不启用自定义响应数据解码，使用JSONDecoder自动解码
    public var enableCustomRetureDataDecode: Bool {
        false
    }
    
    /// 默认的自定义解码实现，直接返回原始数据
    public func customRetureDataDecode(_ retData: Sendable) throws -> Sendable {
        return retData
    }
    
    // MARK: - Alamofire默认实现
    
    /// 默认使用JSON编码（POST/PUT/PATCH）或URL编码（GET）
    public var encoding: ParameterEncoding {
        URLEncoding.default
    }
    
    /// 默认验证200-299状态码
    public var validation: DataRequest.Validation? {
        return nil // 使用Alamofire默认验证
    }
    
    /// 默认无请求修饰
    public var requestModifier: Session.RequestModifier? {
        return nil
    }
}
