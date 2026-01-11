//
//  NtkUnfairLock.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/11.
//

import Foundation
import os.lock

/// 基于 os_unfair_lock 的高性能锁封装
/// 相比 NSLock 具有更低的开销，适合高频调用的临界区保护
/// 注意：os_unfair_lock 是非递归锁，同一个线程重复获取会导致死锁
public final class NtkUnfairLock: @unchecked Sendable {
    
    private let unfairLock: os_unfair_lock_t
    
    public init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }
    
    /// 加锁
    public func lock() {
        os_unfair_lock_lock(unfairLock)
    }
    
    /// 解锁
    public func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
    
    /// 尝试加锁
    /// - Returns: 是否加锁成功
    public func tryLock() -> Bool {
        return os_unfair_lock_trylock(unfairLock)
    }
    
    /// 在锁保护下执行闭包
    /// - Parameter body: 需要保护的代码块
    /// - Returns: 代码块的返回值
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
