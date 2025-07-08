//
//  NtkReturnCode.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

final class NtkReturnCode: Codable, Sendable {
    
    private enum `Type`: Int, Sendable {
        case string
        case int
        case bool
        case double
        case unknown
    }
    private let _type: Type?
    
    private let rawValue: Sendable?
    
    enum CodingKeys: CodingKey {
        case rawValue
    }
    
    init(_ value: Any?) {
        rawValue = value
        if value is String {
            _type = .string
            return
        }
        if value is Int {
            _type = .int
            return
        }
        
        if value is Bool {
            _type = .bool
            return
        }
        if value is Double {
            _type = .double
            return
        }
        _type = .unknown
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            rawValue = value
            _type = .string
            return
        }
        
        if let value = try? container.decode(Int.self) {
            rawValue = value
            _type = .int
            return
        }
        
        if let value = try? container.decode(Bool.self) {
            rawValue = value
            _type = .bool
            return
        }
        
        if let value = try? container.decode(Double.self) {
            rawValue = value
            _type = .double
            return
        }
        if container.decodeNil() {
            rawValue = ""
            _type = .string
            return
        }
        _type = .unknown
        rawValue = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var singleValueContainer =  encoder.singleValueContainer()
        switch _type {
        case .string:
            try? singleValueContainer.encode(rawValue as! String)
        case .int:
            try? singleValueContainer.encode(rawValue as! Int)
        case .bool:
            try? singleValueContainer.encode(rawValue as! Bool)
        case .double:
            try? singleValueContainer.encode(rawValue as! Double)
        case .unknown:
            try? singleValueContainer.encodeNil()
        case .none:
            try? singleValueContainer.encodeNil()
        }
    }
    
}

extension NtkReturnCode {
    
    @objc var string: String? {
        switch _type {
        case .string:
            return rawValue as? String
        default:
            return nil
        }
    }
    
    @objc var stringValue: String {
        switch _type {
        case .string:
            return rawValue as! String
        case .bool:
            return "\(rawValue!)"
        case .double:
            return "\(rawValue!)"
        case .int:
            return "\(rawValue!)"
        default:
            return ""
        }
    }
    
}

extension NtkReturnCode {
    
    var bool: Bool? {
        switch _type {
        case .bool:
            return rawValue as? Bool
        default:
            return nil
        }
    }
    
    @objc var boolValue: Bool {
        switch _type {
        case .string:
            return (rawValue as! NSString).boolValue
        case .bool:
            return rawValue as! Bool
        case .double:
            return (rawValue as! Double) != 0
        case .int:
            return (rawValue as! Int) != 0
        default:
            return false
        }
    }
}

extension NtkReturnCode {
    
    var int: Int? {
        switch _type {
        case .int:
            return rawValue as? Int
        default:
            return nil
        }
    }
    
    @objc var intValue: Int {
        switch _type {
        case .string:
            return (rawValue as! NSString).integerValue
        case .bool:
            return (rawValue as! Bool) ? 1 : 0
        case .double:
            return Int(rawValue as! Double)
        case .int:
            return rawValue as! Int
        default:
            return 0
        }
    }
}

extension NtkReturnCode {
    
    var double: Double? {
        switch _type {
        case .double:
            return rawValue as? Double
        default:
            return nil
        }
    }
    
    @objc var doubleValue: Double {
        switch _type {
        case .string:
            return (rawValue as! NSString).doubleValue
        case .bool:
            return (rawValue as! Bool) ? 1.0 : 0.0
        case .double:
            return rawValue as! Double
        case .int:
            return Double(rawValue as! Int)
        default:
            return 0.0
        }
    }
    
}

