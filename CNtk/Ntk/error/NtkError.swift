//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

enum NtkError: Error {
    
    // 服务端对接口成功和失败逻辑 校验没通过。
    case validation(_ request: iNtkRequest, _ response: any iNtkResponse)
    
    // 接口返回数据不是有效的json数据
    case jsonInvalid(_ request: iNtkRequest, _ response: Sendable)
    
    // deocode解码成模型时，发生错误
    case decodeInvalid(_ error: Error, _ request: iNtkRequest, _ response: Sendable)
    
    // 服务端jSON里的data字段是空的。
    case serviceDataEmpty
    
    // 服务端返回JSON里的data和泛型类型不匹配
    case serviceDataTypeInvalid
    
    // 其他类型错误
    case other(_ error: Error)
    
    // 缓存一类的错误
    enum Cache: Error {
        case noCache
    }
}
