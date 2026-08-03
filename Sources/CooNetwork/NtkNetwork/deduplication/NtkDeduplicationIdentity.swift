import Foundation

struct NtkDeduplicationIdentity: Hashable, Sendable {
    let requestIdentity: NtkRequestIdentity
    let responseType: ObjectIdentifier
    let effectiveTimeout: TimeInterval
    let namespace: String
}
