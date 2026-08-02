import Foundation
import Testing
@testable import CooNetwork

struct NtkCanonicalIdentityEncoderTests {

    @Test
    func dictionariesEncodeIdenticallyRegardlessOfInsertionOrder() throws {
        let first: [String: any Sendable] = ["b": 2, "a": 1]
        let second: [String: any Sendable] = ["a": 1, "b": 2]

        let firstEncoding = try NtkCanonicalIdentityEncoder.encodeValue(first, path: "parameters")
        let secondEncoding = try NtkCanonicalIdentityEncoder.encodeValue(second, path: "parameters")

        #expect(firstEncoding == secondEncoding)
    }

    @Test
    func dictionaryKeyAndValueChangesProduceDifferentBytes() throws {
        let baseline: [String: any Sendable] = ["a": 1]
        let changedKey: [String: any Sendable] = ["b": 1]
        let changedValue: [String: any Sendable] = ["a": 2]

        let baselineEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            baseline,
            path: "parameters"
        )
        let changedKeyEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            changedKey,
            path: "parameters"
        )
        let changedValueEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            changedValue,
            path: "parameters"
        )

        #expect(baselineEncoding != changedKeyEncoding)
        #expect(baselineEncoding != changedValueEncoding)
    }

    @Test
    func typedSwiftContainersEncodeRecursivelyWhenTypeErasedToSendable() throws {
        let typed: any Sendable = [
            "dictionary": ["b": 2, "a": 1] as [String: Int],
            "array": [1, 2, 3] as [Int]
        ] as [String: any Sendable]
        let existential: any Sendable = [
            "dictionary": ["a": 1 as any Sendable, "b": 2 as any Sendable] as [String: any Sendable],
            "array": [1 as any Sendable, 2 as any Sendable, 3 as any Sendable] as [any Sendable]
        ] as [String: any Sendable]

        let typedEncoding = try NtkCanonicalIdentityEncoder.encodeValue(typed, path: "parameters")
        let existentialEncoding = try NtkCanonicalIdentityEncoder.encodeValue(existential, path: "parameters")

        #expect(typedEncoding == existentialEncoding)
    }

    @Test
    func typedStringDictionaryUsesRecursiveEncoding() throws {
        let typed: any Sendable = ["b": "two", "a": "one"] as [String: String]
        let existential: any Sendable = [
            "a": "one" as any Sendable,
            "b": "two" as any Sendable
        ] as [String: any Sendable]

        let typedEncoding = try NtkCanonicalIdentityEncoder.encodeValue(typed, path: "parameters")
        let existentialEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            existential,
            path: "parameters"
        )

        #expect(typedEncoding == existentialEncoding)
    }

    @Test
    func typedBoolArrayUsesRecursiveEncoding() throws {
        let typed: any Sendable = [true, false, true] as [Bool]
        let existential: any Sendable = [
            true as any Sendable,
            false as any Sendable,
            true as any Sendable
        ] as [any Sendable]

        let typedEncoding = try NtkCanonicalIdentityEncoder.encodeValue(typed, path: "parameters")
        let existentialEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            existential,
            path: "parameters"
        )

        #expect(typedEncoding == existentialEncoding)
    }

    @Test
    func nestedTypedDictionariesAndArraysUseRecursiveEncoding() throws {
        let typed: any Sendable = [
            "groups": [
                ["flags": [true, false]],
                ["flags": [false]]
            ]
        ] as [String: [[String: [Bool]]]]
        let existential: any Sendable = [
            "groups": [
                ["flags": [true as any Sendable, false as any Sendable] as [any Sendable]]
                    as [String: any Sendable],
                ["flags": [false as any Sendable] as [any Sendable]]
                    as [String: any Sendable]
            ] as [any Sendable]
        ] as [String: any Sendable]

        let typedEncoding = try NtkCanonicalIdentityEncoder.encodeValue(typed, path: "parameters")
        let existentialEncoding = try NtkCanonicalIdentityEncoder.encodeValue(
            existential,
            path: "parameters"
        )

        #expect(typedEncoding == existentialEncoding)
    }

    @Test
    func arrayOrderAndScalarTypesRemainDistinct() throws {
        let forward = try NtkCanonicalIdentityEncoder.encodeValue([1, 2] as [Int], path: "parameters")
        let reversed = try NtkCanonicalIdentityEncoder.encodeValue([2, 1] as [Int], path: "parameters")
        let string = try NtkCanonicalIdentityEncoder.encodeValue("1", path: "value")
        let integer = try NtkCanonicalIdentityEncoder.encodeValue(1, path: "value")
        let boolean = try NtkCanonicalIdentityEncoder.encodeValue(true, path: "value")

        #expect(forward != reversed)
        #expect(string != integer)
        #expect(integer != boolean)
        #expect(string != boolean)
    }

    @Test
    func supportedScalarCategoriesNeverCollide() throws {
        let encodings = try [
            NtkCanonicalIdentityEncoder.encodeValue("1", path: "value"),
            NtkCanonicalIdentityEncoder.encodeValue(true, path: "value"),
            NtkCanonicalIdentityEncoder.encodeValue(Int(1), path: "value"),
            NtkCanonicalIdentityEncoder.encodeValue(UInt(1), path: "value"),
            NtkCanonicalIdentityEncoder.encodeValue(Float(1), path: "value"),
            NtkCanonicalIdentityEncoder.encodeValue(Double(1), path: "value")
        ]

        for index in encodings.indices {
            for otherIndex in encodings.indices where index < otherIndex {
                #expect(encodings[index] != encodings[otherIndex])
            }
        }
    }

    @Test
    func foundationValuesUseSpecifiedCanonicalFrames() throws {
        let uuid = try #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"))
        let url = try #require(URL(string: "https://example.com/items?q=identity"))
        var dateBits = Date(timeIntervalSinceReferenceDate: 123.5)
            .timeIntervalSinceReferenceDate.bitPattern.bigEndian
        let datePayload = withUnsafeBytes(of: &dateBits) { Data($0) }

        #expect(
            try NtkCanonicalIdentityEncoder.encodeValue(Data([0, 1, 2]), path: "value")
                == identityTestFrame(tag: 8, payload: Data([0, 1, 2]))
        )
        #expect(
            try NtkCanonicalIdentityEncoder.encodeValue(url, path: "value")
                == identityTestFrame(tag: 9, payload: Data(url.absoluteString.utf8))
        )
        #expect(
            try NtkCanonicalIdentityEncoder.encodeValue(uuid, path: "value")
                == identityTestFrame(
                    tag: 10,
                    payload: Data([
                        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                        0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
                    ])
                )
        )
        #expect(
            try NtkCanonicalIdentityEncoder.encodeValue(
                Date(timeIntervalSinceReferenceDate: 123.5),
                path: "value"
            ) == identityTestFrame(tag: 11, payload: datePayload)
        )
        #expect(
            try NtkCanonicalIdentityEncoder.encodeValue(NSNull(), path: "value")
                == identityTestFrame(tag: 12, payload: Data())
        )
    }

    @Test
    func separateDynamicValuesEncodeLikeTheirCanonicalDictionary() throws {
        let uuid = try #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"))
        let url = try #require(URL(string: "https://example.com/items?q=identity"))
        let dictionary: [String: any Sendable] = [
            "uuid": uuid,
            "date": Date(timeIntervalSinceReferenceDate: 123.5),
            "data": Data([0, 1, 2]),
            "url": url,
            "null": NSNull()
        ]
        let first = NtkDynamicData(dictionary: dictionary)
        let second = NtkDynamicData(dictionary: [
            "null": NSNull(),
            "url": url,
            "data": Data([0, 1, 2]),
            "date": Date(timeIntervalSinceReferenceDate: 123.5),
            "uuid": uuid
        ])

        let firstEncoding = try NtkCanonicalIdentityEncoder.encodeValue(first, path: "parameters")
        let secondEncoding = try NtkCanonicalIdentityEncoder.encodeValue(second, path: "parameters")
        let dictionaryEncoding = try NtkCanonicalIdentityEncoder.encodeValue(dictionary, path: "parameters")

        #expect(firstEncoding == secondEncoding)
        #expect(firstEncoding == dictionaryEncoding)
    }

    @Test
    func bridgedFoundationNumbersAreRejectedWithExactFailures() {
        let path = "parameters.paymentAmount"
        let values: [any Sendable] = [
            NSNumber(value: true),
            NSNumber(value: 1),
            NSDecimalNumber(string: "314159.265")
        ]

        for value in values {
            let expectedType = String(reflecting: type(of: value))
            do {
                _ = try NtkCanonicalIdentityEncoder.encodeValue(value, path: path)
                Issue.record("期望拒绝白名单外的 Foundation 数值类型")
            } catch let failure as NtkRequestIdentityBuilder.Failure {
                #expect(failure == .unsupportedValue(path: path, type: expectedType))
                #expect(!failure.diagnosticDescription.contains("314159.265"))
            } catch {
                Issue.record("错误类型不符: \(String(reflecting: type(of: error)))")
            }
        }
    }

    @Test
    func nonFiniteAndUnsupportedValuesExposeSanitizedExactFailures() {
        do {
            _ = try NtkCanonicalIdentityEncoder.encodeValue(Double.nan, path: "parameters.value")
            Issue.record("期望拒绝非有限数值")
        } catch let failure as NtkRequestIdentityBuilder.Failure {
            #expect(
                failure == .nonFiniteValue(
                    path: "parameters.value",
                    type: String(reflecting: Double.self)
                )
            )
            #expect(!failure.diagnosticDescription.contains("nan"))
        } catch {
            Issue.record("错误类型不符: \(String(reflecting: type(of: error)))")
        }

        let secret = "secret-identity-value-8721"
        do {
            _ = try NtkCanonicalIdentityEncoder.encodeValue(
                SensitiveUnsupportedIdentityValue(secret: secret),
                path: "parameters.value"
            )
            Issue.record("期望拒绝不支持的值")
        } catch let failure as NtkRequestIdentityBuilder.Failure {
            #expect(
                failure == .unsupportedValue(
                    path: "parameters.value",
                    type: String(reflecting: SensitiveUnsupportedIdentityValue.self)
                )
            )
            #expect(!failure.diagnosticDescription.contains(secret))
        } catch {
            Issue.record("错误类型不符: \(String(reflecting: type(of: error)))")
        }
    }
}

private struct SensitiveUnsupportedIdentityValue: Sendable {
    let secret: String
}

private func identityTestFrame(tag: UInt8, payload: Data) -> Data {
    var result = Data([tag])
    var length = UInt64(payload.count).bigEndian
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(payload)
    return result
}
