// Tests/CooNetworkTests/NtkTransferProgressTests.swift
import Foundation
import Testing

@testable import CooNetwork

struct NtkTransferProgressTests {

    @Test func testMemberwiseInit() {
        let progress = NtkTransferProgress(
            completedUnitCount: 500,
            totalUnitCount: 1000,
            fractionCompleted: 0.5
        )
        #expect(progress.completedUnitCount == 500)
        #expect(progress.totalUnitCount == 1000)
        #expect(progress.fractionCompleted == 0.5)
    }

    @Test func testInitFromFoundationProgress() {
        let foundation = Progress(totalUnitCount: 200)
        foundation.completedUnitCount = 100
        let progress = NtkTransferProgress(from: foundation)
        #expect(progress.completedUnitCount == 100)
        #expect(progress.totalUnitCount == 200)
        #expect(progress.fractionCompleted == 0.5)
    }

    @Test func testSendableConformance() {
        let progress = NtkTransferProgress(
            completedUnitCount: 0,
            totalUnitCount: -1,
            fractionCompleted: 0.0
        )
        let _: Sendable = progress
        #expect(progress.totalUnitCount == -1)
    }
}
