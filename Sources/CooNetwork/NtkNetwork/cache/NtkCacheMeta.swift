//
//  NtkCacheMeta.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/// 缓存元数据结构
/// 包含缓存数据的完整元信息，用于缓存的版本控制、过期管理和数据存储
public final class NtkCacheMeta: NSObject, NSSecureCoding, Sendable {

    public static var supportsSecureCoding: Bool {
        true
    }

    /// 缓存数据允许出现的全部 Objective-C 类。
    ///
    /// 写入侧 `canEncode(_:)` 与读取侧 `init?(coder:)` 共用这一份定义，避免出现「写得进、读不出」的不对称：
    /// 只要通过 `canEncode` 放行，这里的解档就一定能把它完整读回。
    ///
    /// `NSNull` 不可省略——后端 JSON 的 `null` 会以 `NSNull` 进入响应字典，一旦缺席，
    /// `NSKeyedUnarchiver` 会把它判为非法类：默认策略下整个 `data` 静默变 `nil`，`.raiseException`
    /// 策略下抛出 `NSInvalidUnarchiveOperationException`（OC 异常，Swift 的 `try?`/`do-catch` 无法捕获）。
    static let allowedDataClasses: [AnyClass] = [
        NSString.self, NSDictionary.self, NSArray.self,
        NSNumber.self, NSData.self, NSNull.self
    ]

    /// 缓存数据版本号
    /// 用于标识缓存数据对应的应用版本，便于版本升级时的缓存清理
    public let appVersion: String

    /// 缓存创建时间
    /// 记录缓存数据的创建时间戳（毫秒），用于缓存统计和调试
    public let creationDate: TimeInterval

    /// 缓存过期时间
    /// 缓存数据的过期时间戳（毫秒），超过此时间的缓存将被视为无效
    public let expirationDate: TimeInterval

    /// 实际缓存数据
    /// 存储的网络响应数据，必须遵循Sendable协议以确保线程安全
    /// 支持类型[String:Sendable]、[Sendable]、String、Bool、Int、Double、Float、Data、NSNull
    /// （含上述类型的任意嵌套组合）；`URL`、`Date`、自定义 Sendable 结构体等无法安全往返，
    /// 写入前会被 `canEncode(_:)` 拒绝。
    public let data: Sendable?

    /// 初始化缓存元数据
    /// - Parameters:
    ///   - appVersion: 应用版本号
    ///   - creationDate: 创建时间戳（毫秒）
    ///   - expirationDate: 过期时间戳（毫秒）
    ///   - data: 要缓存的数据
    public init(appVersion: String, creationDate: TimeInterval, expirationDate: TimeInterval, data: Sendable?) {
        self.appVersion = appVersion
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.data = data
    }

    // MARK: - 写入侧校验

    /// 判断一个值能否被归档写入并完整读回。
    ///
    /// 这是 `NSSecureCoding` 往返能力的唯一判定入口：`save` 在真正写入前调用它，不属于白名单的值直接
    /// 跳过缓存，避免出现「写入成功、读取时整个对象解档失败」的脏缓存。判定是递归的——字典和数组的
    /// 任意深度元素都会被检查，因为 `[String: Sendable]` 的元素本身可以是 `URL`、`Date` 这类
    /// 能编码却无法按白名单解码的类型。
    ///
    /// - Parameter value: 待写入缓存的响应数据。
    /// - Returns: 可安全往返时为 `true`，否则为 `false`。
    static func canEncode(_ value: Sendable) -> Bool {
        canEncodeAny(value as Any)
    }

    /// 递归判定任意值是否落在可往返白名单内。
    ///
    /// 类型判断顺序有意如此：`Bool` 先于 `Int`，容器先于标量，避免 `NSNumber` 桥接造成的误判。
    private static func canEncodeAny(_ value: Any) -> Bool {
        if value is NSNull { return true }
        if value is String { return true }
        if value is Bool { return true }
        if value is Int { return true }
        if value is Double { return true }
        if value is Float { return true }
        if value is Data { return true }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.allSatisfy(canEncodeAny)
        }
        if let array = value as? [Any] {
            return array.allSatisfy(canEncodeAny)
        }
        return false
    }

    // MARK: - NSSecureCoding

    required
    public init?(coder: NSCoder) {
        guard let appVersion = coder.decodeObject(of: NSString.self, forKey: "appVersion") as String? else {
            return nil
        }
        self.appVersion = appVersion
        self.creationDate = coder.decodeDouble(forKey: "creationDate")
        self.expirationDate = coder.decodeDouble(forKey: "expirationDate")
        let data = coder.decodeObject(of: Self.allowedDataClasses, forKey: "data")

        // 键存在却解不出任何白名单类型，说明缓存由白名单外的类型构成或已损坏。此时返回 nil 让上层按
        // 「无缓存」处理，而不是构造一个 data 为 nil 的伪命中——后者会让缓存永久失效却无人察觉。
        if data == nil, coder.containsValue(forKey: "data") {
            return nil
        }

        if let data = data as? [String: Sendable] {
            self.data = data
        } else if let data = data as? [Sendable] {
            self.data = data
        } else if let data = data as? String {
            self.data = data
        } else if let data = data as? Bool {
            self.data = data
        } else if let data = data as? Int {
            self.data = data
        } else if let data = data as? Double {
            self.data = data
        } else if let data = data as? Float {
            self.data = data
        } else if let data = data as? Data {
            self.data = data
        } else if let null = data as? NSNull {
            self.data = null
        } else {
            self.data = nil
        }
    }

    public func encode(with coder: NSCoder) {
        coder.encode(appVersion, forKey: "appVersion")
        coder.encode(creationDate, forKey: "creationDate")
        coder.encode(expirationDate, forKey: "expirationDate")
        if let data {
            coder.encode(data, forKey: "data")
        }
    }
}
