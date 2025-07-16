//
//  NtkRequestWrapper.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

// 用于解决当用户使用enum实现iNtkRequest时无法使用存储型属性，以至于无法修改属性的问题。
struct NtkRequestWrapper: Sendable {
    
    private(set) var request: iNtkRequest?
    
    /// 用于在整个组件的调用链中传递值
    var extraData: [String: Sendable] = [:]
    
    init() {
        
    }
    
    subscript(_ key: String) -> Sendable? {
        get {
            extraData[key]
        }
        
        set {
            extraData[key] = newValue
        }
    }
    
    mutating func addRequest(_ req: iNtkRequest) {
        request = req
    }
}
