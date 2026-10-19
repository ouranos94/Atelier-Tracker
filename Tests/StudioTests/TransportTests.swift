import XCTest
import TrackerCore
@testable import AtelierTracker

final class TransportTests: XCTestCase {
    @MainActor func waitForPlayback(_ s: Studio) async throws {
        for _ in 0..<600 where !s.playing && s.error == nil {try await Task.sleep(nanoseconds:10_000_000)}
        XCTAssertNil(s.error); XCTAssertTrue(s.playing)
    }
    @MainActor func exercise(_ s: Studio) async throws {
        defer {s.stop()}
        s.row = 12
        s.playFromSelection()
        try await waitForPlayback(s)
        let cache = try XCTUnwrap(s.preparedID), player = try XCTUnwrap(s.player)
        XCTAssertEqual(s.row,12)
        XCTAssertGreaterThan(s.clock.elapsed,0)
        s.pause()
        XCTAssertEqual(s.phase,.paused)
        let time = s.clock.elapsed
        try await Task.sleep(nanoseconds:60_000_000)
        XCTAssertEqual(s.clock.elapsed,time)
        s.resume(); XCTAssertTrue(s.playing); XCTAssertTrue(s.player === player)
        s.seek(to:2); s.pause()
        XCTAssertEqual(s.clock.elapsed,2,accuracy:0.1)
        XCTAssertEqual(s.preparedID,cache); XCTAssertTrue(s.player === player)
        XCTAssertEqual(s.row,12)
        s.seek(to:1); s.markA(); s.seek(to:2); s.markB(); s.setLoop(.selection)
        XCTAssertEqual(s.loopMode,.selection)
        XCTAssertEqual(s.player?.numberOfLoops,-1)
        XCTAssertEqual(try XCTUnwrap(s.activeRange).duration,1,accuracy:0.0001)
        s.resume()
        try await Task.sleep(nanoseconds:1_150_000_000)
        s.syncPlayback()
        XCTAssertTrue(s.playing); XCTAssertGreaterThanOrEqual(s.clock.elapsed,1); XCTAssertLessThan(s.clock.elapsed,2)
        s.beginScrub(); XCTAssertTrue(s.paused); s.seek(to:3); s.endScrub()
        XCTAssertTrue(s.playing); XCTAssertEqual(s.loopMode,.off)
        s.pause(); s.setLoop(.pattern)
        XCTAssertEqual(s.player?.numberOfLoops,-1)
        XCTAssertEqual(s.preparedID,cache)
        s.stop()
        XCTAssertEqual(s.phase,.stopped); XCTAssertNil(s.player); XCTAssertEqual(s.preparedID,cache)
    }
    @MainActor func testMODTransport() async throws {
        let s = Studio()
        try await exercise(s)
        s.play(); try await waitForPlayback(s); s.stop()
        let id = try XCTUnwrap(s.preparedID)
        s.edit {$0.title = s.module.title}
        XCTAssertEqual(s.preparedID,id)
        s.edit {$0.title = "Edited"}
        XCTAssertNil(s.preparedID)
    }
    @MainActor func testSymphonieTransport() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("TRACKER_TEST_SYMMOD requis")}
        let s = Studio(); s.open(url:URL(fileURLWithPath:path))
        try await exercise(s)
    }
    @MainActor func testCancelPreparationCannotRestartPlayback() async throws {
        let s = Studio(); s.play(); XCTAssertTrue(s.rendering); s.stop(clearCache:true)
        try await Task.sleep(nanoseconds:100_000_000)
        XCTAssertEqual(s.phase,.stopped); XCTAssertNil(s.player); XCTAssertNil(s.preparedAudio)
    }
}
