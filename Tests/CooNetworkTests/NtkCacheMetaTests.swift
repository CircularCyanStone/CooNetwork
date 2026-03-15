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
}
