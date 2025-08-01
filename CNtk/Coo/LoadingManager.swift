//
//  LoadingManager.swift
//  CNtk
//
//  Created by Trae Builder on 2025/1/27.
//
//  基于SVProgressHUD的计数式Loading管理器
//  支持Swift6严格并发模式，使用Actor确保线程安全
//

import Foundation
import SVProgressHUD
import UIKit

/// Loading管理器
/// 基于SVProgressHUD内置计数功能的Loading管理器
/// 支持Swift6严格并发模式，直接使用SVProgressHUD的activityCount机制
@MainActor
public final class LoadingManager: Sendable {
    
    /// 私有初始化，防止实例化
    private init() {}
    
    /// 配置默认样式
    private static func configureDefaultStyle() {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setMinimumDismissTimeInterval(1.0)
        SVProgressHUD.setMaximumDismissTimeInterval(3.0)
    }
    
    /// 静态初始化标志
    private static var isConfigured = false
    
    /// 确保配置已初始化
    private static func ensureConfigured() {
        if !isConfigured {
            configureDefaultStyle()
            isConfigured = true
        }
    }
    
    /// 显示Loading
    /// 使用SVProgressHUD内置计数机制
    /// - Parameter status: 可选的状态文本
    public static func showLoading(with status: String? = nil) {
        ensureConfigured()
        if let status = status {
            SVProgressHUD.show(withStatus: status)
        } else {
            SVProgressHUD.show()
        }
    }
    
    /// 隐藏Loading
    /// 使用SVProgressHUD内置计数机制
    public static func hideLoading() {
        SVProgressHUD.popActivity()
    }
    
    /// 强制隐藏Loading
    /// 立即隐藏Loading
    public static func forceHide() {
        SVProgressHUD.dismiss()
    }
    
    /// 显示成功消息
    /// - Parameters:
    ///   - message: 成功消息
    ///   - duration: 显示时长，默认2秒
    public static func showSuccess(_ message: String, duration: TimeInterval = 2.0) {
        SVProgressHUD.showSuccess(withStatus: message)
        SVProgressHUD.dismiss(withDelay: duration)
    }
    
    /// 显示错误消息
    /// - Parameters:
    ///   - message: 错误消息
    ///   - duration: 显示时长，默认3秒
    public static func showError(_ message: String, duration: TimeInterval = 3.0) {
        SVProgressHUD.showError(withStatus: message)
        SVProgressHUD.dismiss(withDelay: duration)
    }
    
    /// 显示信息消息
    /// - Parameters:
    ///   - message: 信息消息
    ///   - duration: 显示时长，默认2秒
    public static func showInfo(_ message: String, duration: TimeInterval = 2.0) {
        SVProgressHUD.showInfo(withStatus: message)
        SVProgressHUD.dismiss(withDelay: duration)
    }
    
    /// 检查是否正在显示Loading
    /// - Returns: 是否正在显示Loading
    public static var isLoadingVisible: Bool {
        return SVProgressHUD.isVisible()
    }
    
    /// 重置Loading状态
    /// 强制隐藏所有Loading
    public static func reset() {
        SVProgressHUD.dismiss()
    }
}

// MARK: - 异步方法扩展
extension LoadingManager {
    
    /// 异步显示Loading
    /// - Parameter status: 可选的状态文本
    public static func showLoadingAsync(with status: String? = nil) async {
        await MainActor.run {
            showLoading(with: status)
        }
    }
    
    /// 异步隐藏Loading
    public static func hideLoadingAsync() async {
        await MainActor.run {
            hideLoading()
        }
    }
    
    /// 异步强制隐藏Loading
    public static func forceHideAsync() async {
        await MainActor.run {
            forceHide()
        }
    }
    
    /// 异步显示成功消息
    /// - Parameters:
    ///   - message: 成功消息
    ///   - duration: 显示时长
    public static func showSuccessAsync(_ message: String, duration: TimeInterval = 2.0) async {
        await MainActor.run {
            showSuccess(message, duration: duration)
        }
    }
    
    /// 异步显示错误消息
    /// - Parameters:
    ///   - message: 错误消息
    ///   - duration: 显示时长
    public static func showErrorAsync(_ message: String, duration: TimeInterval = 3.0) async {
        await MainActor.run {
            showError(message, duration: duration)
        }
    }
    
    /// 异步显示信息消息
    /// - Parameters:
    ///   - message: 信息消息
    ///   - duration: 显示时长
    public static func showInfoAsync(_ message: String, duration: TimeInterval = 2.0) async {
        await MainActor.run {
            showInfo(message, duration: duration)
        }
    }
}

// MARK: - 调试和监控扩展
extension LoadingManager {
    
    /// 调试信息
    public static var debugInfo: String {
        return "LoadingManager - Visible: \(SVProgressHUD.isVisible())"
    }
    
    /// 打印调试信息
    public static func printDebugInfo() {
        print(debugInfo)
    }
}
