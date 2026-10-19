import XCTest
import TrackerCore
@testable import AtelierTracker

final class SongTransitionTests: XCTestCase {
    @MainActor func testOutOfRangeMeterChannelsAreSilent() async {
        let meters = TrackMeterState()
        XCTAssertEqual(meters.level(for:15),0)
        XCTAssertEqual(meters.peak(for:15),0)
        XCTAssertEqual(meters.level(for:-1),0)
    }

    @MainActor func testSymphonieToClassicMODStoppedPlayingAndRendering() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else { throw XCTSkip("Définir TRACKER_TEST_SYMMOD pour la transition réelle.") }
        let symURL = URL(fileURLWithPath:path)
        let modURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mod")
        defer { try? FileManager.default.removeItem(at:modURL) }
        try MODCodec.encode(.demo()).write(to:modURL)
        let studio = Studio()
        for mode in 0..<4 {
            studio.open(url:symURL)
            XCTAssertNil(studio.error)
            let retiredMeters = studio.meters
            XCTAssertEqual(retiredMeters.levels.count,16)
            if mode == 1 || mode == 3 {
                studio.play(patternOnly:true)
                for _ in 0..<200 where !studio.playing {
                    try await Task.sleep(nanoseconds:10_000_000)
                }
                XCTAssertTrue(studio.playing)
                if mode == 3 {studio.pause(); XCTAssertTrue(studio.paused)}
            } else if mode == 2 {
                studio.play()
                XCTAssertTrue(studio.rendering)
            }
            studio.order = studio.module.orders.count-1
            studio.row = 100; studio.channel = 15; studio.sample = 127
            studio.channelPage = 3
            studio.open(url:modURL)
            XCTAssertNil(studio.error)
            XCTAssertFalse(studio.isSymphonie)
            XCTAssertEqual(Array(studio.visibleChannels),[0,1,2,3])
            XCTAssertEqual(studio.meterLevels.count,4)
            XCTAssertFalse(studio.meters === retiredMeters)
            // Outgoing SwiftUI observers may still read this object: it must stay 16-wide.
            XCTAssertEqual(retiredMeters.levels.count,16)
            XCTAssertEqual(retiredMeters.level(for:15),0)
            XCTAssertEqual(studio.meters.level(for:15),0)
            XCTAssertEqual(studio.note,studio.module.patterns[0][0])
            XCTAssertEqual(studio.currentSample.data,studio.module.samples[0].data)
            XCTAssertTrue(studio.renderMarkers.isEmpty)
            XCTAssertTrue(studio.renderMeters.isEmpty)
            XCTAssertNil(studio.player)
            try await Task.sleep(nanoseconds:100_000_000)
            XCTAssertFalse(studio.playing)
            XCTAssertFalse(studio.rendering)
            XCTAssertTrue(studio.renderMeters.isEmpty)
        }
        studio.play()
        for _ in 0..<200 where !studio.playing {
            try await Task.sleep(nanoseconds:10_000_000)
        }
        XCTAssertTrue(studio.playing)
        XCTAssertTrue(studio.renderMeters.allSatisfy({$0.peaks.count == 4}))
        studio.stop()
    }
}
