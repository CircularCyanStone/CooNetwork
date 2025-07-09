//
//  NtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

protocol NtkResponseMapKeys {
    static var code: String { get }
    static var data: String { get }
    static var msg: String { get }
}


struct NtkCodingKeys: CodingKey {
    let stringValue: String
    
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        if let intValue = Int(stringValue) {
            self.intValue = intValue
        }else {
            self.intValue = nil
        }
    }
    
    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    init<Key>(_ base: Key) where Key: CodingKey {
        if let intValue = base.intValue {
            self.init(intValue: intValue)!
        } else {
            self.init(stringValue: base.stringValue)!
        }
    }
}

struct NtkResponseDecoder<ResponseData: Decodable, Keys: NtkResponseMapKeys>: Decodable {
    
    let code: NtkReturnCode
    
    /// 这里设置为可选是避免后端数据 不存在/类型不匹配/Null 时，导致崩溃
    /// 后续交由开发者手动处理data = nil的情况
    let data: ResponseData?
    
    let msg: String?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: NtkCodingKeys.self)
        
        let codeKey = NtkCodingKeys(stringValue: Keys.code)!
        self.code = try container.decode(NtkReturnCode.self, forKey: codeKey)
        
        let dataKey = NtkCodingKeys(stringValue: Keys.data)!
        self.data = try container.decodeIfPresent(ResponseData.self, forKey: dataKey)
        
        let msgKey = NtkCodingKeys(stringValue: Keys.msg)!
        self.msg = try container.decodeIfPresent(String.self, forKey: msgKey)
    }
}


/// 该类型用于在抽象协议中使用
/// 同时也是为了避免NtkResponseDecoder中范型Keys在抽象协议中被要求
struct NtkResponse<ResponseData: Sendable>: iNtkResponse, Sendable {
    
    let code: NtkReturnCode
    
    let data: ResponseData
    
    let msg: String?
    
    let response: Sendable
    
    let request: iNtkRequest
    
    init(code: NtkReturnCode, data: ResponseData, msg: String?, response: Sendable, request: iNtkRequest) {
        self.code = code
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
    }
    
}

