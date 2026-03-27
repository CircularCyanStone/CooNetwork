//
//  NtkTransferProgress.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/25.
//

import Foundation

/// 传输进度快照
/// 记录某一时刻的字节传输进度，可用于上传或下载场景
/// 该结构为值类型，满足 `Sendable`，可安全跨并发域传递
public struct NtkTransferProgress: Sendable {

    /// 已完成的字节数
    public let completedUnitCount: Int64

    /// 总字节数；-1 表示未知
    public let totalUnitCount: Int64

    /// 完成比例，范围 0.0 – 1.0；总字节数未知时为 0.0
    public let fractionCompleted: Double

    /// 逐成员初始化
    /// - Parameters:
    ///   - completedUnitCount: 已完成的字节数
    ///   - totalUnitCount: 总字节数（-1 表示未知）
    ///   - fractionCompleted: 完成比例
    public init(completedUnitCount: Int64, totalUnitCount: Int64, fractionCompleted: Double) {
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.fractionCompleted = fractionCompleted
    }

    /// 从 Foundation `Progress` 对象创建快照
    /// - Parameter progress: Foundation 进度对象
    public init(from progress: Progress) {
        self.completedUnitCount = progress.completedUnitCount
        self.totalUnitCount = progress.totalUnitCount
        self.fractionCompleted = progress.fractionCompleted
    }
}
