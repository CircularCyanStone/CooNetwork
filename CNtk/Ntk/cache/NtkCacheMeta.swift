//
//  NtkCacheMeta.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

struct NtkCacheMeta: Sendable {
    
    // 缓存数据版本号
    let appVersion: String
    
    // 缓存构建日期
    let creationDate: TimeInterval
    
    // 缓存过期时间
    let expirationDate: TimeInterval
    
    // 缓存数据
    let data: Sendable
    
    init(appVersion: String, creationDate: TimeInterval, expirationDate: TimeInterval, data: Sendable) {
        self.appVersion = appVersion
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.data = data
    }
}
