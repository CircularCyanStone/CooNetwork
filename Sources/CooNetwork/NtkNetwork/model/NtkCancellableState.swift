//
//  NtkCancellableState.swift
//  CooNetwork
//
//  Created by Claude on 2026/3/16.
//

import Foundation

/// 可取消状态（引用类型，用于跨组件共享取消状态）
///
/// 设计目的：
/// - 解决 NtkMutableRequest 是值类型的问题，无法直接存储共享的可变状态
/// - 提供 Actor 保护，确保多线程下读取和写入取消状态的线程安全
///
/// 使用场景：
/// - NtkNetwork.cancel() 设置取消状态=true
/// - NtkTaskManager.executeWithDeduplication() 读取取消状态，提前中断
@NtkActor
public final class NtkCancellableState {

    /// 是否已取消
    private var _isCancelled: Bool = false

    /// 读取取消状态
    public var isCancelled: Bool {
        _isCancelled
    }

    /// 设置取消状态为 true
    public func cancel() {
        _isCancelled = true
    }
}
