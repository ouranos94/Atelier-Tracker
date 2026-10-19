import XCTest
import AppKit
@testable import TrackerCore
@testable import AtelierTracker

final class SymMODCompositionStudioTests: XCTestCase {
    @MainActor func studio() throws -> Studio {
        let s = try SymMODInstrumentStudioTests().studio(); s.symScoreSource = true; return s
    }
    @MainActor func testMainSourceEditKeyboardHistoryAndProtectedCell() throws {
        let s = try studio(), original = s.module
        s.selectCell(order:0,row:2,channel:12)
        XCTAssertTrue(s.canCompose); XCTAssertEqual(s.selectedSymEntry?.position,0)
        s.sample = 2; s.octave = 3; s.advance = 1; s.enter(0)
        s.cancelSymAudition()
        XCTAssertNil(s.error); XCTAssertEqual(s.row,3); XCTAssertEqual(s.undoStack.count,1)
        XCTAssertEqual(try s.symArchive!.event(pattern:0,row:2,channel:12).pitch,12)
        s.undo(); XCTAssertEqual(s.module,original); XCTAssertEqual(s.row,2)
        s.redo(); XCTAssertEqual(try s.symArchive!.event(pattern:0,row:2,channel:12).pitch,12)
        s.selectCell(order:0,row:1,channel:12)
        let before = s.module, count = s.undoStack.count
        s.editSelectedSymEvent(SymMODEvent(pitch:20,parameter:80,instrument:2))
        XCTAssertNotNil(s.error); XCTAssertEqual(s.module,before); XCTAssertEqual(s.undoStack.count,count)
        s.error = nil; s.symScoreSource = false
        XCTAssertFalse(s.canCompose); s.enter(1); XCTAssertEqual(s.module,before)
        s.symScoreSource = true
        let snapshot = s.module
        s.selectCell(order:0,row:2,channel:12)
        for invalid in [Int.min,-1,256,Int.max] {s.sample = invalid; s.enter(0); XCTAssertEqual(s.module,snapshot)}
        s.sample = 0; s.octave = Int.max; s.enter(0); XCTAssertEqual(s.module,snapshot)
        s.replaceModule(with:.demo()); XCTAssertLessThanOrEqual(s.octave,3)
    }
    @MainActor func testSymBlockCopyPasteDuplicateTransposeAndTransactionalRejections() throws {
        let s = try studio(), original = s.module
        let board = NSPasteboard(name:NSPasteboard.Name(UUID().uuidString)); defer {board.releaseGlobally()}
        s.selectCell(order:0,row:0,channel:12); s.extendSelection(toRow:0,channel:13)
        XCTAssertEqual(s.selection.width,2); XCTAssertTrue(s.copyBlock(to:board))
        XCTAssertNil(board.data(forType:Studio.blockPasteboardType))
        s.selectCell(order:0,row:4,channel:12); s.pasteBlock(from:board)
        XCTAssertNil(s.error); XCTAssertEqual(s.undoStack.count,1)
        XCTAssertEqual(try s.symArchive!.event(pattern:0,row:4,channel:12).pitch,47)
        s.transpose(1); XCTAssertEqual(try s.symArchive!.event(pattern:0,row:4,channel:12).pitch,48)
        s.duplicateBlock(); XCTAssertNil(s.error)
        XCTAssertEqual(try s.symArchive!.event(pattern:0,row:5,channel:12).pitch,48)
        s.undo(); s.undo(); s.undo(); XCTAssertEqual(s.module,original)
        s.redo(); let pasted = s.module
        s.selectCell(order:0,row:s.rows-1,channel:15); s.pasteBlock(from:board)
        XCTAssertNotNil(s.error); XCTAssertEqual(s.module,pasted); s.error = nil
        s.selectCell(order:0,row:0,channel:12); s.extendSelection(toRow:1,channel:13)
        let count = s.undoStack.count; s.clearSelection()
        XCTAssertNotNil(s.error); XCTAssertEqual(s.undoStack.count,count); XCTAssertEqual(s.module,pasted)
    }
    @MainActor func testEffectsCacheProjectRecoveryAndTransition() async throws {
        let s = try studio(), original = s.module
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:path,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:path)}
        await s.enableRecovery(directory:path.appendingPathComponent("recovery"))
        s.preparedAudio = try PlaybackTimeline(SymphonieDecoder.render(original,maximumDuration:0.1)); s.preparedID = UUID()
        s.selectCell(order:0,row:2,channel:12)
        s.editSelectedSymEvent(SymMODEvent(command:13,pitch:-1,parameter:8,instrument:64))
        XCTAssertNil(s.error); XCTAssertNil(s.preparedAudio); XCTAssertNil(s.preparedID)
        let changed = s.module
        s.fileURL = path.appendingPathComponent("composition.atelier"); XCTAssertTrue(s.save())
        let reopened = Studio(); reopened.open(url:s.fileURL!); XCTAssertEqual(reopened.module,changed)
        s.editSelectedSymEvent(SymMODEvent(command:1,pitch:-1,parameter:30))
        try await Task.sleep(nanoseconds:1_000_000_000)
        let records = await RecoveryStore(directory:path.appendingPathComponent("recovery")).candidates()
        XCTAssertEqual(records.first?.module,s.module)
        s.auditionSymInstrument(2); s.replaceModule(with:.demo())
        try await Task.sleep(nanoseconds:300_000_000)
        XCTAssertNil(s.symArchive); XCTAssertNil(s.symAudition); XCTAssertFalse(s.samplePreviewing)
        XCTAssertEqual(s.module.channelCount,4)
        await s.clearRecovery()
    }
}
