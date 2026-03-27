import Foundation

/// payload pipeline 使用的统一中间表示。
///
/// 该类型的目标不是表达完整业务协议，而是为 `normalize -> transform -> decode` 主链
/// 提供一个稳定、可扩展、足够小的中间层，让后续阶段不必直接处理过于松散的原始 `Any`。
///
/// 设计理念：
/// - parser 首先要回答的是“这个原始响应能不能进入解析流水线”，而不是“它最终代表什么业务含义”
/// - 因此 `NtkPayload` 只承载进入 pipeline 所需的最低结构信息，不抢占 decoder / policy 的职责
/// - 对原始 `Data` 保持原样，对顶层 object / array 提供结构化入口，拒绝顶层 scalar
public enum NtkPayload: Sendable {
    /// 原始二进制响应体。
    ///
    /// 适用于仍需要由 decoder 自行完成 JSON 反序列化或协议解释的场景。
    case data(Data)

    /// 已具备顶层结构的动态 payload。
    ///
    /// 适用于上游已经提供 object / array 形式响应，或 transformer 已将数据改造成结构化载荷的场景。
    case dynamic(NtkDynamicData)

    /// 将客户端原始响应收敛为可进入 payload pipeline 的统一入口类型。
    ///
    /// 这是 parser pipeline 的结构边界，而不是业务协议边界：
    /// - 接受原始 `Data`
    /// - 接受顶层 object / array 这种可继续解释的结构化载荷
    /// - 拒绝顶层 scalar（如 `String` / `number` / `bool` / `null`）
    ///
    /// - Parameter raw: 客户端返回的原始响应数据，通常来自 `NtkClientResponse.data`。
    /// - Returns: 可进入 transformer / decoder 阶段的统一 payload。
    /// - Throws: 当原始值既不是 `Data`，也不是允许进入 pipeline 的顶层结构时抛出 `NtkError.Serialization.invalidJSON(rawPayload:)`。
    /// - Note: 该步骤只保证“可进入 pipeline”，不负责递归归一化整棵树，也不负责解释业务字段。
    public static func normalize(from raw: Any) throws -> NtkPayload {
        if let data = raw as? Data {
            return .data(data)
        }

        guard let dynamic = try PayloadRootGate.normalizeRoot(raw) else {
            throw NtkError.Serialization.invalidJSON(rawPayload: nil)
        }

        return .dynamic(dynamic)
    }
}

/// payload pipeline 入口的轻量结构 gate。
///
/// 该类型只负责判断原始响应是否具备进入 parsing pipeline 的顶层结构形态，
/// 不负责递归清洗 payload，也不负责任何业务语义解释。
///
/// 设计目的：
/// - 把“结构可进入性检查”从 decoder 中前移并固定下来
/// - 让 transformer / decoder 面对的是更明确的输入边界
/// - 避免 parser 在主流程里散落对顶层 object / array / scalar 的零碎判断
enum PayloadRootGate {
    /// 对原始响应做顶层结构收敛。
    ///
    /// - Parameter raw: 上游客户端产出的原始响应值。
    /// - Returns: 若 `raw` 是允许进入 pipeline 的顶层 object / array，则返回对应的 `NtkDynamicData`；否则返回 `nil`。
    /// - Throws: 当前实现不会主动抛错，但保留 `throws` 便于未来在结构桥接阶段增加显式失败原因。
    static func normalizeRoot(_ raw: Any) throws -> NtkDynamicData? {
        if isTopLevelScalar(raw) {
            return nil
        }

        if let object = normalizeObjectRoot(raw) {
            return NtkDynamicData(dictionary: object)
        }

        if let array = normalizeArrayRoot(raw) {
            return NtkDynamicData(array: array)
        }

        return nil
    }

    /// 判断原始值是否为不允许直接进入 pipeline 的顶层 scalar。
    ///
    /// - Parameter raw: 待判断的原始值。
    /// - Returns: `true` 表示该值是顶层 leaf value，应被 gate 拒绝；`false` 表示仍可能是可接受的 object / array 结构。
    private static func isTopLevelScalar(_ raw: Any) -> Bool {
        switch raw {
        case is String, is Bool, is Int, is Double, is NSNull, is NSString, is NSNumber:
            return true
        default:
            return false
        }
    }

    /// 将原始值桥接为顶层对象 payload。
    ///
    /// - Parameter raw: 待桥接的原始值。
    /// - Returns: 若原始值可视为 `[String: any Sendable]`，则返回对应字典；否则返回 `nil`。
    private static func normalizeObjectRoot(_ raw: Any) -> [String: any Sendable]? {
        raw as? [String: any Sendable]
    }

    /// 将原始值桥接为顶层数组 payload。
    ///
    /// - Parameter raw: 待桥接的原始值。
    /// - Returns: 若原始值可视为 `[any Sendable]`，则返回对应数组；否则返回 `nil`。
    private static func normalizeArrayRoot(_ raw: Any) -> [any Sendable]? {
        raw as? [any Sendable]
    }
}
