import Foundation

/// TFNDynamicData - 支持多种数据类型的动态数据结构
/// 用于处理网络响应中的动态数据，支持 Dictionary<String, any Sendable>、Int、Bool、String 等多种类型
/// 提供类型安全的访问接口和便利的下标语法支持
struct TFNDynamicData: Sendable, Codable {
    
    /// 内部存储的原始值
    private let rawValue: any Sendable
    
    /// 值类型枚举
    private enum ValueType: String, Codable {
        case dictionary = "dictionary"
        case array = "array"
        case string = "string"
        case int = "int"
        case double = "double"
        case bool = "bool"
        case null = "null"
    }
    
    /// 当前值的类型
    private let valueType: ValueType
    
    // MARK: - 初始化方法
    
    /// 从字典初始化
    init(_ dictionary: [String: any Sendable]) {
        self.rawValue = dictionary
        self.valueType = .dictionary
    }
    
    /// 从数组初始化
    init(_ array: [any Sendable]) {
        self.rawValue = array
        self.valueType = .array
    }
    
    /// 从字符串初始化
    init(_ string: String) {
        self.rawValue = string
        self.valueType = .string
    }
    
    /// 从整数初始化
    init(_ int: Int) {
        self.rawValue = int
        self.valueType = .int
    }
    
    /// 从双精度浮点数初始化
    init(_ double: Double) {
        self.rawValue = double
        self.valueType = .double
    }
    
    /// 从布尔值初始化
    init(_ bool: Bool) {
        self.rawValue = bool
        self.valueType = .bool
    }
    
    /// 空值初始化
    init() {
        self.rawValue = NSNull()
        self.valueType = .null
    }
    
    // MARK: - Codable实现
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 尝试按优先级解码不同类型
        if container.decodeNil() {
            self.rawValue = NSNull()
            self.valueType = .null
            return
        }
        
        // 尝试解码为字典
        if let dict = try? container.decode([String: TFNDynamicData].self) {
            var convertedDict: [String: any Sendable] = [:]
            for (key, value) in dict {
                convertedDict[key] = value.rawValue
            }
            self.rawValue = convertedDict
            self.valueType = .dictionary
            return
        }
        
        // 尝试解码为数组
        if let array = try? container.decode([TFNDynamicData].self) {
            let convertedArray = array.map { $0.rawValue }
            self.rawValue = convertedArray
            self.valueType = .array
            return
        }
        
        // 尝试解码为字符串
        if let string = try? container.decode(String.self) {
            self.rawValue = string
            self.valueType = .string
            return
        }
        
        // 尝试解码为整数
        if let int = try? container.decode(Int.self) {
            self.rawValue = int
            self.valueType = .int
            return
        }
        
        // 尝试解码为双精度浮点数
        if let double = try? container.decode(Double.self) {
            self.rawValue = double
            self.valueType = .double
            return
        }
        
        // 尝试解码为布尔值
        if let bool = try? container.decode(Bool.self) {
            self.rawValue = bool
            self.valueType = .bool
            return
        }
        
        // 如果所有类型都无法解码，抛出错误
        throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
            TFNDynamicData.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "无法解码为任何支持的类型")
        ))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch valueType {
        case .dictionary:
            guard let dict = rawValue as? [String: any Sendable] else {
                throw TFNError.decodingFailure(underlying: EncodingError.invalidValue(
                    rawValue,
                    EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "字典类型编码失败")
                ))
            }
            var dynamicDict: [String: TFNDynamicData] = [:]
            for (key, value) in dict {
                dynamicDict[key] = TFNDynamicData.from(value)
            }
            try container.encode(dynamicDict)
            
        case .array:
            guard let array = rawValue as? [any Sendable] else {
                throw TFNError.decodingFailure(underlying: EncodingError.invalidValue(
                    rawValue,
                    EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "数组类型编码失败")
                ))
            }
            let dynamicArray = array.map { TFNDynamicData.from($0) }
            try container.encode(dynamicArray)
            
        case .string:
            try container.encode(rawValue as! String)
        case .int:
            try container.encode(rawValue as! Int)
        case .double:
            try container.encode(rawValue as! Double)
        case .bool:
            try container.encode(rawValue as! Bool)
        case .null:
            try container.encodeNil()
        }
    }
    
    // MARK: - 辅助方法
    
    /// 从任意Sendable值创建TFNDynamicData
    public static func from(_ value: any Sendable) -> TFNDynamicData {
        switch value {
        case let dict as [String: any Sendable]:
            return TFNDynamicData(dict)
        case let array as [any Sendable]:
            return TFNDynamicData(array)
        case let string as String:
            return TFNDynamicData(string)
        case let int as Int:
            return TFNDynamicData(int)
        case let double as Double:
            return TFNDynamicData(double)
        case let bool as Bool:
            return TFNDynamicData(bool)
        case is NSNull:
            return TFNDynamicData()
        default:
            // 对于其他类型，尝试转换为字符串
            return TFNDynamicData(String(describing: value))
        }
    }
}

// MARK: - 类型安全的访问接口

extension TFNDynamicData {
    
    /// 获取字典值
    /// - Returns: 字典值或nil
    func getDictionary() -> [String: any Sendable]? {
        guard valueType == .dictionary else { return nil }
        return rawValue as? [String: any Sendable]
    }
    
    /// 获取数组值
    /// - Returns: 数组值或nil
    func getArray() -> [any Sendable]? {
        guard valueType == .array else { return nil }
        return rawValue as? [any Sendable]
    }
    
    /// 获取字符串值
    /// - Returns: 字符串值或nil
    func getString() -> String? {
        guard valueType == .string else { return nil }
        return rawValue as? String
    }
    
    /// 获取整数值
    /// - Returns: 整数值或nil
    func getInt() -> Int? {
        guard valueType == .int else { return nil }
        return rawValue as? Int
    }
    
    /// 获取双精度浮点数值
    /// - Returns: 双精度浮点数值或nil
    func getDouble() -> Double? {
        guard valueType == .double else { return nil }
        return rawValue as? Double
    }
    
    /// 获取布尔值
    /// - Returns: 布尔值或nil
    func getBool() -> Bool? {
        guard valueType == .bool else { return nil }
        return rawValue as? Bool
    }
    
    /// 检查是否为空值
    /// - Returns: 是否为空值
    func isNull() -> Bool {
        return valueType == .null
    }
    
    /// 通用获取值方法，支持类型转换
    /// - Parameter type: 目标类型
    /// - Returns: 转换后的值或抛出错误
    func getValue<T>(as type: T.Type) throws -> T {
        switch type {
        case is String.Type:
            if let value = getString() {
                return value as! T
            }
            // 尝试类型转换
            switch valueType {
            case .int:
                return String(rawValue as! Int) as! T
            case .double:
                return String(rawValue as! Double) as! T
            case .bool:
                return String(rawValue as! Bool) as! T
            case .null:
                return "" as! T
            default:
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                     T.self,
                     DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
                 ))
            }
            
        case is Int.Type:
            if let value = getInt() {
                return value as! T
            }
            // 尝试类型转换
            switch valueType {
            case .string:
                if let intValue = Int(rawValue as! String) {
                    return intValue as! T
                }
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                     T.self,
                     DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
                 ))
            case .double:
                return Int(rawValue as! Double) as! T
            case .bool:
                return (rawValue as! Bool ? 1 : 0) as! T
            default:
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                     T.self,
                     DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
                 ))
            }
            
        case is Double.Type:
            if let value = getDouble() {
                return value as! T
            }
            // 尝试类型转换
            switch valueType {
            case .string:
                if let doubleValue = Double(rawValue as! String) {
                    return doubleValue as! T
                }
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                     T.self,
                     DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
                 ))
            case .int:
                return Double(rawValue as! Int) as! T
            case .bool:
                return (rawValue as! Bool ? 1.0 : 0.0) as! T
            default:
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                     T.self,
                     DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
                 ))
            }
            
        case is Bool.Type:
            if let value = getBool() {
                return value as! T
            }
            // 尝试类型转换
            switch valueType {
            case .string:
                let stringValue = (rawValue as! String).lowercased()
                return (stringValue == "true" || stringValue == "1") as! T
            case .int:
                return (rawValue as! Int != 0) as! T
            case .double:
                return (rawValue as! Double != 0.0) as! T
            default:
                throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                 T.self,
                 DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
             ))
            }
            
        case is [String: any Sendable].Type:
            if let value = getDictionary() {
                return value as! T
            }
            throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                 T.self,
                 DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
             ))
            
        case is [any Sendable].Type:
            if let value = getArray() {
                return value as! T
            }
            throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                 T.self,
                 DecodingError.Context(codingPath: [], debugDescription: "无法将\(valueType)类型转换为\(T.self)")
             ))
            
        default:
             throw TFNError.decodingFailure(underlying: DecodingError.typeMismatch(
                 T.self,
                 DecodingError.Context(codingPath: [], debugDescription: "不支持的类型转换: \(T.self)")
             ))
        }
    }
}

// MARK: - 下标语法支持

extension TFNDynamicData {
    
    /// 字典类型的字符串下标访问
    /// - Parameter key: 字典键
    /// - Returns: 对应的TFNDynamicData值或nil
    subscript(key: String) -> TFNDynamicData? {
        guard let dict = getDictionary() else { return nil }
        guard let value = dict[key] else { return nil }
        return TFNDynamicData.from(value)
    }
    
    /// 数组类型的整数下标访问
    /// - Parameter index: 数组索引
    /// - Returns: 对应的TFNDynamicData值或nil
    subscript(index: Int) -> TFNDynamicData? {
        guard let array = getArray() else { return nil }
        guard index >= 0 && index < array.count else { return nil }
        return TFNDynamicData.from(array[index])
    }
    
    /// 支持链式访问的下标方法
    /// 例如: data["user"]["name"] 或 data["items"][0]
    /// - Parameter keyPath: 键路径（字符串或整数）
    /// - Returns: 对应的TFNDynamicData值或nil
    subscript(dynamicMember keyPath: String) -> TFNDynamicData? {
        return self[keyPath]
    }
}

// MARK: - 便利扩展

extension TFNDynamicData {
    
    /// 获取嵌套字典中的值
    /// - Parameter keyPath: 点分隔的键路径，如 "user.profile.name"
    /// - Returns: 对应的TFNDynamicData值或nil
    func getValue(forKeyPath keyPath: String) -> TFNDynamicData? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: TFNDynamicData? = self
        
        for key in keys {
            current = current?[key]
            if current == nil {
                return nil
            }
        }
        
        return current
    }
    
    /// 获取嵌套数组中的值
    /// - Parameter indexPath: 索引路径数组，如 [0, 1, 2]
    /// - Returns: 对应的TFNDynamicData值或nil
    func getValue(forIndexPath indexPath: [Int]) -> TFNDynamicData? {
        var current: TFNDynamicData? = self
        
        for index in indexPath {
            current = current?[index]
            if current == nil {
                return nil
            }
        }
        
        return current
    }
    
    /// 安全获取值的便利方法
    /// - Parameters:
    ///   - key: 键名
    ///   - defaultValue: 默认值
    /// - Returns: 获取到的值或默认值
    func getValue<T>(for key: String, defaultValue: T) -> T {
        guard let value = self[key] else { return defaultValue }
        return (try? value.getValue(as: T.self)) ?? defaultValue
    }
    
    /// 安全获取数组元素的便利方法
    /// - Parameters:
    ///   - index: 索引
    ///   - defaultValue: 默认值
    /// - Returns: 获取到的值或默认值
    func getValue<T>(at index: Int, defaultValue: T) -> T {
        guard let value = self[index] else { return defaultValue }
        return (try? value.getValue(as: T.self)) ?? defaultValue
    }
}