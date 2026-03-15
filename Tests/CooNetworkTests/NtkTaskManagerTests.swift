import Testing
import Foundation
@testable import CooNetwork

struct NtkTaskManagerTests {

    @Test
    @NtkActor
    func testActiveRequestCount() async throws {
        NtkDeduplicationConfig.shared.reset()
        NtkDeduplicationConfig.shared.isGloballyEnabled = true

        // 验证初始状态
        let initialCount = NtkTaskManager.shared.activeRequestCount()
        #expect(initialCount == 0)
    }

    @Test
    @NtkActor
    func testCancelAllRequests() async throws {
        NtkDeduplicationConfig.shared.reset()
        NtkDeduplicationConfig.shared.isGloballyEnabled = true

        // 取消所有请求（即使没有请求也不会崩溃）
        NtkTaskManager.shared.cancelAllRequests()

        let count = NtkTaskManager.shared.activeRequestCount()
        #expect(count == 0)
    }
}
