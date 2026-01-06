//
//  NtkConfiguration.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2026/1/6.
//
/**
 配置项
 */
import Foundation

public struct NtkConfiguration: Sendable {
    
    static let shared = NtkConfiguration()
    
    /// 日志开关
    var isLoggingEnabled: Bool = false
    
}
