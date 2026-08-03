import Foundation
import Testing
@testable import CooNetwork

struct NtkEffectiveTimeoutResolverTests {
    @Test(arguments: [1.0, 20.0, 100.5])
    func finitePositiveRequestTimeoutWins(_ value: TimeInterval) {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: value, configuredDefault: 30) == value)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidRequestTimeoutUsesConfiguredDefault(_ value: TimeInterval) {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: value, configuredDefault: 30) == 30)
    }

    @Test(arguments: [0.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidConfiguredDefaultUsesBuiltInValue(_ value: TimeInterval) {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: .nan, configuredDefault: value) == 20)
    }

    @Test
    func invalidDefaultUsesBuiltInValueAndAllValuesAreClamped() {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: .nan, configuredDefault: -1) == 20)
        #expect(NtkEffectiveTimeoutResolver.resolve(
            requested: 4_000_000_000,
            configuredDefault: 20
        ) == 3_153_600_000)
        #expect(NtkEffectiveTimeoutResolver.resolve(
            requested: .nan,
            configuredDefault: 4_000_000_000
        ) == 3_153_600_000)
    }

    @Test
    func structuredIdentityUsesAllFourIsolationDimensions() {
        let requestIdentity = NtkRequestIdentity(digest: "ntk-identity-v2-request-a")
        let baseline = NtkDeduplicationIdentity(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let identical = NtkDeduplicationIdentity(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let changedNamespace = NtkDeduplicationIdentity(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "secondary"
        )
        let changedResponseType = NtkDeduplicationIdentity(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(Int.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let changedTimeout = NtkDeduplicationIdentity(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 30,
            namespace: "default"
        )
        let changedRequestIdentity = NtkDeduplicationIdentity(
            requestIdentity: NtkRequestIdentity(digest: "ntk-identity-v2-request-b"),
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "default"
        )

        #expect(baseline == identical)
        #expect(Set([baseline, identical]).count == 1)
        #expect(baseline != changedNamespace)
        #expect(baseline != changedResponseType)
        #expect(baseline != changedTimeout)
        #expect(baseline != changedRequestIdentity)
        #expect(Set([
            baseline,
            changedNamespace,
            changedResponseType,
            changedTimeout,
            changedRequestIdentity
        ]).count == 5)
    }
}
