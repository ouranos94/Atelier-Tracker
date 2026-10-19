import XCTest
import TrackerCore
@testable import AtelierTracker

final class ConsoleStudioTests: XCTestCase {
    @MainActor func testLiveMixKeepsPlayerAndUndoDoesNotStop() async throws {
        let s = Studio(); s.prepareTransport()
        for _ in 0..<600 where s.preparedAudio == nil && s.error == nil {try await Task.sleep(nanoseconds:10_000_000)}
        XCTAssertNil(s.error); XCTAssertNotNil(s.preparedAudio)
        s.prepareConsole()
        for _ in 0..<600 where s.consolePreparing {try await Task.sleep(nanoseconds:10_000_000)}
        XCTAssertNil(s.error); XCTAssertTrue(s.consoleActive)
        s.play()
        let player = try XCTUnwrap(s.player); XCTAssertTrue(player is ConsolePlayer)
        s.setTrackVolume(0,0.4); s.setTrackPan(1,-0.5); s.toggleSolo(2); s.toggleMute(2)
        XCTAssertTrue(s.player === player); XCTAssertTrue(s.playing); XCTAssertTrue(s.effectiveMuted.contains(2))
        s.undo(); XCTAssertTrue(s.player === player); XCTAssertTrue(s.playing); XCTAssertEqual(s.mix.tracks[1].pan,0)
        s.pause(); s.seek(to:1); s.resume(); XCTAssertTrue(s.player === player)
        s.stop(clearCache:true); XCTAssertNil(s.consoleCache); XCTAssertFalse(s.consoleActive)
    }
    @MainActor func testReplacingSongDuringExportDoesNotChangeNewSession() async throws {
        let s = Studio(), url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer {try? FileManager.default.removeItem(at:url)}
        s.startMixExport(to:url,separate:false)
        var replacement = Module.demo(); replacement.title = "Nouvelle session"
        s.replaceModule(with:replacement)
        try await Task.sleep(nanoseconds:200_000_000)
        XCTAssertEqual(s.module.title,"Nouvelle session"); XCTAssertEqual(s.phase,.stopped)
        XCTAssertNil(s.player); XCTAssertFalse(FileManager.default.fileExists(atPath:url.path))
    }
    @MainActor func testFileReplacementCancelsConsolePreparation() async throws {
        let s = Studio(); s.prepareTransport()
        for _ in 0..<600 where s.preparedAudio == nil {try await Task.sleep(nanoseconds:10_000_000)}
        s.prepareConsole(); s.replaceModule(with:Module.demo())
        try await Task.sleep(nanoseconds:100_000_000)
        XCTAssertFalse(s.consolePreparing); XCTAssertNil(s.consoleCache); XCTAssertFalse(s.consoleActive)
    }
}
