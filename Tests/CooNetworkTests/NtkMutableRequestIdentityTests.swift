import Foundation
import Testing
@testable import CooNetwork

struct NtkMutableRequestIdentityTests {
    @Test
    func headerHelpersTreatNamesAsCaseInsensitiveLogicalKeys() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addHeader(key: "Authorization", value: "first", identity: .excluded)
        request.addHeader(key: "authorization", value: "second", identity: .included)

        #expect(request.headers == ["authorization": "second"])
        #expect(request.identityParticipation(forHeader: "AUTHORIZATION") == .included)

        request.removeHeader(key: "AUTHORIZATION")

        #expect(request.headers == [:])
        #expect(request.identityParticipation(forHeader: "Authorization") == .automatic)
    }

    @Test
    func addHeadersUsesSortedLastCaseVariantAndAppliesUniformParticipation() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addHeaders(
            ["authorization": "lowercase", "Authorization": "uppercase"],
            identity: .excluded
        )

        #expect(request.headers == ["authorization": "lowercase"])
        #expect(request.identityParticipation(forHeader: "AUTHORIZATION") == .excluded)
    }

    @Test
    func parameterMetadataAndIdentityComponentsStayOutOfTheRequestPayload() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addParameter(key: "timestamp", value: 123, identity: .excluded)
        request.addIdentityComponent(key: "user", value: "42")

        #expect(request.parameters?["timestamp"] as? Int == 123)
        #expect(request.identityParticipation(forParameter: "timestamp") == .excluded)
        #expect(request.identityComponents == ["user": "42"])
        #expect(request.extraData.isEmpty)
        #expect(request.headers == nil)
    }

    @Test
    func automaticClearsOverridesAndSetParameterReplacesParameterMetadata() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addParameter(key: "token", value: "first", identity: .excluded)
        request.addParameter(key: "token", value: "second", identity: .automatic)
        #expect(request.identityParticipation(forParameter: "token") == .automatic)

        request.addParameter(key: "tenant", value: "coo", identity: .included)
        request.setParameter(["next": 1], identity: .excluded)

        #expect(request.parameters?["next"] as? Int == 1)
        #expect(request.parameters?["tenant"] == nil)
        #expect(request.identityParticipation(forParameter: "tenant") == .automatic)
        #expect(request.identityParticipation(forParameter: "next") == .excluded)
    }

    @Test
    func removeParameterAlsoRemovesItsParticipationOverride() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addParameter(key: "Token", value: "secret", identity: .excluded)
        request.removeParameter(key: "token")

        #expect(request.parameters?["Token"] as? String == "secret")
        #expect(request.identityParticipation(forParameter: "Token") == .excluded)

        request.removeParameter(key: "Token")

        #expect(request.parameters?["Token"] == nil)
        #expect(request.identityParticipation(forParameter: "Token") == .automatic)
    }

    @Test
    func clearHelpersAlsoClearTheirParticipationOverrides() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addHeader(key: "Authorization", value: "secret", identity: .excluded)
        request.addParameter(key: "tenant", value: "coo", identity: .included)
        request.addIdentityComponent(key: "user", value: "42")
        request.clearHeaders()
        request.clearParameters()

        #expect(request.headers == nil)
        #expect(request.parameters == nil)
        #expect(request.identityParticipation(forHeader: "authorization") == .automatic)
        #expect(request.identityParticipation(forParameter: "tenant") == .automatic)
        #expect(request.identityComponents == ["user": "42"])
    }

    @Test
    func pruneIdentityMetadataPreservesExistingOverridesAndRemovesStaleOnes() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addHeader(key: "X-Retained", value: "first", identity: .included)
        request.addHeader(key: "X-Removed", value: "removed", identity: .excluded)
        request.addParameter(key: "retained", value: "first", identity: .included)
        request.addParameter(key: "removed", value: "removed", identity: .excluded)
        request.addParameter(key: "CaseSensitive", value: "first", identity: .excluded)

        request.headers = ["x-retained": "second", "X-New": "new"]
        request.parameters = ["retained": "second", "new": "new", "casesensitive": "second"]
        request.pruneIdentityMetadata()

        #expect(request.identityParticipation(forHeader: "X-RETAINED") == .included)
        #expect(request.identityParticipation(forHeader: "X-New") == .automatic)
        #expect(request.identityParticipation(forHeader: "X-Removed") == .automatic)
        #expect(request.identityParticipation(forParameter: "retained") == .included)
        #expect(request.identityParticipation(forParameter: "new") == .automatic)
        #expect(request.identityParticipation(forParameter: "removed") == .automatic)
        #expect(request.identityParticipation(forParameter: "CaseSensitive") == .automatic)
        #expect(request.identityParticipation(forParameter: "casesensitive") == .automatic)
    }

    @Test
    func identityComponentRemovalIsCaseSensitiveAndNeverChangesPayload() {
        var request = NtkMutableRequest(IdentityMetadataRequest())

        request.addIdentityComponent(key: "User", value: "42")
        request.addIdentityComponent(key: "user", value: "84")

        #expect(request.identityComponents == ["User": "42", "user": "84"])
        #expect(request.parameters == nil)
        #expect(request.headers == nil)
        #expect(request.extraData.isEmpty)

        request.removeIdentityComponent(key: "User")

        #expect(request.identityComponents == ["user": "84"])
        #expect(request.parameters == nil)
        #expect(request.headers == nil)
        #expect(request.extraData.isEmpty)
    }

    @Test
    func identityPolicyNormalizesOnlyHeaderExclusions() {
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
            request: IdentityMetadataRequest(),
            isCache: false
        )

        #expect(defaultConfiguration.cacheTime == 30 * 24 * 60 * 60)
        #expect(customConfiguration.cacheTime == 42)
        #expect(defaultConfiguration.shouldCache(response))
        #expect(customConfiguration.shouldCache(response))
    }

    @Test
    func mutableRequestForwardsCacheAndIdentityConfigurationFromOriginalRequest() {
        let originalRequest = IdentityMetadataRequest(
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

private struct IdentityMetadataRequest: iNtkRequest {
    let path = "/identity/metadata"
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
