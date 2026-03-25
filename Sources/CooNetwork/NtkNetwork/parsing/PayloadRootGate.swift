import Foundation

/// payload pipeline 入口的轻量结构 gate。
///
/// 这里只负责：
/// - 接受顶层 object / array
/// - 拒绝顶层 scalar
/// - 对 Foundation 容器做顶层浅桥接
///
/// 不对整棵 payload 做递归归一化；更深层的结构解释由 transformer / decoder 按需处理。
enum PayloadRootGate {
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

    private static func isTopLevelScalar(_ raw: Any) -> Bool {
        switch raw {
        case is String, is Bool, is Int, is Double, is NSNull, is NSString, is NSNumber:
            return true
        default:
            return false
        }
    }

    private static func normalizeObjectRoot(_ raw: Any) -> [String: any Sendable]? {
        raw as? [String: any Sendable]
    }

    private static func normalizeArrayRoot(_ raw: Any) -> [any Sendable]? {
        raw as? [any Sendable]
    }
}
