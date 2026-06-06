import Testing
import Foundation
@testable import CooNetwork

struct NtkRequestIdentifierManagerTests {

    // MARK: - LRU 双向链表测试

    /// 测试：空链表的基本属性
    @Test
    func lruList_empty_initial_state() {
        let list = LRUList<String, Int>()

        #expect(list.head == nil)
        #expect(list.tail == nil)
        #expect(list.count == 0)
    }

    /// 测试：添加单个节点
    @Test
    func lruList_add_single_node() {
        let list = LRUList<String, Int>()
        let node = list.addFirst(key: "a", value: 1)

        #expect(list.head === node)
        #expect(list.tail === node)
        #expect(list.count == 1)
        #expect(node.key == "a")
        #expect(node.value == 1)
        #expect(node.prev == nil)
        #expect(node.next == nil)
    }

    /// 测试：添加多个节点，顺序正确
    @Test
    func lruList_add_multiple_nodes_order() {
        let list = LRUList<String, Int>()
        let node1 = list.addFirst(key: "a", value: 1)
        let node2 = list.addFirst(key: "b", value: 2)
        let node3 = list.addFirst(key: "c", value: 3)

        #expect(list.count == 3)

        // 链表顺序应该是: c -> b -> a
        #expect(list.head === node3)
        #expect(list.tail === node1)

        // 检查链表指针关系
        #expect(node3.prev == nil)
        #expect(node3.next === node2)

        #expect(node2.prev === node3)
        #expect(node2.next === node1)

        #expect(node1.prev === node2)
        #expect(node1.next == nil)
    }

    /// 测试：移动节点到头部（已在头部）
    @Test
    func lruList_move_to_first_already_at_head() {
        let list = LRUList<String, Int>()
        let node1 = list.addFirst(key: "a", value: 1)
        let node2 = list.addFirst(key: "b", value: 2)

        // node2 已经在头部
        list.moveToFirst(node2)

        #expect(list.head === node2)
        #expect(list.tail === node1)
        #expect(list.count == 2)
    }

    /// 测试：移动节点到头部（在中间）
    @Test
    func lruList_move_to_first_from_middle() {
        let list = LRUList<String, Int>()
        let node1 = list.addFirst(key: "a", value: 1)
        let node2 = list.addFirst(key: "b", value: 2)
        let node3 = list.addFirst(key: "c", value: 3)

        // 当前顺序: c -> b -> a
        // 移动 node1 到头部
        list.moveToFirst(node1)

        #expect(list.head === node1)
        #expect(list.tail === node2)  // a -> c -> b，尾部是 b
        #expect(list.count == 3)

        // 新顺序: a -> c -> b
        #expect(node1.next === node3)
        #expect(node3.prev === node1)
        #expect(node3.next === node2)
        #expect(node2.prev === node3)
    }

    /// 测试：移动节点到头部（在尾部）
    @Test
    func lruList_move_to_first_from_tail() {
        let list = LRUList<String, Int>()
        let node1 = list.addFirst(key: "a", value: 1)
        let node2 = list.addFirst(key: "b", value: 2)

        // 当前顺序: b -> a, node1 在尾部
        list.moveToFirst(node1)

        #expect(list.head === node1)
        #expect(list.tail === node2)
        #expect(list.count == 2)

        // 新顺序: a -> b
        #expect(node1.next === node2)
        #expect(node2.prev === node1)
        #expect(node2.next == nil)
    }

    /// 测试：移除尾部节点
    @Test
    func lruList_remove_last() {
        let list = LRUList<String, Int>()
        list.addFirst(key: "a", value: 1)
        list.addFirst(key: "b", value: 2)
        list.addFirst(key: "c", value: 3)

        // 当前顺序: c -> b -> a
        let removed = list.removeLast()

        #expect(removed?.key == "a")
        #expect(removed?.value == 1)
        #expect(list.count == 2)

        // 链表应该是: c -> b
        #expect(list.head?.key == "c")
        #expect(list.tail?.key == "b")
    }

    /// 测试：移除空链表的尾部节点
    @Test
    func lruList_remove_last_empty_list() {
        let list = LRUList<String, Int>()

        let removed = list.removeLast()

        #expect(removed == nil)
        #expect(list.count == 0)
    }

    /// 测试：移除单个节点的链表
    @Test
    func lruList_remove_last_single_node() {
        let list = LRUList<String, Int>()
        list.addFirst(key: "a", value: 1)

        let removed = list.removeLast()

        #expect(removed?.key == "a")
        #expect(list.head == nil)
        #expect(list.tail == nil)
        #expect(list.count == 0)
    }

    /// 测试：连续添加和移除
    @Test
    func lruList_continuous_add_and_remove() {
        let list = LRUList<Int, String>()

        // 添加 5 个节点
        for i in 1...5 {
            list.addFirst(key: i, value: "value_\(i)")
        }

        #expect(list.count == 5)

        // 移除 3 个
        for _ in 1...3 {
            _ = list.removeLast()
        }

        #expect(list.count == 2)
        #expect(list.head?.key == 5)
        #expect(list.tail?.key == 4)
    }

    /// 测试：LRU 缓存淘汰场景模拟
    @Test
    func lruList_cache_eviction_scenario() {
        let list = LRUList<String, Int>()
        var nodeIndex: [String: LRUNode<String, Int>] = [:]

        // 模拟缓存容量为 3
        let capacity = 3

        // 添加 key1
        let node1 = list.addFirst(key: "key1", value: 1)
        nodeIndex["key1"] = node1

        // 添加 key2
        let node2 = list.addFirst(key: "key2", value: 2)
        nodeIndex["key2"] = node2

        // 添加 key3
        let node3 = list.addFirst(key: "key3", value: 3)
        nodeIndex["key3"] = node3

        #expect(list.count == 3)

        // 访问 key1（移动到头部）
        if let node = nodeIndex["key1"] {
            list.moveToFirst(node)
        }

        // 链表现在是: key1 -> key3 -> key2（访问 key1 后）
        #expect(list.head?.key == "key1")
        #expect(list.tail?.key == "key2")

        // 手动模拟淘汰：移除最久未使用的 key2
        if let removed = list.removeLast() {
            nodeIndex.removeValue(forKey: removed.key)
        }

        #expect(list.count == 2)  // 现在是 2

        // 添加 key4
        let node4 = list.addFirst(key: "key4", value: 4)
        nodeIndex["key4"] = node4

        #expect(list.count == 3)

        // 验证链表顺序: key4 -> key1 -> key3
        #expect(list.head?.key == "key4")
        #expect(list.tail?.key == "key3")
    }

    /// 测试：高频访问场景
    @Test
    func lruList_high_frequency_access() {
        let list = LRUList<Int, Int>()
        var nodeIndex: [Int: LRUNode<Int, Int>] = [:]

        // 添加 10 个节点
        for i in 0..<10 {
            let node = list.addFirst(key: i, value: i * 10)
            nodeIndex[i] = node
        }

        // 高频访问节点 5（每次访问都移动到头部）
        for _ in 0..<100 {
            if let node = nodeIndex[5] {
                list.moveToFirst(node)
            }
        }

        // 验证节点 5 在头部
        #expect(list.head?.key == 5)
        #expect(list.head?.value == 50)
        #expect(list.count == 10)
    }

    // MARK: - weak prev 引用验证

    /// 测试：移除尾部节点后，被移除节点的引用已断开
    @Test
    func lruList_removed_tail_node_has_no_references() {
        let list = LRUList<String, Int>()
        let node1 = list.addFirst(key: "a", value: 1)
        let node2 = list.addFirst(key: "b", value: 2)
        _ = list.addFirst(key: "c", value: 3)

        // 当前顺序: c -> b -> a
        _ = list.removeLast()

        // 被移除的 node1 的引用应已清理
        #expect(node1.prev == nil)
        #expect(node1.next == nil)

        // 新尾部 node2 的 next 应为 nil
        #expect(node2.next == nil)
    }

    /// 测试：移除中间节点后，链表完整性保持
    @Test
    func lruList_move_from_middle_maintains_integrity() {
        let list = LRUList<String, Int>()
        let nodeA = list.addFirst(key: "a", value: 1)
        let nodeB = list.addFirst(key: "b", value: 2)
        let nodeC = list.addFirst(key: "c", value: 3)

        // 当前顺序: c -> b -> a，移动中间的 b 到头部
        list.moveToFirst(nodeB)

        // 新顺序: b -> c -> a
        #expect(list.head === nodeB)
        #expect(nodeB.prev == nil)
        #expect(nodeB.next === nodeC)
        #expect(nodeC.prev === nodeB)
        #expect(nodeC.next === nodeA)
        #expect(nodeA.prev === nodeC)
        #expect(nodeA.next == nil)
        #expect(list.count == 3)
    }

    /// 测试：连续移除所有节点后，head/tail 均为 nil
    @Test
    func lruList_remove_all_nodes_leaves_empty() {
        let list = LRUList<String, Int>()
        _ = list.addFirst(key: "a", value: 1)
        _ = list.addFirst(key: "b", value: 2)
        _ = list.addFirst(key: "c", value: 3)

        _ = list.removeLast()
        _ = list.removeLast()
        _ = list.removeLast()

        #expect(list.head == nil)
        #expect(list.tail == nil)
        #expect(list.count == 0)
    }

    // MARK: - NtkRequestIdentifierManager 集成测试

    /// 测试：缓存键生成的一致性
    @Test
    @NtkActor
    func request_identifier_manager_cache_key_consistency() async {
        let request = createTestRequest()
        let config = NtkRequestConfiguration(cacheTime: 3600)

        // 多次调用应该返回相同的缓存键
        let
 key1 = NtkRequestIdentifierManager.shared.getCacheKey(request: request, cacheConfig: config)
        let key2 = NtkRequestIdentifierManager.shared.getCacheKey(request: request, cacheConfig: config)
        let key3 = NtkRequestIdentifierManager.shared.getCacheKey(request: request, cacheConfig: config)

        #expect(key1 == key2)
        #expect(key2 == key3)
    }

    /// 测试：不同请求生成不同的缓存键
    @Test
    @NtkActor
    func request_identifier_manager_different_requests_different_keys() async {
        let request1 = createTestRequest(path: "/api/user/1")
        let request2 = createTestRequest(path: "/api/user/2")

        let key1 = NtkRequestIdentifierManager.shared.getCacheKey(request: request1, cacheConfig: nil)
        let key2 = NtkRequestIdentifierManager.shared.getCacheKey(request: request2, cacheConfig: nil)

        #expect(key1 != key2)
    }

    /// 测试：去重标识符生成的一致性
    @Test
    @NtkActor
    func request_identifier_manager_deduplication_consistency() async {
        let request = createTestRequest()

        let id1 = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        let id2 = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)

        #expect(id1 == id2)
    }

    // MARK: - Helper Methods

    private func createTestRequest(
        baseURL: URL? = URL(string: "https://api.example.com"),
        path: String = "/api/test",
        method: NtkHTTPMethod = .get,
        headers: [String: String]? = nil,
        parameters: [String: Sendable]? = nil
    ) -> NtkMutableRequest {
        struct TestRequest: iNtkRequest {
            let baseURL: URL?
            let path: String
            let method: NtkHTTPMethod
            let headers: [String: String]?
            let parameters: [String: Sendable]?

            var requestHeaders: [String: String]? { headers }
            var requestConfiguration: NtkRequestConfiguration? { nil }
            var timeout: TimeInterval { 30 }
        }

        let request = TestRequest(
            baseURL: baseURL,
            path: path,
            method: method,
            headers: headers,
            parameters: parameters
        )
        return NtkMutableRequest(request)
    }
}
