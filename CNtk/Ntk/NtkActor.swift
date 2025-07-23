//
//  NtkActor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation


/// 网络组件全局Actor
/// 提供线程安全的并发控制，确保网络相关操作在同一个执行上下文中进行
/// 使用Swift的Actor模型来管理并发访问和数据竞争
@globalActor
actor NtkActor {
    /// 共享的Actor实例
    static var shared = NtkActor()
}
