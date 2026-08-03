import Foundation
import Testing
@testable import CooNetwork

struct NtkMutableRequestIdentityTests {
    @Test
    func headerHelpersTreatNamesAsCaseInsensitiveLogicalKeys() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setHeader("first", forField: "Authorization", requestIdentityRule: .exclude)
        request.setHeader("second", forField: "authorization", requestIdentityRule: .include)

        #expect(request.headers == ["authorization": "second"])
        #expect(request.requestIdentityRuleForHeader(named: "AUTHORIZATION") == .include)

        request.removeHeader(forField: "AUTHORIZATION")

        #expect(request.headers == [:])
        #expect(request.requestIdentityRuleForHeader(named: "Authorization") == .automatic)
    }

    @Test
    func mergeHeadersUsesSortedLastCaseVariantAndAppliesUniformRequestIdentityRule() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.mergeHeaders(
            ["authorization": "lowercase", "Authorization": "uppercase"],
            requestIdentityRule: .exclude
        )

        #expect(request.headers == ["authorization": "lowercase"])
        #expect(request.requestIdentityRuleForHeader(named: "AUTHORIZATION") == .exclude)
    }

    @Test
    func parameterRulesAndRequestIdentityValuesStayOutOfTheRequestPayload() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setParameter(123, forKey: "timestamp", requestIdentityRule: .exclude)
        request.setRequestIdentityValue("42", forKey: "user")

        #expect(request.parameters?["timestamp"] as? Int == 123)
        #expect(request.requestIdentityRuleForParameter(named: "timestamp") == .exclude)
        #expect(request.requestIdentityValues == ["user": "42"])
        #expect(request.extraData.isEmpty)
        #expect(request.headers == nil)
    }

    @Test
    func automaticClearsOverridesAndSetParametersReplacesParameterMetadata() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setParameter("first", forKey: "token", requestIdentityRule: .exclude)
        request.setParameter("second", forKey: "token", requestIdentityRule: .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "token") == .automatic)

        request.setParameter("coo", forKey: "tenant", requestIdentityRule: .include)
        request.setParameters(["next": 1], requestIdentityRule: .exclude)

        #expect(request.parameters?["next"] as? Int == 1)
        #expect(request.parameters?["tenant"] == nil)
        #expect(request.requestIdentityRuleForParameter(named: "tenant") == .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "next") == .exclude)
    }

    @Test
    func removeParameterAlsoRemovesItsRequestIdentityRuleOverride() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setParameter("secret", forKey: "Token", requestIdentityRule: .exclude)
        request.removeParameter(forKey: "token")

        #expect(request.parameters?["Token"] as? String == "secret")
        #expect(request.requestIdentityRuleForParameter(named: "Token") == .exclude)

        request.removeParameter(forKey: "Token")

        #expect(request.parameters?["Token"] == nil)
        #expect(request.requestIdentityRuleForParameter(named: "Token") == .automatic)
    }

    @Test
    func removeAllMethodsAlsoClearTheirRequestIdentityRuleOverrides() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setHeader("secret", forField: "Authorization", requestIdentityRule: .exclude)
        request.setParameter("coo", forKey: "tenant", requestIdentityRule: .include)
        request.setRequestIdentityValue("42", forKey: "user")
        request.removeAllHeaders()
        request.removeAllParameters()

        #expect(request.headers == nil)
        #expect(request.parameters == nil)
        #expect(request.requestIdentityRuleForHeader(named: "authorization") == .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "tenant") == .automatic)
        #expect(request.requestIdentityValues == ["user": "42"])
    }

    @Test
    func setCollectionsReplacePayloadAndDiscardAllPreviousFieldRules() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setHeader("first", forField: "X-Retained", requestIdentityRule: .include)
        request.setHeader("removed", forField: "X-Removed", requestIdentityRule: .exclude)
        request.setParameter("first", forKey: "retained", requestIdentityRule: .include)
        request.setParameter("removed", forKey: "removed", requestIdentityRule: .exclude)

        request.setHeaders(["x-retained": "second", "X-New": "new"])
        request.setParameters(["retained": "second", "new": "new"])

        #expect(request.headers == ["x-retained": "second", "X-New": "new"])
        #expect(request.parameters?["retained"] as? String == "second")
        #expect(request.requestIdentityRuleForHeader(named: "X-RETAINED") == .automatic)
        #expect(request.requestIdentityRuleForHeader(named: "X-New") == .automatic)
        #expect(request.requestIdentityRuleForHeader(named: "X-Removed") == .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "retained") == .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "new") == .automatic)
        #expect(request.requestIdentityRuleForParameter(named: "removed") == .automatic)
    }

    @Test
    func requestIdentityValueRemovalIsCaseSensitiveAndNeverChangesPayload() {
        var request = NtkMutableRequest(RequestIdentityMetadataRequest())

        request.setRequestIdentityValue("42", forKey: "User")
        request.setRequestIdentityValue("84", forKey: "user")

        #expect(request.requestIdentityValues == ["User": "42", "user": "84"])
        #expect(request.parameters == nil)
        #expect(request.headers == nil)
        #expect(request.extraData.isEmpty)

        request.removeRequestIdentityValue(forKey: "User")

        #expect(request.requestIdentityValues == ["user": "84"])
        #expect(request.parameters == nil)
        #expect(request.headers == nil)
        #expect(request.extraData.isEmpty)
    }

    @Test
    func requestIdentityPolicyLowercasesOnlyHeaderExclusions() {
        let policy = NtkRequestIdentityPolicy(
            excludedHeaderNames: ["Authorization"],
            excludedParameterNames: ["Token"]
        )

        #expect(policy.excludedHeaderNames == ["authorization"])
        #expect(policy.excludedParameterNames == ["Token"])
        #expect(NtkRequestIdentityPolicy.strict.excludedHeaderNames.isEmpty)
    }

    @Test(arguments: [
        CacheDurationCase(duration: 30, expectedEnabled: true),
        CacheDurationCase(duration: 0, expectedEnabled: false),
        CacheDurationCase(duration: -1, expectedEnabled: false),
        CacheDurationCase(duration: .nan, expectedEnabled: false),
        CacheDurationCase(duration: .infinity, expectedEnabled: false),
    ])
    fileprivate func cacheConfigurationRequiresAPositiveFiniteDuration(_ testCase: CacheDurationCase) {
        let configuration = NtkCacheConfiguration(cacheTime: testCase.duration)

        #expect(configuration.isEnabled == testCase.expectedEnabled)
    }

    @Test
    func cacheConfigurationFactoriesKeepTheirDocumentedDefaults() {
        let defaultConfiguration = NtkCacheConfiguration.default()
        let customConfiguration = NtkCacheConfiguration.custom(duration: 42)
        let response = NtkResponse(
            code: NtkReturnCode(200),
            data: true,
            msg: nil,
            response: true,
            request: RequestIdentityMetadataRequest(),
            isCache: false
        )

        #expect(defaultConfiguration.cacheTime == 30 * 24 * 60 * 60)
        #expect(customConfiguration.cacheTime == 42)
        #expect(defaultConfiguration.shouldCache(response))
        #expect(customConfiguration.shouldCache(response))
    }

    @Test
    func mutableRequestForwardsCacheAndRequestIdentityConfigurationFromOriginalRequest() {
        let originalRequest = RequestIdentityMetadataRequest(
            cacheConfiguration: .custom(duration: 60),
            requestIdentityPolicy: NtkRequestIdentityPolicy(
                excludedHeaderNames: ["Authorization"],
                excludedParameterNames: ["Token"]
            )
        )
        let request = NtkMutableRequest(originalRequest)

        #expect(request.cacheConfiguration?.cacheTime == 60)
        #expect(request.requestIdentityPolicy?.excludedHeaderNames == ["authorization"])
        #expect(request.requestIdentityPolicy?.excludedParameterNames == ["Token"])
    }
}

private struct RequestIdentityMetadataRequest: iNtkRequest {
    let path = "/request-identity/metadata"
    let cacheConfiguration: NtkCacheConfiguration?
    let requestIdentityPolicy: NtkRequestIdentityPolicy?

    init(
        cacheConfiguration: NtkCacheConfiguration? = nil,
        requestIdentityPolicy: NtkRequestIdentityPolicy? = nil
    ) {
        self.cacheConfiguration = cacheConfiguration
        self.requestIdentityPolicy = requestIdentityPolicy
    }
}

private struct CacheDurationCase: Sendable {
    let duration: TimeInterval
    let expectedEnabled: Bool
}
