//
//  NtkReturnCode.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

class NtkReturnCode: NSObject, Codable {
    
    private enum `Type`: Int {
        case string
        case int
        case bool
        case double
        case unknown
    }
    private var _type: Type?
    
    private var rawValue: Any?
    
    enum CodingKeys: CodingKey {
        case rawValue
    }
    
    required init(from decoder: any Decoder) throws {
        super.init()
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
        get {
            switch _type {
            case .string:
                return rawValue as? String
            default:
                return nil
            }
        }
        set {
            rawValue = newValue ?? ""
        }
    }
    
    @objc var stringValue: String {
        get {
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
        set {
            rawValue = newValue
        }
    }
    
}

extension NtkReturnCode {
    
    var bool: Bool? {
        get {
            switch _type {
            case .bool:
                return rawValue as? Bool
            default:
                return nil
            }
        }
        set {
            rawValue = newValue
        }
    }
    
    @objc var boolValue: Bool {
        get {
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
        set {
            rawValue = newValue
        }
    }
}

extension NtkReturnCode {
    
    var int: Int? {
        get {
           switch _type {
           case .int:
               return rawValue as? Int
           default:
               return nil
           }
        }
        set {
            rawValue = newValue
        }
    }
    
    @objc var intValue: Int {
        get {
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
        set {
            rawValue = newValue
        }
    }
}

extension NtkReturnCode {
    
    var double: Double? {
        get {
          switch _type {
          case .double:
              return rawValue as? Double
          default:
              return nil
          }
       }
       set {
           rawValue = newValue
       }
    }
    
    @objc var doubleValue: Double {
        get {
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
        set {
            rawValue = newValue
        }
    }
    
}

