//
//  EWNetworkReachabilityManager.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/3/18.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import UIKit
import Reachability

@objcMembers
class EWNetworkReachabilityManager: NSObject {
    
    static let shared = EWNetworkReachabilityManager()
    
    private let reachability = Reachability(hostname: "www.apple.com")
    
    private(set) var isRunning = false
    
    func startMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged), name: .reachabilityChanged, object: reachability)
        reachability?.startNotifier()
        if reachability != nil {
            isRunning = true
        }
    }
    
    func stopMonitoring() {
        reachability?.stopNotifier()
        isRunning = false
        NotificationCenter.default.removeObserver(self)
        EWNetworkExceptionBanner.sharedInstance().hide(true)
    }
    
    @objc private func networkChanged(notification: Notification) {
        guard let reachability = notification.object as? Reachability else {
            return
        }
        
        if reachability.isReachable() {
            EWNetworkExceptionBanner.sharedInstance().hide(false)
        } else {
            EWNetworkExceptionBanner.sharedInstance().show(false)
        }
    }
}
