import XCTest
import TrackerCore
@testable import AtelierTracker

final class ImportTests: XCTestCase {
    @MainActor func testMetersDecayAndResetOnStop() async throws {
        let studio = Studio()
        var m = Module(); var sample = Sample(); sample.data = [127,0]
        m.samples[0] = sample; m.patterns[0][0] = Note(period:428,sample:1)
        studio.renderMeters = try Renderer.render(m).meters
        studio.updateMeters(at:0)
        XCTAssertGreaterThan(studio.meterLevels[0],0.99)
        let initialPeak = studio.meterHolds[0]
        studio.updateMeters(at:0.3)
        XCTAssertLessThan(studio.meterLevels[0],initialPeak)
        XCTAssertEqual(studio.meterHolds[0],initialPeak)
        studio.updateMeters(at:2)
        XCTAssertEqual(studio.meterLevels,[0,0,0,0])
        studio.stop()
        XCTAssertEqual(studio.meterHolds,[0,0,0,0])
        XCTAssertEqual(studio.meterLevels,[0,0,0,0])
    }

    @MainActor func testUserSuppliedMODThroughSampleImporter() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_MOD"] else { throw XCTSkip("Définir TRACKER_TEST_MOD pour tester un morceau externe.") }
        let studio = Studio()
        studio.importSample(url:URL(fileURLWithPath:path))
        XCTAssertNil(studio.error)
        guard studio.error == nil else { return }
        XCTAssertFalse(studio.module.samples.allSatisfy({$0.data.isEmpty}))
        let result = try Renderer.render(studio.module)
        XCTAssertGreaterThan(result.duration,0)
        XCTAssertTrue(result.wav.dropFirst(44).contains(where:{$0 != 0}))
        print("Module externe : \(studio.module.title), \(studio.module.orders.count) positions, \(studio.module.patterns.count) patterns, \(result.duration) s. \(result.warnings.joined(separator:" · "))")
    }

    @MainActor func testMODSelectedInSampleImporterOpensSong() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mod")
        defer { try? FileManager.default.removeItem(at:url) }
        var song = Module.demo(); song.title = "Imported song"
        try MODCodec.encode(song).write(to:url)
        let studio = Studio()
        studio.importSample(url:url)
        XCTAssertNil(studio.error)
        XCTAssertEqual(studio.module.title,"Imported song")
        XCTAssertEqual(studio.module.samples[0].data,song.samples[0].data)
        XCTAssertFalse(studio.hasChanges)
    }
    @MainActor func testAmigaPrefixMODSelectedInSampleImporter() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let url = folder.appendingPathComponent("mod.test-song")
        try MODCodec.encode(.demo()).write(to:url)
        let studio = Studio(); studio.importSample(url:url)
        XCTAssertNil(studio.error); XCTAssertEqual(studio.module.title,"Neon tides")
    }
    @MainActor func testInvalidMODDoesNotReplaceSongOrReachCoreAudio() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mod")
        defer { try? FileManager.default.removeItem(at:url) }
        try Data("bad MOD".utf8).write(to:url)
        let studio = Studio(); studio.importSample(url:url)
        XCTAssertTrue(studio.error?.contains("MOD incomplet") == true)
        XCTAssertFalse(studio.error?.contains("coreaudio") == true)
        XCTAssertEqual(studio.module.title,"Neon tides")
    }
}
