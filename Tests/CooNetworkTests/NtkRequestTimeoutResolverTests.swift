import Foundation
import Testing
@testable import CooNetwork

struct NtkRequestTimeoutResolverTests {
    @Test(arguments: [1.0, 20.0, 100.5])
    func finitePositiveRequestTimeoutWins(_ value: TimeInterval) {
        #expect(NtkRequestTimeoutResolver.resolve(requested: value, configuredDefault: 30) == value)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidRequestTimeoutUsesConfiguredDefault(_ value: TimeInterval) {
        #expect(NtkRequestTimeoutResolver.resolve(requested: value, configuredDefault: 30) == 30)
    }

    @Test(arguments: [0.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidConfiguredDefaultUsesBuiltInValue(_ value: TimeInterval) {
        #expect(NtkRequestTimeoutResolver.resolve(requested: .nan, configuredDefault: value) == 20)
    }

    @Test
    func invalidDefaultUsesBuiltInValueAndAllValuesAreClamped() {
        #expect(NtkRequestTimeoutResolver.resolve(requested: .nan, configuredDefault: -1) == 20)
        #expect(NtkRequestTimeoutResolver.resolve(
            requested: 4_000_000_000,
            configuredDefault: 20
        ) == 3_153_600_000)
        #expect(NtkRequestTimeoutResolver.resolve(
            requested: .nan,
            configuredDefault: 4_000_000_000
        ) == 3_153_600_000)
    }

    @Test
    func deduplicationKeyUsesAllFourIsolationDimensions() {
        let requestIdentity = NtkRequestIdentity(value: "ntk-identity-v2-request-a")
        let baseline = NtkDeduplicationKey(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let identical = NtkDeduplicationKey(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let changedNamespace = NtkDeduplicationKey(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 20,
            namespace: "secondary"
        )
        let changedResponseType = NtkDeduplicationKey(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(Int.self),
            effectiveTimeout: 20,
            namespace: "default"
        )
        let changedTimeout = NtkDeduplicationKey(
            requestIdentity: requestIdentity,
            responseType: ObjectIdentifier(String.self),
            effectiveTimeout: 30,
            namespace: "default"
        )
        let changedRequestIdentity = NtkDeduplicationKey(
            requestIdentity: NtkRequestIdentity(value: "ntk-identity-v2-request-b"),
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
