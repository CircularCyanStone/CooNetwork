import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestIdentityBuilderTests {
    @Test
    func excludedDynamicFieldsProduceOneIdentity() throws {
        var first = makeRequest(token: "token-a", timestamp: 1)
        first.addHeader(key: "Authorization", value: "token-a", identity: .excluded)
        first.addParameter(key: "token", value: "token-a", identity: .excluded)
        first.addParameter(key: "timestamp", value: 1, identity: .excluded)
        first.addIdentityComponent(key: "user", value: "42")

        var second = makeRequest(token: "token-b", timestamp: 2)
        second.addHeader(key: "authorization", value: "token-b", identity: .excluded)
        second.addParameter(key: "token", value: "token-b", identity: .excluded)
        second.addParameter(key: "timestamp", value: 2, identity: .excluded)
        second.addIdentityComponent(key: "user", value: "42")

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    @Test
    func includedOverridesGlobalExclusionAndUserComponentSeparatesUsers() throws {
        let policy = NtkRequestIdentityPolicy(excludedParameterNames: ["tenant"])
        var first = makeRequest()
        first.addParameter(key: "tenant", value: "a", identity: .included)
        first.addIdentityComponent(key: "user", value: "1")
        var second = makeRequest()
        second.addParameter(key: "tenant", value: "b", identity: .included)
        second.addIdentityComponent(key: "user", value: "2")

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func headerCaseAndDictionaryInsertionOrderDoNotChangeIdentity() throws {
        var first = makeRequest()
        first.addHeader(key: "X-CLIENT", value: "ios")
        first.setParameter(["outer": ["b": 2, "a": 1] as [String: Sendable]])
        var second = makeRequest()
        second.addHeader(key: "x-client", value: "ios")
        second.setParameter(["outer": ["a": 1, "b": 2] as [String: Sendable]])

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    @Test
    func normalizerCannotSeeExplicitFieldsAndCollisionFails() throws {
        let policy = NtkRequestIdentityPolicy(normalizeParameters: { parameters in
            #expect(parameters["secret"] == nil)
            return ["stable": "from-normalizer"]
        })
        var request = makeRequest()
        request.addParameter(key: "secret", value: "value", identity: .excluded)
        request.addParameter(key: "stable", value: "included", identity: .included)

        #expect(throws: NtkRequestIdentityBuilder.Failure.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: policy)
        }
    }

    @Test
    func unsupportedValueReturnsInternalFailure() {
        var request = makeRequest()
        request.addParameter(key: "custom", value: UnsupportedIdentityParameter())
        #expect(throws: NtkRequestIdentityBuilder.Failure.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        }
    }

    @Test
    func excludedParameterNamesAreCaseSensitiveExactMatches() throws {
        let policy = NtkRequestIdentityPolicy(excludedParameterNames: ["token"])
        var first = NtkMutableRequest(IdentityBuilderRequest())
        first.setParameter(["token": "a", "Token": "A", "tokenValue": "one"])
        var second = NtkMutableRequest(IdentityBuilderRequest())
        second.setParameter(["token": "b", "Token": "A", "tokenValue": "one"])
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) ==
                NtkRequestIdentityBuilder.build(request: second, policy: policy))

        second.addParameter(key: "tokenValue", value: "two")
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func nilAndEmptyCollectionsHaveOneIdentity() throws {
        let nilCollections = NtkMutableRequest(IdentityBuilderRequest())
        var emptyCollections = NtkMutableRequest(IdentityBuilderRequest())
        emptyCollections.headers = [:]
        emptyCollections.parameters = [:]
        #expect(try NtkRequestIdentityBuilder.build(request: nilCollections, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: emptyCollections, policy: .strict))
    }

    @Test
    func arrayOrderAndScalarTypesChangeIdentity() throws {
        var first = NtkMutableRequest(IdentityBuilderRequest())
        first.setParameter(["value": [1, 2] as [any Sendable]])
        var reordered = NtkMutableRequest(IdentityBuilderRequest())
        reordered.setParameter(["value": [2, 1] as [any Sendable]])
        var stringValue = NtkMutableRequest(IdentityBuilderRequest())
        stringValue.setParameter(["value": "1"])
        var booleanValue = NtkMutableRequest(IdentityBuilderRequest())
        booleanValue.setParameter(["value": true])

        let integerIdentity = try NtkRequestIdentityBuilder.build(request: first, policy: .strict)
        #expect(integerIdentity != (try NtkRequestIdentityBuilder.build(request: reordered, policy: .strict)))
        #expect(integerIdentity != (try NtkRequestIdentityBuilder.build(request: stringValue, policy: .strict)))
        #expect(integerIdentity != (try NtkRequestIdentityBuilder.build(request: booleanValue, policy: .strict)))
    }

    @Test
    func supportedFoundationAndDynamicValuesRepeatExactly() throws {
        var request = NtkMutableRequest(IdentityBuilderRequest())
        request.setParameter([
            "data": Data([1, 2, 3]),
            "url": URL(string: "https://example.com/resource")!,
            "uuid": UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!,
            "date": Date(timeIntervalSinceReferenceDate: 123),
            "null": NSNull(),
            "dynamic": NtkDynamicData(array: [1, "two", NSNull()])
        ])
        let first = try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        let second = try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        #expect(first == second)
    }

    @Test
    func normalizationFailureStoresOnlyErrorType() {
        let policy = NtkRequestIdentityPolicy(normalizeParameters: { _ in
            throw IdentityNormalizerError.containsSensitiveDescription
        })
        let request = NtkMutableRequest(IdentityBuilderRequest())
        do {
            _ = try NtkRequestIdentityBuilder.build(request: request, policy: policy)
            Issue.record("期望规范化失败")
        } catch let failure as NtkRequestIdentityBuilder.Failure {
            guard case .normalizationFailed(.parameters, let errorType) = failure else {
                Issue.record("错误类型不符: \(failure)")
                return
            }
            #expect(errorType.contains("IdentityNormalizerError"))
            #expect(!errorType.contains("secret-value"))
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }

    @Test
    func duplicateCaseInsensitiveHeadersFailIdentityOnly() {
        var request = NtkMutableRequest(IdentityBuilderRequest())
        request.headers = ["Authorization": "a", "authorization": "b"]
        #expect(throws: NtkRequestIdentityBuilder.Failure.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        }
    }

    @Test
    func headerExclusionIsCaseInsensitiveAndExact() throws {
        let policy = NtkRequestIdentityPolicy(excludedHeaderNames: ["Authorization"])
        var first = NtkMutableRequest(IdentityBuilderRequest())
        first.headers = ["authorization": "a", "Authorization-Mode": "stable"]
        var second = NtkMutableRequest(IdentityBuilderRequest())
        second.headers = ["AUTHORIZATION": "b", "Authorization-Mode": "stable"]
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) ==
                NtkRequestIdentityBuilder.build(request: second, policy: policy))

        second.headers?["Authorization-Mode"] = "changed"
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func cacheTimeAndTimeoutDoNotChangeResourceIdentity() throws {
        let first = NtkMutableRequest(IdentityBuilderConfiguredRequest(
            timeout: 10,
            cacheTime: 60
        ))
        let second = NtkMutableRequest(IdentityBuilderConfiguredRequest(
            timeout: 20,
            cacheTime: 3_600
        ))
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    private func makeRequest(token: String = "token", timestamp: Int = 0) -> NtkMutableRequest {
        var request = NtkMutableRequest(IdentityBuilderRequest())
        request.addHeader(key: "Content-Type", value: "application/json")
        request.addParameter(key: "token", value: token)
        request.addParameter(key: "timestamp", value: timestamp)
        return request
    }
}

private struct IdentityBuilderRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/identity/build" }
    var method: NtkHTTPMethod { .post }
}

private struct UnsupportedIdentityParameter: Sendable {}

private enum IdentityNormalizerError: Error, CustomStringConvertible {
    case containsSensitiveDescription
    var description: String { "secret-value" }
}

private struct IdentityBuilderConfiguredRequest: iNtkRequest {
    let timeout: TimeInterval
    let cacheTime: TimeInterval
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/identity/config-independent" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? {
        .custom(duration: cacheTime)
    }
}
