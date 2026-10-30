import Testing
import Foundation
@testable import CooNetwork

struct NtkCacheMetaTests {
    @Test
    func shouldReturnNilWhenAppVersionMissing() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(1.0, forKey: "creationDate")
        archiver.encode(2.0, forKey: "expirationDate")
        archiver.finishEncoding()
        
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        defer { unarchiver.finishDecoding() }
        
        let decoded = NtkCacheMeta(coder: unarchiver)
        
        #expect(decoded == nil)
    }

    // MARK: - NSNull 往返

    @Test
    func roundTripsTopLevelNull() throws {
        let decoded = try #require(try roundTrip(NSNull()))

        #expect(decoded.data is NSNull)
    }

    @Test
    func roundTripsDictionaryContainingNull() throws {
        let decoded = try #require(try roundTrip(["module": NSNull()] as [String: Sendable]))
        let data = try #require(decoded.data as? [String: Sendable])

        #expect(data.count == 1)
        #expect(data["module"] is NSNull)
    }

    @Test
    func roundTripsArrayContainingNull() throws {
        let decoded = try #require(try roundTrip([1, NSNull(), "text"] as [Sendable]))
        let data = try #require(decoded.data as? [Sendable])

        #expect(data.count == 3)
        #expect(data[1] is NSNull)
    }

    @Test
    func roundTripsDeeplyNestedNull() throws {
        let value: [String: Sendable] = [
            "code": 0,
            "codeNameList": [NSNull()] as [Sendable],
            "moduleList": [
                "module": ["title": NSNull()] as [String: Sendable]
            ] as [String: Sendable]
        ]
        let decoded = try #require(try roundTrip(value))
        let data = try #require(decoded.data as? [String: Sendable])

        #expect(data["code"] as? Int == 0)
        #expect((data["codeNameList"] as? [Sendable])?.first is NSNull)
        let moduleList = try #require(data["moduleList"] as? [String: Sendable])
        let module = try #require(moduleList["module"] as? [String: Sendable])
        #expect(module["title"] is NSNull)
    }

    @Test
    func roundTripsJSONScalarDictionary() throws {
        let decoded = try #require(try roundTrip(["code": 0, "message": "ok"] as [String: Sendable]))
        let data = try #require(decoded.data as? [String: Sendable])

        #expect(data["code"] as? Int == 0)
        #expect(data["message"] as? String == "ok")
    }

    // MARK: - 写入侧白名单

    @Test
    func canEncodeAcceptsOnlyRoundTrippableTypes() {
        #expect(NtkCacheMeta.canEncode("text"))
        #expect(NtkCacheMeta.canEncode(true))
        #expect(NtkCacheMeta.canEncode(42))
        #expect(NtkCacheMeta.canEncode(1.5))
        #expect(NtkCacheMeta.canEncode(Float(1.5)))
        #expect(NtkCacheMeta.canEncode(Data([0x01])))
        #expect(NtkCacheMeta.canEncode(NSNull()))
        #expect(NtkCacheMeta.canEncode([String: Sendable]()))
        #expect(NtkCacheMeta.canEncode([Sendable]()))
    }

    @Test
    func canEncodeAcceptsNestedContainersWithNull() {
        #expect(NtkCacheMeta.canEncode(["n": NSNull()] as [String: Sendable]))
        #expect(NtkCacheMeta.canEncode([1, NSNull()] as [Sendable]))
        #expect(NtkCacheMeta.canEncode(["a": ["b": [NSNull()]]] as [String: Sendable]))
    }

    @Test
    func canEncodeRejectsTypesThatCannotBeDecodedBack() {
        // URL 与 Date 能被归档编码，但不在解档白名单内：放行会让整条缓存记录读取失败。
        #expect(!NtkCacheMeta.canEncode(URL(string: "https://example.com")!))
        #expect(!NtkCacheMeta.canEncode(Date(timeIntervalSince1970: 0)))
        #expect(!NtkCacheMeta.canEncode(["u": URL(string: "https://example.com")!] as [String: Sendable]))
        #expect(!NtkCacheMeta.canEncode([Date(timeIntervalSince1970: 0)] as [Sendable]))
        #expect(!NtkCacheMeta.canEncode(["a": [["d": Date(timeIntervalSince1970: 0)] as [String: Sendable]]] as [String: Sendable]))
    }

    // MARK: - 脏缓存降级

    @Test
    func returnsNilWhenPersistedDataContainsUnsupportedType() throws {
        // 模拟旧版本或写入侧未校验时落盘的数据：构造时不经过 canEncode。
        let dirty = NtkCacheMeta(
            appVersion: "1.0.0",
            creationDate: 1,
            expirationDate: 2,
            data: ["u": URL(string: "https://example.com")!] as [String: Sendable]
        )
        let archived = try NSKeyedArchiver.archivedData(withRootObject: dirty, requiringSecureCoding: true)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archived)
        defer { unarchiver.finishDecoding() }

        let decoded = unarchiver.decodeObject(of: NtkCacheMeta.self, forKey: NSKeyedArchiveRootObjectKey)

        // 整体判为无效，而非返回一个 data 为 nil 的“伪命中”。
        #expect(decoded == nil)
    }

    @Test
    func keepsMetadataWhenDataKeyIsAbsent() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode("1.0.0", forKey: "appVersion")
        archiver.encode(1.0, forKey: "creationDate")
        archiver.encode(2.0, forKey: "expirationDate")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        defer { unarchiver.finishDecoding() }
        let decoded = try #require(NtkCacheMeta(coder: unarchiver))

        // data 缺失是合法状态（写入侧只在 data 非 nil 时编码），不能与“解不出来”混为一谈。
        #expect(decoded.appVersion == "1.0.0")
        #expect(decoded.data == nil)
    }
}

/// 用完整对象归档的方式往返一次，模拟 storage 的真实读写路径。
private func roundTrip(_ data: Sendable) throws -> NtkCacheMeta? {
    let meta = NtkCacheMeta(appVersion: "1.0.0", creationDate: 1, expirationDate: 2, data: data)
    let archived = try NSKeyedArchiver.archivedData(withRootObject: meta, requiringSecureCoding: true)
    let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archived)
    defer { unarchiver.finishDecoding() }
    return unarchiver.decodeObject(of: NtkCacheMeta.self, forKey: NSKeyedArchiveRootObjectKey)
}
