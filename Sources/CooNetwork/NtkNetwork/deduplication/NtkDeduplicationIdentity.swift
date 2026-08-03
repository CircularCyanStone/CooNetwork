import Foundation

// 四个维度必须共同参与去重隔离，不得退回易碰撞的字符串拼接键。
struct NtkDeduplicationIdentity: Hashable, Sendable {
    let requestIdentity: NtkRequestIdentity
    let responseType: ObjectIdentifier
    let effectiveTimeout: TimeInterval
    let namespace: String
}
