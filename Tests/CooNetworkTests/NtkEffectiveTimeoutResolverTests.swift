import Foundation
import Testing
@testable import CooNetwork

struct NtkEffectiveTimeoutResolverTests {
    @Test(arguments: [1.0, 20.0, 100.5])
    func finitePositiveRequestTimeoutWins(_ value: TimeInterval) {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: value, configuredDefault: 30) == value)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func invalidRequestTimeoutUsesConfiguredDefault(_ value: TimeInterval) {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: value, configuredDefault: 30) == 30)
    }

    @Test
    func invalidDefaultUsesBuiltInValueAndAllValuesAreClamped() {
        #expect(NtkEffectiveTimeoutResolver.resolve(requested: .nan, configuredDefault: -1) == 20)
        #expect(NtkEffectiveTimeoutResolver.resolve(
            requested: 4_000_000_000,
            configuredDefault: 20
        ) == 3_153_600_000)
    }
}
