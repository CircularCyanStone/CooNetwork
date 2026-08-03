import CryptoKit
import Foundation

struct NtkRequestIdentityBuilder {
    static func build(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> NtkRequestIdentity {
        let headers = try projectHeaders(request: request, policy: policy)
        let parameters = try projectParameters(request: request, policy: policy)

        var encoder = NtkCanonicalIdentityEncoder()
        encoder.appendStringField(tag: 1, value: request.method.rawValue)
        encoder.appendOptionalStringField(tag: 2, value: request.baseURL?.absoluteString)
        encoder.appendStringField(tag: 3, value: request.path)
        encoder.appendStringDictionaryField(tag: 4, value: headers)
        try encoder.appendValueDictionaryField(tag: 5, value: parameters, path: "parameters")
        encoder.appendStringDictionaryField(tag: 6, value: request.identityComponents)

        let digest = SHA256.hash(data: encoder.data)
            .map { String(format: "%02x", $0) }
            .joined()
        return NtkRequestIdentity(digest: "ntk-identity-v2-\(digest)")
    }
}

private extension NtkRequestIdentityBuilder {
    static func projectHeaders(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> [String: String] {
        var included: [String: String] = [:]
        var automatic: [String: String] = [:]

        for (key, value) in request.headers ?? [:] {
            switch request.identityParticipation(forHeader: key) {
            case .excluded:
                continue
            case .included:
                included[key] = value
            case .automatic:
                if !policy.excludedHeaderNames.contains(key.lowercased()) {
                    automatic[key] = value
                }
            }
        }

        let normalized: [String: String]
        do {
            normalized = try policy.normalizeHeaders?(automatic) ?? automatic
        } catch {
            throw Failure.normalizationFailed(
                section: .headers,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = normalized
        let normalizedKeys = Set(normalized.keys.map { $0.lowercased() })
        for (key, value) in included {
            guard !normalizedKeys.contains(key.lowercased()) else {
                throw Failure.projectionCollision(section: .headers, key: key)
            }
            merged[key] = value
        }

        var canonical: [String: String] = [:]
        for (key, value) in merged {
            guard isValidHeaderName(key) else {
                throw Failure.invalidHeaderName(key)
            }
            let canonicalKey = key.lowercased()
            guard canonical[canonicalKey] == nil else {
                throw Failure.duplicateNormalizedHeader(canonicalKey)
            }
            canonical[canonicalKey] = value
        }
        return canonical
    }

    static func projectParameters(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> [String: any Sendable] {
        var included: [String: any Sendable] = [:]
        var automatic: [String: any Sendable] = [:]

        for (key, value) in request.parameters ?? [:] {
            switch request.identityParticipation(forParameter: key) {
            case .excluded:
                continue
            case .included:
                included[key] = value
            case .automatic:
                if !policy.excludedParameterNames.contains(key) {
                    automatic[key] = value
                }
            }
        }

        let normalized: [String: any Sendable]
        do {
            normalized = try policy.normalizeParameters?(automatic) ?? automatic
        } catch {
            throw Failure.normalizationFailed(
                section: .parameters,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = normalized
        for (key, value) in included {
            guard merged[key] == nil else {
                throw Failure.projectionCollision(section: .parameters, key: key)
            }
            merged[key] = value
        }
        return merged
    }

    static func isValidHeaderName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let punctuation = Set("!#$%&'*+-.^_`|~".utf8)
        return name.utf8.allSatisfy {
            $0 <= 127 && (
                (48...57).contains($0) ||
                (65...90).contains($0) ||
                (97...122).contains($0) ||
                punctuation.contains($0)
            )
        }
    }
}
