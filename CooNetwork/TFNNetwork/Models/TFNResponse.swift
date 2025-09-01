import Foundation
import CodableWrappers

/// 网络组件编码键
/// 实现CodingKey协议，支持动态键名的JSON解码
struct TNFCodingKeys: CodingKey {
    /// 字符串形式的键值
    let stringValue: String
    
    /// 整数形式的键值（可选）
    let intValue: Int?
    
    /// 通过字符串初始化编码键
    /// - Parameter stringValue: 字符串键值
    init?(stringValue: String) {
        self.stringValue = stringValue
        if let intValue = Int(stringValue) {
            self.intValue = intValue
        }else {
            self.intValue = nil
        }
    }
    
    /// 通过整数初始化编码键
    /// - Parameter intValue: 整数键值
    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    /// 通过其他CodingKey初始化
    /// - Parameter base: 基础编码键
    init<Key>(_ base: Key) where Key: CodingKey {
        if let intValue = base.intValue {
            self.init(intValue: intValue)!
        } else {
            self.init(stringValue: base.stringValue)!
        }
    }
}


/// 网络响应解码器
/// 用于将JSON响应数据解码为结构化的响应对象
struct TFNResponseDecoder<ResponseData: Decodable, Keys: iTFNResponseMapKeys>: Decodable {
    
    /// 响应状态码
    let code: TFNReturnCode
    
    let data: ResponseData
    
    /// 响应消息（可选）
    let msg: String?
    
    /// 从解码器初始化响应对象
    /// - Parameter decoder: JSON解码器
    /// - Throws: 解码过程中的错误
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: TNFCodingKeys.self)
        
        let codeKey = TNFCodingKeys(stringValue: Keys.statusCodeKey)!
        self.code = try container.decode(TFNReturnCode.self, forKey: codeKey)
        
        let dataKey = TNFCodingKeys(stringValue: Keys.dataKey)!
        self.data = try container.decode(ResponseData.self, forKey: dataKey)
        
        let msgKey = TNFCodingKeys(stringValue: Keys.messageKey)!
        self.msg = try container.decodeIfPresent(String.self, forKey: msgKey)
    }
}


/// TFN响应结构体
struct TFNResponse<DataModel: Sendable & Decodable>: iTFNResponse {
    typealias DataType = DataModel
    
    var statusCode: TFNReturnCode
    let data: DataModel
    let message: String?
    var isCache: Bool = false
    let request: any iTFNRequest
    let response: Sendable
    
    /// 初始化网络响应对象
    /// - Parameters:
    ///   - code: 响应状态码
    ///   - data: 响应数据
    ///   - msg: 响应消息
    ///   - response: 原始响应数据
    ///   - request: 关联的请求对象
    init(code: TFNReturnCode, data: DataModel, msg: String?, response: Sendable, request: any iTFNRequest) {
        self.statusCode = code
        self.data = data
        self.message = msg
        self.response = response
        self.request = request
    }
}

struct TFNNever: Decodable {
    
}
