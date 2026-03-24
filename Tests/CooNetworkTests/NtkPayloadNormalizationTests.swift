import Testing
import Foundation
@testable import CooNetwork

struct NtkPayloadNormalizationTests {

    @Test
    func normalizeAcceptsDataRoot() throws {
        let raw = Data("hello".utf8)
        let payload = try NtkPayload.normalize(from: raw)

        guard case .data(let data) = payload else {
            Issue.record("期望 data payload")
            return
        }
        #expect(data == raw)
    }

    @Test(arguments: ["hello", true as any Sendable, 1 as any Sendable, 1.5 as any Sendable, NSNull() as any Sendable])
    func normalizeRejectsTopLevelScalar(_ raw: any Sendable) throws {
        #expect(throws: NtkError.self) {
            _ = try NtkPayload.normalize(from: raw)
        }
    }

    @Test
    func normalizeRejectsDictionaryWithNonStringKey() throws {
        let source: NSDictionary = [1: "bad"]
        #expect(throws: NtkError.self) {
            _ = try NtkPayload.normalize(from: source)
        }
    }

    @Test
    func normalizeAcceptsJSONObjectDictionary() throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "data": ["id": 1, "name": "ok"] as [String: any Sendable]
        ] as [String: any Sendable])

        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        let dict = try #require(dynamic.getDictionary())
        #expect(dict["retCode"] as? Int == 0)
        let data = try #require(dict["data"] as? [String: any Sendable])
        #expect(data["id"] as? Int == 1)
        #expect(data["name"] as? String == "ok")
    }

    @Test
    func normalizeAcceptsArrayRoot() throws {
        let payload = try NtkPayload.normalize(from: ["a", 1, true] as [any Sendable])

        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        let array = try #require(dynamic.getArray())
        #expect(array.count == 3)
        #expect(array[0] as? String == "a")
        #expect(array[1] as? Int == 1)
        #expect(array[2] as? Bool == true)
    }

    @Test
    func normalizeDistinguishesNSNumberKindsInNestedStructure() throws {
        let source: NSDictionary = [
            "bool": NSNumber(value: true),
            "int": NSNumber(value: 1),
            "double": NSNumber(value: 1.5)
        ]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        #expect(dynamic["bool"]?.getBool() == true)
        #expect(dynamic["int"]?.getInt() == 1)
        #expect(dynamic["double"]?.getDouble() == 1.5)
    }

    @Test
    func normalizeRejectsDeepInvalidNestedNode() throws {
        final class UnknownBox: NSObject, @unchecked Sendable {}
        let source: [String: any Sendable] = [
            "outer": [
                "inner": UnknownBox()
            ] as [String: any Sendable]
        ]

        #expect(throws: NtkError.self) {
            _ = try NtkPayload.normalize(from: source)
        }
    }

    @Test
    func normalizeRejectsNSArrayContainingInvalidNode() throws {
        final class UnknownBox: NSObject, @unchecked Sendable {}
        let source: NSArray = ["ok", UnknownBox()]

        #expect(throws: NtkError.self) {
            _ = try NtkPayload.normalize(from: source)
        }
    }

    @Test
    func normalizeRejectsUnknownNSObject() throws {
        final class UnknownBox: NSObject, @unchecked Sendable {}

        #expect(throws: NtkError.self) {
            _ = try NtkPayload.normalize(from: UnknownBox())
        }
    }
}
