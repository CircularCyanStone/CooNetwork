import Testing
import Foundation
@testable import CooNetwork

struct NtkPayloadNormalizationTests {

    @Test
    func dynamicDataDecodeFailureThrowsStructuredDataDecodeFailed() throws {
        do {
            _ = try NtkDynamicData(from: PayloadTestFailingDecoder())
            Issue.record("期望抛出 serialization.dataDecodeFailed")
        } catch let error as NtkError {
            if case let NtkError.responseSerializationFailed(reason: reason) = error,
               case let .dataDecodingFailed(request: _, clientResponse: _, recoveredResponse: recoveredResponse, rawPayload: _, underlyingError: underlyingError) = reason {
                #expect(recoveredResponse == nil)
                if let decodingError = underlyingError as? DecodingError,
                   case .typeMismatch = decodingError {
                    #expect(Bool(true))
                } else {
                    Issue.record("underlyingError 类型不符: \(String(describing: underlyingError))")
                }
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

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
    func normalizeKeepsNestedFoundationContainersUntouched() throws {
        let nested = NSMutableDictionary(dictionary: [
            "bool": NSNumber(value: true),
            "int": NSNumber(value: 1),
            "double": NSNumber(value: 1.5)
        ])
        let source: NSDictionary = [
            "data": nested
        ]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        let root = try #require(dynamic.getDictionary())
        let nestedObject = try #require(root["data"] as? NSMutableDictionary)
        #expect(ObjectIdentifier(nestedObject) == ObjectIdentifier(nested))
    }

    @Test
    func normalizeAcceptsDeepUnknownNestedNodeWithoutPrevalidation() throws {
        final class UnknownBox: NSObject, @unchecked Sendable {}
        let source: [String: any Sendable] = [
            "outer": [
                "inner": UnknownBox()
            ] as [String: any Sendable]
        ]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        let root = try #require(dynamic.getDictionary())
        let outer = try #require(root["outer"] as? [String: any Sendable])
        #expect(outer["inner"] is UnknownBox)
    }

    @Test
    func normalizeAcceptsNSArrayContainingUnknownNestedNodeWithoutPrevalidation() throws {
        final class UnknownBox: NSObject, @unchecked Sendable {}
        let source: NSArray = ["ok", UnknownBox()]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        let array = try #require(dynamic.getArray())
        #expect(array.count == 2)
        #expect(array[0] as? String == "ok")
        #expect(array[1] is UnknownBox)
    }

    @Test
    func normalizeStillAllowsLazyNestedDictionaryNavigation() throws {
        let source: NSDictionary = [
            "data": [
                "user": [
                    "id": 1,
                    "name": "coo"
                ]
            ]
        ]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        #expect(dynamic["data"]?["user"]?["id"]?.getInt() == 1)
        #expect(dynamic["data"]?["user"]?["name"]?.getString() == "coo")
    }

    @Test
    func normalizeStillAllowsLazyNestedArrayNavigation() throws {
        let source: NSDictionary = [
            "data": [
                ["id": 1],
                ["id": 2]
            ]
        ]

        let payload = try NtkPayload.normalize(from: source)
        guard case .dynamic(let dynamic) = payload else {
            Issue.record("期望 dynamic payload")
            return
        }

        #expect(dynamic["data"]?[0]?["id"]?.getInt() == 1)
        #expect(dynamic["data"]?[1]?["id"]?.getInt() == 2)
    }
}

private struct PayloadTestFailingDecoder: Decoder {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: Any].self,
            .init(codingPath: codingPath, debugDescription: "unsupported keyed container")
        )
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [Any].self,
            .init(codingPath: codingPath, debugDescription: "unsupported unkeyed container")
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        PayloadTestFailingSingleValueContainer()
    }
}

private struct PayloadTestFailingSingleValueContainer: SingleValueDecodingContainer {
    let codingPath: [CodingKey] = []

    func decodeNil() -> Bool { false }

    func decode(_ type: Bool.Type) throws -> Bool { throw mismatch(type) }
    func decode(_ type: String.Type) throws -> String { throw mismatch(type) }
    func decode(_ type: Double.Type) throws -> Double { throw mismatch(type) }
    func decode(_ type: Float.Type) throws -> Float { throw mismatch(type) }
    func decode(_ type: Int.Type) throws -> Int { throw mismatch(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { throw mismatch(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { throw mismatch(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { throw mismatch(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { throw mismatch(type) }
    func decode(_ type: UInt.Type) throws -> UInt { throw mismatch(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { throw mismatch(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { throw mismatch(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { throw mismatch(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { throw mismatch(type) }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        throw mismatch(type)
    }

    private func mismatch(_ type: Any.Type) -> DecodingError {
        .typeMismatch(type, .init(codingPath: codingPath, debugDescription: "forced failure for NtkDynamicData test"))
    }
}
