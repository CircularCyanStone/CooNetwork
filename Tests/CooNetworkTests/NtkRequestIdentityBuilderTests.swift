import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestIdentityBuilderTests {
    @Test
    func excludedDynamicFieldsProduceOneRequestIdentity() throws {
        var first = makeRequest(token: "token-a", timestamp: 1)
        first.setHeader("token-a", forField: "Authorization", requestIdentityRule: .exclude)
        first.setParameter("token-a", forKey: "token", requestIdentityRule: .exclude)
        first.setParameter(1, forKey: "timestamp", requestIdentityRule: .exclude)
        first.setRequestIdentityValue("42", forKey: "user")

        var second = makeRequest(token: "token-b", timestamp: 2)
        second.setHeader("token-b", forField: "authorization", requestIdentityRule: .exclude)
        second.setParameter("token-b", forKey: "token", requestIdentityRule: .exclude)
        second.setParameter(2, forKey: "timestamp", requestIdentityRule: .exclude)
        second.setRequestIdentityValue("42", forKey: "user")

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    @Test
    func includedTenantOverridesGlobalExclusionAndSeparatesRequestIdentity() throws {
        let policy = NtkRequestIdentityPolicy(excludedParameterNames: ["tenant"])
        var first = makeRequest()
        first.setParameter("a", forKey: "tenant", requestIdentityRule: .include)
        var second = makeRequest()
        second.setParameter("b", forKey: "tenant", requestIdentityRule: .include)

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func userRequestIdentityValueChangeSeparatesRequestIdentity() throws {
        var first = makeRequest()
        first.setRequestIdentityValue("1", forKey: "user")
        var second = makeRequest()
        second.setRequestIdentityValue("2", forKey: "user")

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) !=
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    @Test
    func headerCaseAndDictionaryInsertionOrderDoNotChangeRequestIdentity() throws {
        var first = makeRequest()
        first.setHeader("ios", forField: "X-CLIENT")
        first.setParameters(["outer": ["b": 2, "a": 1] as [String: Sendable]])
        var second = makeRequest()
        second.setHeader("ios", forField: "x-client")
        second.setParameters(["outer": ["a": 1, "b": 2] as [String: Sendable]])

        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    @Test
    func transformClosureCannotSeeExplicitFieldsAndCollisionFails() throws {
        let policy = NtkRequestIdentityPolicy(transformParameters: { parameters in
            #expect(parameters["secret"] == nil)
            return ["stable": "from-transform"]
        })
        var request = makeRequest()
        request.setParameter("value", forKey: "secret", requestIdentityRule: .exclude)
        request.setParameter("included", forKey: "stable", requestIdentityRule: .include)

        #expect(throws: NtkRequestIdentityBuilder.BuildError.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: policy)
        }
    }

    @Test
    func includedHeadersAndParametersBypassTransformClosuresAndAffectRequestIdentity() throws {
        let policy = NtkRequestIdentityPolicy(
            transformHeaders: { headers in
                #expect(headers["X-Stable"] == nil)
                return headers
            },
            transformParameters: { parameters in
                #expect(parameters["tenant"] == nil)
                return parameters
            }
        )
        var baseline = makeRequest()
        baseline.setHeader("header-a", forField: "X-Stable", requestIdentityRule: .include)
        baseline.setParameter("tenant-a", forKey: "tenant", requestIdentityRule: .include)
        var changedHeader = baseline
        changedHeader.setHeader("header-b", forField: "X-Stable", requestIdentityRule: .include)
        var changedParameter = baseline
        changedParameter.setParameter("tenant-b", forKey: "tenant", requestIdentityRule: .include)

        let baselineKey = try NtkRequestIdentityBuilder.build(request: baseline, policy: policy)
        #expect(baselineKey != (try NtkRequestIdentityBuilder.build(
            request: changedHeader,
            policy: policy
        )))
        #expect(baselineKey != (try NtkRequestIdentityBuilder.build(
            request: changedParameter,
            policy: policy
        )))
    }

    @Test
    func unsupportedValueReturnsInternalFailure() {
        var request = makeRequest()
        request.setParameter(UnsupportedRequestIdentityParameter(), forKey: "custom")
        #expect(throws: NtkRequestIdentityBuilder.BuildError.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        }
    }

    @Test
    func excludedParameterNamesAreCaseSensitiveExactMatches() throws {
        let policy = NtkRequestIdentityPolicy(excludedParameterNames: ["token"])
        var first = NtkMutableRequest(RequestIdentityBuilderRequest())
        first.setParameters(["token": "a", "Token": "A", "tokenValue": "one"])
        var second = NtkMutableRequest(RequestIdentityBuilderRequest())
        second.setParameters(["token": "b", "Token": "A", "tokenValue": "one"])
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) ==
                NtkRequestIdentityBuilder.build(request: second, policy: policy))

        second.setParameter("two", forKey: "tokenValue")
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func nilAndEmptyCollectionsHaveOneRequestIdentity() throws {
        let nilCollections = NtkMutableRequest(RequestIdentityBuilderRequest())
        var emptyCollections = NtkMutableRequest(RequestIdentityBuilderRequest())
        emptyCollections.setHeaders([:])
        emptyCollections.setParameters([:])
        #expect(try NtkRequestIdentityBuilder.build(request: nilCollections, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: emptyCollections, policy: .strict))
    }

    @Test
    func arrayOrderAndScalarTypesChangeRequestIdentity() throws {
        var first = NtkMutableRequest(RequestIdentityBuilderRequest())
        first.setParameters(["value": [1, 2] as [any Sendable]])
        var reordered = NtkMutableRequest(RequestIdentityBuilderRequest())
        reordered.setParameters(["value": [2, 1] as [any Sendable]])
        var stringValue = NtkMutableRequest(RequestIdentityBuilderRequest())
        stringValue.setParameters(["value": "1"])
        var booleanValue = NtkMutableRequest(RequestIdentityBuilderRequest())
        booleanValue.setParameters(["value": true])

        let integerKey = try NtkRequestIdentityBuilder.build(request: first, policy: .strict)
        #expect(integerKey != (try NtkRequestIdentityBuilder.build(request: reordered, policy: .strict)))
        #expect(integerKey != (try NtkRequestIdentityBuilder.build(request: stringValue, policy: .strict)))
        #expect(integerKey != (try NtkRequestIdentityBuilder.build(request: booleanValue, policy: .strict)))
    }

    @Test
    func supportedFoundationAndDynamicValuesRepeatExactly() throws {
        var request = NtkMutableRequest(RequestIdentityBuilderRequest())
        request.setParameters([
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
    func requestIdentityValueUsesVersionedLowercaseSHA256Format() throws {
        let requestIdentity = try NtkRequestIdentityBuilder.build(
            request: makeRequest(),
            policy: .strict
        )
        let prefix = "ntk-identity-v2-"
        let hashBytes = requestIdentity.value.dropFirst(prefix.count).utf8

        #expect(requestIdentity.value.hasPrefix(prefix))
        #expect(hashBytes.count == 64)
        #expect(hashBytes.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        })
    }

    @Test
    func transformationFailureStoresOnlyErrorType() {
        let policy = NtkRequestIdentityPolicy(transformParameters: { _ in
            throw RequestIdentityTransformError.containsSensitiveDescription
        })
        let request = NtkMutableRequest(RequestIdentityBuilderRequest())
        do {
            _ = try NtkRequestIdentityBuilder.build(request: request, policy: policy)
            Issue.record("期望字段转换失败")
        } catch let failure as NtkRequestIdentityBuilder.BuildError {
            guard case .transformationFailed(.parameters, let errorType) = failure else {
                Issue.record("错误类型不符: \(failure)")
                return
            }
            #expect(errorType.contains("RequestIdentityTransformError"))
            #expect(!errorType.contains("secret-value"))
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }

    @Test
    func duplicateCaseInsensitiveHeadersFailRequestIdentityOnly() {
        let request = NtkMutableRequest(RequestIdentityBuilderRequest(
            requestHeaders: ["Authorization": "a", "authorization": "b"]
        ))
        #expect(throws: NtkRequestIdentityBuilder.BuildError.self) {
            try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        }
    }

    @Test
    func headerExclusionIsCaseInsensitiveAndExact() throws {
        let policy = NtkRequestIdentityPolicy(excludedHeaderNames: ["Authorization"])
        var first = NtkMutableRequest(RequestIdentityBuilderRequest())
        first.setHeaders(["authorization": "a", "Authorization-Mode": "stable"])
        var second = NtkMutableRequest(RequestIdentityBuilderRequest())
        second.setHeaders(["AUTHORIZATION": "b", "Authorization-Mode": "stable"])
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) ==
                NtkRequestIdentityBuilder.build(request: second, policy: policy))

        second.setHeader("changed", forField: "Authorization-Mode")
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: policy) !=
                NtkRequestIdentityBuilder.build(request: second, policy: policy))
    }

    @Test
    func cacheTimeAndTimeoutDoNotChangeRequestIdentity() throws {
        let first = NtkMutableRequest(RequestIdentityBuilderConfiguredRequest(
            timeout: 10,
            cacheTime: 60
        ))
        let second = NtkMutableRequest(RequestIdentityBuilderConfiguredRequest(
            timeout: 20,
            cacheTime: 3_600
        ))
        #expect(try NtkRequestIdentityBuilder.build(request: first, policy: .strict) ==
                NtkRequestIdentityBuilder.build(request: second, policy: .strict))
    }

    private func makeRequest(token: String = "token", timestamp: Int = 0) -> NtkMutableRequest {
        var request = NtkMutableRequest(RequestIdentityBuilderRequest())
        request.setHeader("application/json", forField: "Content-Type")
        request.setParameter(token, forKey: "token")
        request.setParameter(timestamp, forKey: "timestamp")
        return request
    }
}

private struct RequestIdentityBuilderRequest: iNtkRequest {
    var requestHeaders: [String: String]? = nil
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/request-identity/build" }
    var method: NtkHTTPMethod { .post }
    var headers: [String: String]? { requestHeaders }
}

private struct UnsupportedRequestIdentityParameter: Sendable {}

private enum RequestIdentityTransformError: Error, CustomStringConvertible {
    case containsSensitiveDescription
    var description: String { "secret-value" }
}

private struct RequestIdentityBuilderConfiguredRequest: iNtkRequest {
    let timeout: TimeInterval
    let cacheTime: TimeInterval
    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/request-identity/config-independent" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? {
        .custom(duration: cacheTime)
    }
}
