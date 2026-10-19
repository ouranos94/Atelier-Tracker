import XCTest
import TrackerCore
@testable import AtelierTracker

final class SymMODEditorTests: XCTestCase {
    @MainActor func studio() throws -> Studio {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Fixture SymMOD requise")}
        let s = Studio(); s.open(url:URL(fileURLWithPath:path)); XCTAssertNil(s.error); return s
    }
    @MainActor func testSymSourceUndoProjectExportAndReopening() throws {
        let s = try studio(), original = s.module
        let d = try SymMODDocument(original.symphonie!.source)
        var location: (Int,Int)?
        for r in 0..<d.rows {for c in 0..<d.channels {if location == nil, try d.event(pattern:0,row:r,channel:c).isEditableNote {location = (r,c)}}}
        let (r,c) = try XCTUnwrap(location), event = try d.event(pattern:0,row:r,channel:c)
        var replacement = event; replacement.pitch = event.pitch == 40 ? 41 : 40; replacement.parameter = 70
        s.editSymNote(pattern:0,row:r,channel:c,event:replacement)
        XCTAssertNil(s.error); XCTAssertTrue(s.hasChanges); XCTAssertNil(s.preparedAudio)
        let changed = s.module
        s.undo(); XCTAssertEqual(s.module,original); s.redo(); XCTAssertEqual(s.module,changed)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:dir)}
        let project = dir.appendingPathComponent("edited.atelier"), sym = dir.appendingPathComponent("edited.SymMOD")
        s.fileURL = project; XCTAssertTrue(s.save()); XCTAssertFalse(s.hasChanges)
        try s.exportSymMOD(to:sym)
        XCTAssertEqual(try Data(contentsOf:sym),changed.symphonie?.playbackSource)
        XCTAssertThrowsError(try s.exportSymMOD(to:sym))
        let reopened = Studio(); reopened.open(url:project); XCTAssertNil(reopened.error); XCTAssertEqual(reopened.module,changed)
        reopened.open(url:sym); XCTAssertNil(reopened.error); XCTAssertEqual(reopened.module.patterns,changed.patterns)
        XCTAssertNil(reopened.module.symphonie?.editedSource)
        s.replaceModule(with:.demo()); XCTAssertEqual(s.module.channelCount,4); XCTAssertNil(s.module.symphonie)
    }
    @MainActor func testRecoveryKeepsOriginalAndEditedSource() async throws {
        let s = try studio(), dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:dir)}
        await s.enableRecovery(directory:dir)
        let d = try SymMODDocument(s.module.symphonie!.source)
        outer: for r in 0..<d.rows {for c in 0..<d.channels {
            let e = try d.event(pattern:0,row:r,channel:c)
            if e.isEditableNote {s.editSymNote(pattern:0,row:r,channel:c,event:SymMODEvent(pitch:33,parameter:80,instrument:e.instrument)); break outer}
        }}
        await s.recoveryJob?.value
        let candidates = await RecoveryStore(directory:dir).candidates()
        XCTAssertEqual(candidates.first?.module,s.module)
        XCTAssertNotNil(candidates.first?.module.symphonie?.editedSource)
        await s.clearRecovery()
    }
}
