//
//  TFNCacheMeta.swift
//  TAIChat
//
//  Created by 李奇奇 on 2025/7/27.
//

import Foundation

final class TFNCacheMeta: NSObject, NSSecureCoding, Sendable {
    
    static var supportsSecureCoding: Bool {
        true
    }
    
    /// 缓存数据版本号
    /// 用于标识缓存数据对应的应用版本，便于版本升级时的缓存清理
    let appVersion: String
    
    /// 缓存创建时间
    /// 记录缓存数据的创建时间戳（毫秒），用于缓存统计和调试
    let creationDate: TimeInterval
    
    /// 缓存过期时间
    /// 缓存数据的过期时间戳（毫秒），超过此时间的缓存将被视为无效
    let expirationDate: TimeInterval
    
    /// 实际缓存数据
    /// 存储的网络响应数据，必须遵循Sendable协议以确保线程安全
    /// 支持类型[String:Sendable]、[Sendable]、String、Bool、Int
    let data: Sendable?
    
    /// 初始化缓存元数据
    /// - Parameters:
    ///   - appVersion: 应用版本号
    ///   - creationDate: 创建时间戳（毫秒）
    ///   - expirationDate: 过期时间戳（毫秒）
    ///   - data: 要缓存的数据
    init(appVersion: String, creationDate: TimeInterval, expirationDate: TimeInterval, data: Sendable?) {
        self.appVersion = appVersion
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.data = data
    }
    
    required
    init?(coder: NSCoder) {
        self.appVersion = coder.decodeObject(of: NSString.self, forKey: "appVersion")! as String
        self.creationDate = coder.decodeDouble(forKey: "creationDate")
        self.expirationDate = coder.decodeDouble(forKey: "expirationDate")
        let data = coder.decodePropertyList(forKey: "data")
        
        if let data = data as? [String : Sendable] {
            self.data = data
        }else if let data = data as? [Sendable] {
            self.data = data
        }else if let data = data as? String {
            self.data = data
        }else if let data = data as? Bool {
            self.data = data
        }else if let data = data as? Int {
            self.data = data
        }else if let data = data as? Data {
            self.data = data
        }else {
            self.data = nil
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(appVersion, forKey: "appVersion")
        coder.encode(creationDate, forKey: "creationDate")
        coder.encode(expirationDate, forKey: "expirationDate")
        if let data {
            coder.encode(data, forKey: "data")
        }
    }
}
