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
/// - 提供线程安全的取消状态读写
///
/// 使用场景：
/// - NtkNetwork.cancel() 设置取消状态=true
/// - NtkTaskManager.executeWithDeduplication() 读取取消状态，提前中断
public final class NtkCancellableState: @unchecked Sendable {

    /// 是否已取消
    private var _isCancelled: Bool = false

    /// 内部锁保护状态读写
    private let lock = NtkUnfairLock()

    /// 读取取消状态
    public var isCancelled: Bool {
        lock.withLock { _isCancelled }
    }

    /// 设置取消状态为 true
    public func cancel() {
        lock.withLock { _isCancelled = true }
    }
}
