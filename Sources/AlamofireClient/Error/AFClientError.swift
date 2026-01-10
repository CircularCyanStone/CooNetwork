//
//  AFClientError.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork

extension NtkError {
    
    /// AF 扩展的网络工具错误类型
    public enum AF: Error {
        /// 后端返回的响应体完全为空，异常情况
        case responseEmpty
        
        /// 后端返回的响应体类型不匹配
        case responseTypeError
        
        /// 未知错误
        case unknown(msg: String)
    }
}
