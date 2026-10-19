import XCTest
@testable import TrackerCore
@testable import AtelierTracker

final class SymMODArrangementStudioTests: XCTestCase {
    @MainActor func testArrangementShorteningClampsSelectionAndPreservesHistoryProjectExport() throws {
        let s = try SymMODInstrumentStudioTests().studio(), original = s.module, source = original.symphonie!.source
        let d = try SymMODDocument(source)
        s.order = original.orders.count-1; s.row = s.rows-1
        let previousOrder = s.order, previousRow = s.row
        s.preparedAudio = try PlaybackTimeline(SymphonieDecoder.render(original,maximumDuration:0.1)); s.preparedID = UUID()
        s.selectionA = 1; s.selectionB = 2
        var q = d.sequences[0]; q.start = 0; q.length = 1
        s.editSymSequence(0,edit:q,expectedSource:source)
        XCTAssertNil(s.error); XCTAssertNil(s.preparedAudio); XCTAssertNil(s.preparedID)
        XCTAssertNil(s.selectionA); XCTAssertNil(s.selectionB)
        XCTAssertEqual(s.module.orders.count,1); XCTAssertEqual(s.order,0)
        XCTAssertLessThan(s.row,s.rows); XCTAssertEqual(s.clock.duration,s.module.symphonie!.duration)
        let changed = s.module
        s.undo(); XCTAssertEqual(s.module,original); XCTAssertEqual(s.order,previousOrder); XCTAssertEqual(s.row,previousRow); XCTAssertEqual(s.clock.duration,original.symphonie!.duration)
        s.redo(); XCTAssertEqual(s.module,changed); XCTAssertEqual(s.order,0); XCTAssertLessThan(s.row,s.rows); XCTAssertEqual(s.clock.duration,changed.symphonie!.duration)
        s.editSymSequence(0,edit:q,expectedSource:source); XCTAssertEqual(s.module,changed)
        var p = d.positions[0]; p.speed = 6
        s.editSymPosition(0,edit:p,expectedSource:changed.symphonie!.playbackSource)
        XCTAssertNil(s.error); XCTAssertEqual(s.module.symphonie!.source,source)
        let combined = s.module
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:path,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:path)}
        s.fileURL = path.appendingPathComponent("arrangement.atelier"); XCTAssertTrue(s.save())
        let reopened = Studio(); reopened.open(url:s.fileURL!); XCTAssertNil(reopened.error); XCTAssertEqual(reopened.module,combined)
        let output = path.appendingPathComponent("arrangement.SymMOD"); try s.exportSymMOD(to:output)
        let exported = try SymMODDocument(Data(contentsOf:output))
        XCTAssertEqual(exported.sequences[0].length,1); XCTAssertEqual(exported.positions[0].speed,6)
        XCTAssertEqual(exported.events,d.events); XCTAssertEqual(exported.instrumentData,d.instrumentData)
        s.symArrangementPresented = true; s.replaceModule(with:.demo())
        XCTAssertFalse(s.symArrangementPresented); XCTAssertEqual(s.module.channelCount,4)
    }
    @MainActor func testProtectedNoOpAndRecovery() async throws {
        let s = try SymMODInstrumentStudioTests().studio(), source = s.module.symphonie!.source, original = s.module
        let d = try SymMODDocument(source)
        s.editSymPosition(0,edit:d.positions[0],expectedSource:source)
        XCTAssertTrue(s.undoStack.isEmpty); XCTAssertFalse(s.hasChanges)
        s.editSymSequence(1,edit:d.sequences[1],expectedSource:source)
        XCTAssertNotNil(s.error); XCTAssertEqual(s.module,original); XCTAssertTrue(s.undoStack.isEmpty); s.error = nil
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:path)}
        await s.enableRecovery(directory:path)
        var p = d.positions[0]; p.repeats = 2
        s.editSymPosition(0,edit:p,expectedSource:source)
        try await Task.sleep(nanoseconds:1_000_000_000)
        let records = await RecoveryStore(directory:path).candidates()
        XCTAssertEqual(records.first?.module,s.module)
        await s.clearRecovery()
    }
}
