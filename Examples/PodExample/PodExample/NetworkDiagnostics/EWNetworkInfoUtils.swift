//
//  EWNetworkInfoUtils.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/3/12.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import Foundation
import Reachability

enum EWNetworkType: String {
    case NotReachable = "无网络"
    case WiFi = "WiFi"
    case WWAN2G = "2G"
    case WWAN3G = "3G"
    case WWAN4G = "4G"
    case WWAN5G = "5G"
    case Unknown = "未知"
}

struct EWNetworkInfoUtils {
    
    static let networkInfo = CTTelephonyNetworkInfo()
    
    static func getNetworkType() -> EWNetworkType {
        guard let reachability = Reachability.forInternetConnection() else { return .Unknown }
        if !reachability.isReachable() {
            return .NotReachable
        } else if reachability.isReachableViaWiFi() {
            return .WiFi
        } else if !reachability.isReachableViaWWAN() {
            return .Unknown
        }
        
        if let currentRadioAccessTechnology = networkInfo.serviceCurrentRadioAccessTechnology {
            // 返回第一个有效的网络类型
            for (_, value) in currentRadioAccessTechnology {
                switch value {
                case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
                    return .WWAN2G
                case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                    return .WWAN3G
                case CTRadioAccessTechnologyLTE:
                    return .WWAN4G
                default:
                    if #available(iOS 14.1, *), value == CTRadioAccessTechnologyNRNSA || value == CTRadioAccessTechnologyNR {
                        return .WWAN5G
                    }
                    break
                }
            }
        }
        
        return .Unknown
    }
    
    static func getCarrierName() -> String {
        if let carriers = networkInfo.serviceSubscriberCellularProviders {
            // 返回第一个有效的运营商名称
            for (_, carrier) in carriers {
                if let carrierName = carrier.carrierName {
                    if carrierName == "--" {
                        return "其他"
                    } else {
                        return carrierName
                    }
                }
            }
        }
        return "未知"
    }
    
    static func isProxyEnabled() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as? [String: Any] else {
            return false
        }
        
        if let httpProxy = proxySettings["HTTPProxy"] as? String, !httpProxy.isEmpty {
            return true
        }
        
        if let httpsProxy = proxySettings["HTTPSProxy"] as? String, !httpsProxy.isEmpty {
            return true
        }
        
        return false
    }
}
