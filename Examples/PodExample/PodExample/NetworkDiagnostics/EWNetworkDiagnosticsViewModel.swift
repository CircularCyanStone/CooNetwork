//
//  EWNetworkDiagnosticsViewModel.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/3/8.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import UIKit
import CoreTelephony

class EWNetworkDiagnosticsViewModel: ObservableObject {
    
    @Published private(set) var basicInfoArr: [(String, String)]
    @Published private(set) var isNetworkConnected: Bool
    @Published private(set) var publicIPV4: String?
    @Published private(set) var publicIPV6: String?
    @Published private(set) var rpcDiagInfoArr: [(String, String)]
    @Published private(set) var domain1DiagInfoArr: [(String, String)]
    @Published private(set) var domain2DiagInfoArr: [(String, String)]
    @Published private(set) var domain3DiagInfoArr: [(String, String)]
    
    init() {
        let appName = EWNetworkDiagnosticsViewModel.getAppName()
        let appVersion = EWNetworkDiagnosticsViewModel.getAppVersion()
        let networkType = EWNetworkInfoUtils.getNetworkType()
        let carrierName = EWNetworkInfoUtils.getCarrierName()
        let time = (ClockSyncUtil().syncDate as? NSDate ?? NSDate()).ew_string(withFormat: "yyyy-MM-dd HH:mm:ss")!
        
        basicInfoArr = [
            ("应用名称", appName ?? "未知"),
            ("设备厂商", "Apple"),
            ("设备型号", EWNetworkDiagnosticsViewModel.getDeviceModel()),
            ("设备ID", MPUtdidInterface.deviceId()),
            ("操作系统", UIDevice.current.systemVersion),
            ("App版本", appVersion ?? "未知"),
            ("网络类型", networkType.rawValue),
            ("运营商", carrierName),
            ("代理设置", EWNetworkInfoUtils.isProxyEnabled() ? "开启" : "关闭"),
            ("时间", time)
        ]
        
        rpcDiagInfoArr = [("诊断域名", "域名0"), ("结果", ""), ("状态码", "")]
        domain1DiagInfoArr = [("诊断域名", "域名1"), ("结果", ""), ("状态码", ""), ("响应耗时", "")]
        domain2DiagInfoArr = [("诊断域名", "域名2"), ("结果", ""), ("状态码", ""), ("响应耗时", "")]
        domain3DiagInfoArr = [("诊断域名", "域名3"), ("结果", ""), ("状态码", ""), ("响应耗时", "")]
        
        isNetworkConnected = networkType == .NotReachable || networkType == .Unknown ? false : true
        guard isNetworkConnected else {return}
        
        
        Task {
            await EWPublicIPFetchAPI.execute(.V4) { ip, error in
                self.publicIPV4 = ip
            }
        }
        
        Task {
            await EWPublicIPFetchAPI.execute(.V6) { ip, error in
                self.publicIPV6 = ip
            }
        }
        
        let req = EWFestivalConfigRequest()
        req?.startRequest(asyncCallback: { response, exception, request in
            DispatchQueue.main.async {
                if exception != nil {
                    self.rpcDiagInfoArr[1] = ("结果", "连接异常")
                    if let dict = exception?.userInfo as? NSDictionary, let statusCode = dict.object(forKey: "retCode") {
                        self.rpcDiagInfoArr[2] = ("状态码", "\(statusCode)")
                    } else {
                        self.rpcDiagInfoArr[2] = ("状态码", "无")
                    }
                } else {
                    self.rpcDiagInfoArr[1] = ("结果", "连接正常")
                    self.rpcDiagInfoArr[2] = ("状态码", "0")
                }
            }
        }, hud: nil)
        
        
#if BOSC_SIT
        let domain1 = "https://mpaas3.bankofshanghai.net:3601/mgw.htm"
#else
        let domain1 = "https://workingenv1.bosc.cn:3601/mgw.htm"
#endif
        let timestampBeforeSendingFirstRequest = Date().timeIntervalSince1970
        Task {
            await EWDomainDiagnosticsAPI.execute(domain1) { code, msg in
                let responseTime = Int((Date().timeIntervalSince1970 - timestampBeforeSendingFirstRequest) * 1000)
                self.domain1DiagInfoArr[1] = ("结果", msg)
                self.domain1DiagInfoArr[2] = ("状态码", code)
                self.domain1DiagInfoArr[3] = ("响应耗时", "\(responseTime)ms")
            }
        }
        
        let timestampBeforeSendingSecondRequest = Date().timeIntervalSince1970
        Task {
            await EWDomainDiagnosticsAPI.execute("https://www.bosc.cn/zh/") { code, msg in
                let responseTime = Int((Date().timeIntervalSince1970 - timestampBeforeSendingSecondRequest) * 1000)
                self.domain2DiagInfoArr[1] = ("结果", msg)
                self.domain2DiagInfoArr[2] = ("状态码", code)
                self.domain2DiagInfoArr[3] = ("响应耗时", "\(responseTime)ms")
            }
        }
        
        let timestampBeforeSendingThirdRequest = Date().timeIntervalSince1970
        Task {
            await EWDomainDiagnosticsAPI.execute("https://www.baidu.com") { code, msg in
                let responseTime = Int((Date().timeIntervalSince1970 - timestampBeforeSendingThirdRequest) * 1000)
                self.domain3DiagInfoArr[1] = ("结果", msg)
                self.domain3DiagInfoArr[2] = ("状态码", code)
                self.domain3DiagInfoArr[3] = ("响应耗时", "\(responseTime)ms")
            }
        }
    }
    
    private static func getAppName() -> String? {
        if let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            return appName
        } else if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            return appName
        } else {
            return nil
        }
    }
    
    private static func getAppVersion() -> String? {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        } else {
            return nil
        }
    }
    
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce("") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return result }
            return result + String(UnicodeScalar(UInt8(value)))
        }
        return deviceModel
    }
    
    func copyAllInfo() -> Bool {
        var allInfo: [String: Any] = [:]
        
        var basicInfo: [String: String] = [:]
        for (title, detail) in basicInfoArr {
            basicInfo[title] = detail
        }
        allInfo["basicInfo"] = basicInfo
        
        if isNetworkConnected {
            var rpcDiagInfo: [String: String] = [:]
            for (title, detail) in rpcDiagInfoArr {
                rpcDiagInfo[title] = detail
            }
            rpcDiagInfo["IPV4"] = publicIPV4 ?? ""
            rpcDiagInfo["IPV6"] = publicIPV6 ?? ""
            allInfo["requestInfo"] = rpcDiagInfo
            
            var domain1DiagInfo: [String: String] = [:]
            for (title, detail) in domain1DiagInfoArr {
                domain1DiagInfo[title] = detail
            }
            var domain2DiagInfo: [String: String] = [:]
            for (title, detail) in domain2DiagInfoArr {
                domain2DiagInfo[title] = detail
            }
            var domain3DiagInfo: [String: String] = [:]
            for (title, detail) in domain3DiagInfoArr {
                domain3DiagInfo[title] = detail
            }
            allInfo["checkInfo"] = [domain1DiagInfo, domain2DiagInfo, domain3DiagInfo]
        } else {
            allInfo["requestInfo"] = [:]
            allInfo["checkInfo"] = []
        }
        
        if JSONSerialization.isValidJSONObject(allInfo), let data = try? JSONSerialization.data(withJSONObject: allInfo), let str = String(data: data, encoding: .utf8) {
            let pasteboard = UIPasteboard.general
            pasteboard.string = str
            return true
        } else {
            return false
        }
    }
}
