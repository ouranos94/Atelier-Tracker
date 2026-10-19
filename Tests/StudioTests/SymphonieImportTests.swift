import XCTest
import TrackerCore
@testable import AtelierTracker
final class SymphonieImportTests: XCTestCase {
    @MainActor func testSymphonieUsesNativeImportAndDynamicMeters() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Définir TRACKER_TEST_SYMMOD pour le test du fichier externe.")}
        let studio = Studio()
        studio.importSample(url:URL(fileURLWithPath:path))
        XCTAssertNil(studio.error)
        XCTAssertTrue(studio.isSymphonie)
        XCTAssertEqual(studio.module.channelCount,16)
        XCTAssertEqual(studio.meterLevels.count,16)
        XCTAssertEqual(studio.meterHolds.count,16)
        XCTAssertTrue(studio.isOverview)
        XCTAssertEqual(Array(studio.visibleChannels),Array(0..<16))
        studio.channelPage = 3
        XCTAssertEqual(Array(studio.visibleChannels),[12,13,14,15])
        studio.channelPage = -1
        XCTAssertEqual(Array(studio.visibleChannels),Array(0..<16))
        studio.edit {$0.title = "Must not overwrite Symphonie source"}
        XCTAssertNotEqual(studio.module.title,"Must not overwrite Symphonie source")
        XCTAssertFalse(studio.hasChanges)
        studio.newModule()
        XCTAssertEqual(studio.module.channelCount,4)
        XCTAssertEqual(studio.meterLevels.count,4)
        XCTAssertEqual(studio.channelPage,0)
    }
}
