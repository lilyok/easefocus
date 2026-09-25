import Foundation
import Testing
@testable import EaseFocus

struct StatisticsShareTests {
    @Test
    func temporaryPNGWriteIsReadable() throws {
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let url = try #require(StatisticsShareRendering.writeTemporaryPNG(bytes))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url) == bytes)
    }
}
