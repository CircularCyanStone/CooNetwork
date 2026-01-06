//
//  NtkNever.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 空数据模型
/// 用于表示服务端返回 {data: null} 或 {data: {}} 的数据情况
/// 当接口不需要返回具体数据内容时使用此模型作为泛型参数
public struct NtkNever: Decodable, Sendable {
    public init() {
        
    }
}
