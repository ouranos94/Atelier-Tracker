import XCTest
import TrackerCore
@testable import AtelierTracker

final class SymMODInstrumentStudioTests: XCTestCase {
    @MainActor func studio() throws -> Studio {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Fixture SymMOD requise")}
        let module = try SymphonieDecoder.decode(Data(contentsOf:URL(fileURLWithPath:path)),title:"TheSecret")
        let s = Studio(); s.replaceModule(with:module); return s
    }
    @MainActor func testInstrumentHistoryCombinedNotesExportAndStaleEditor() throws {
        let s = try studio(), original = s.module, source = original.symphonie!.source
        let doc = try SymMODDocument(source)
        s.preparedAudio = try PlaybackTimeline(SymphonieDecoder.render(original,maximumDuration:0.1)); s.preparedID = UUID()
        var edit = try doc.instrument(2).settings; edit.volume = 50
        s.editSymInstrument(2,edit:edit,expectedSource:source)
        XCTAssertNil(s.error); XCTAssertNil(s.preparedAudio); XCTAssertNil(s.preparedID); XCTAssertTrue(s.hasChanges)
        let changed = s.module
        s.undo(); XCTAssertEqual(s.module,original); s.redo(); XCTAssertEqual(s.module,changed)
        var note = try SymMODDocument(changed.symphonie!.playbackSource).event(pattern:0,row:0,channel:12); note.pitch += 1
        s.editSymNote(pattern:0,row:0,channel:12,event:note)
        let combined = s.module
        s.editSymInstrument(2,edit:edit,expectedSource:source); XCTAssertEqual(s.module,combined)
        XCTAssertEqual(s.module.symphonie?.source,source)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:path,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:path)}
        s.fileURL = path.appendingPathComponent("project.atelier"); XCTAssertTrue(s.save())
        let reopened = Studio(); reopened.open(url:s.fileURL!); XCTAssertNil(reopened.error); XCTAssertEqual(reopened.module,combined)
        let exported = path.appendingPathComponent("changed.SymMOD"); try s.exportSymMOD(to:exported)
        let archive = try SymMODDocument(Data(contentsOf:exported))
        XCTAssertEqual(try archive.instrument(2).volume,50); XCTAssertEqual(try archive.event(pattern:0,row:0,channel:12),note)
        s.symInstrumentPresented = true; s.replaceModule(with:.demo())
        XCTAssertFalse(s.symInstrumentPresented); XCTAssertEqual(s.module.channelCount,4)
        s.editSymInstrument(2,edit:edit,expectedSource:source); XCTAssertNil(s.module.symphonie)
    }
    @MainActor func testInstrumentRecoveryAndProtectedMutation() async throws {
        let s = try studio(), source = s.module.symphonie!.source, original = s.module
        let doc = try SymMODDocument(source), protected = try XCTUnwrap((0..<doc.instrumentCount).first { (try? doc.instrument($0).canEdit) == false })
        s.editSymInstrument(protected,edit:try doc.instrument(2).settings,expectedSource:source)
        XCTAssertNotNil(s.error); XCTAssertEqual(s.module,original); XCTAssertTrue(s.undoStack.isEmpty); s.error = nil
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:path)}
        await s.enableRecovery(directory:path)
        var edit = try doc.instrument(2).settings; edit.transpose = 7
        s.editSymInstrument(2,edit:edit,expectedSource:source)
        try await Task.sleep(nanoseconds:1_000_000_000)
        let records = await RecoveryStore(directory:path).candidates()
        XCTAssertEqual(records.first?.module,s.module)
        await s.clearRecovery()
    }
}
