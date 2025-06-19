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
    var stringValue: String
    
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        if let intValue = Int(stringValue) {
            self.intValue = intValue
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

class NtkResponseModel<ResponseData: Codable, Keys: NtkResponseMapKeys>: NSObject, Decodable {
    
    let code: NtkReturnCode
    
    let data: ResponseData
    
    let msg: String
    
    required
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: NtkCodingKeys.self)
        
        let codeKey = NtkCodingKeys(stringValue: Keys.code)!
        self.code = try container.decode(NtkReturnCode.self, forKey: codeKey)
        
        let dataKey = NtkCodingKeys(stringValue: Keys.data)!
        self.data = try container.decode(ResponseData.self, forKey: dataKey)
        
        let msgKey = NtkCodingKeys(stringValue: Keys.msg)!
        self.msg = try container.decode(String.self, forKey: msgKey)
        super.init()
    }
}


/// 该类型用于在协议中移除Keys范型
final class NtkResponse<ResponseData: Codable>: NSObject {
    
    let code: NtkReturnCode
    
    let data: ResponseData
    
    let msg: String
    
    let response: Any
    
    let request: iNtkRequest
    
    init(code: NtkReturnCode, data: ResponseData, msg: String, response: Any, request: iNtkRequest) {
        self.code = code
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
    }
}


