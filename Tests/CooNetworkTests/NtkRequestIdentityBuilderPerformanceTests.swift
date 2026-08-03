import Foundation
import Testing
@testable import CooNetwork

@Suite
struct NtkRequestIdentityBuilderPerformanceTests {
    @Test
    func commonRequestBuildsWithinBudget() throws {
        let request = makePerformanceRequest(parameterCount: 12)
        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0..<1_000 {
            _ = try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        }
        #expect(start.duration(to: clock.now) < .seconds(1))
    }

    @Test
    func nestedRequestProducesOneConcurrentDigest() async throws {
        let request = makePerformanceRequest(parameterCount: 100)
        let digests = try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try NtkRequestIdentityBuilder.build(request: request, policy: .strict).digest
                }
            }
            var values: [String] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }
        #expect(digests.count == 100)
        #expect(Set(digests).count == 1)
    }
}

private struct IdentityPerformanceRequest: iNtkRequest {
    let values: [String: any Sendable]

    var baseURL: URL? { URL(string: "https://api.example.com") }
    var path: String { "/performance/request-identity" }
    var method: NtkHTTPMethod { .post }
    var parameters: [String: any Sendable]? { values }
}

private func makePerformanceRequest(parameterCount: Int) -> NtkMutableRequest {
    var values: [String: any Sendable] = [
        "nested": [
            "enabled": true,
            "ids": [1, 2, 3] as [any Sendable]
        ] as [String: any Sendable]
    ]
    for index in 0..<parameterCount {
        values["parameter_\(index)"] = "fixed-value-\(index)"
    }
    return NtkMutableRequest(IdentityPerformanceRequest(values: values))
}
