import XCTest
import AppKit
import TrackerCore
@testable import AtelierTracker

final class CompositionTests: XCTestCase {
    @MainActor func testPasteSharedPatternUndoRestoresSelectionAndData() throws {
        let s = Studio(); s.module.orders = [0,0]
        let board = NSPasteboard(name:NSPasteboard.Name(UUID().uuidString))
        defer {board.releaseGlobally()}
        s.selectCell(order:0,row:0,channel:0); s.extendSelection(toRow:3,channel:1)
        let copied = s.selection
        s.copyBlock(to:board); XCTAssertTrue(s.undoStack.isEmpty)
        s.selectCell(order:1,row:40,channel:2)
        let before = s.module
        s.pasteBlock(from:board)
        XCTAssertNil(s.error); XCTAssertEqual(s.undoStack.count,1)
        XCTAssertEqual(s.selection,PatternSelection(row:40,channel:2,toRow:43,toChannel:3))
        XCTAssertEqual(s.module.patterns[0][40*4+2],before.patterns[0][copied.rowRange.lowerBound*4])
        let after = s.module, selected = s.selection
        XCTAssertTrue(s.status.contains("partagé"))
        s.undo(); XCTAssertEqual(s.module,before); XCTAssertEqual(s.order,1); XCTAssertEqual(s.row,40); XCTAssertEqual(s.channel,2)
        s.redo(); XCTAssertEqual(s.module,after); XCTAssertEqual(s.selection,selected)
    }
    @MainActor func testCutAndLineInsertionAreSingleUndoableActions() throws {
        let s = Studio(); let before = s.module
        let board = NSPasteboard(name:NSPasteboard.Name(UUID().uuidString)); defer {board.releaseGlobally()}
        s.selectCell(order:0,row:0,channel:0); s.extendSelection(toRow:8,channel:3)
        let selection = s.selection
        s.cutBlock(to:board); XCTAssertEqual(s.undoStack.count,1)
        XCTAssertTrue(s.module.patterns[0][0..<36].allSatisfy({$0 == Note()}))
        s.undo(); XCTAssertEqual(s.module,before); XCTAssertEqual(s.selection,selection)
        s.shiftLines(insert:true); let inserted = s.module
        XCTAssertEqual(s.undoStack.count,1)
        s.undo(); XCTAssertEqual(s.module,before); s.redo(); XCTAssertEqual(s.module,inserted)
    }
    @MainActor func testSliderGestureGroupsEditsAndNoopDoesNotAddHistory() {
        let s = Studio(); let before = s.module
        s.selectCell(order:0,row:8,channel:2)
        s.beginEditGesture()
        for volume in [60,52,43,27,12] {s.edit {$0.samples[0].volume = volume}}
        s.endEditGesture()
        XCTAssertEqual(s.undoStack.count,1)
        s.undo(); XCTAssertEqual(s.module,before); XCTAssertEqual(s.row,8); XCTAssertEqual(s.channel,2)
        s.redo(); XCTAssertEqual(s.module.samples[0].volume,12)
        let count = s.undoStack.count
        s.beginEditGesture(); s.edit {$0.samples[0].volume = 12}; s.endEditGesture()
        XCTAssertEqual(s.undoStack.count,count)
    }
    @MainActor func testRejectedPasteDoesNotCreateHistoryOrDirtyTheSong() throws {
        let s = Studio(); let before = s.module
        let board = NSPasteboard(name:NSPasteboard.Name(UUID().uuidString)); defer {board.releaseGlobally()}
        s.selectPattern(); s.copyBlock(to:board)
        s.selectCell(order:0,row:63,channel:3); s.pasteBlock(from:board)
        XCTAssertNotNil(s.error); XCTAssertEqual(s.module,before); XCTAssertTrue(s.undoStack.isEmpty); XCTAssertFalse(s.hasChanges)
    }
    @MainActor func testKeyboardMappingsAndPitchBoundary() {
        XCTAssertEqual(MusicalKeyboard.azerty.note(for:"w"),0)
        XCTAssertEqual(MusicalKeyboard.azerty.note(for:"é"),13)
        XCTAssertEqual(MusicalKeyboard.qwerty.note(for:"z"),0)
        XCTAssertEqual(MusicalKeyboard.qwerty.note(for:"2"),13)
        let s = Studio(), before = s.module
        s.octave = 3; s.enter(12)
        XCTAssertEqual(s.module,before); XCTAssertFalse(s.hasChanges); XCTAssertTrue(s.undoStack.isEmpty)
    }
    @MainActor func testEveryBlockMutationRoundTripsThroughHistory() {
        let actions: [(Studio) -> Void] = [
            {$0.clearSelection()}, {$0.transpose(1)}, {$0.transpose(12)},
            {$0.transpose(-1,wholePattern:true)}, {$0.moveBlock(rows:1)},
            {$0.moveBlock(rows:0,channels:1)}, {$0.duplicateBlock()},
            {$0.shiftLines(insert:true)}, {$0.shiftLines(insert:false)}
        ]
        for action in actions {
            let s = Studio()
            s.selectCell(order:0,row:0,channel:0); s.extendSelection(toRow:4,channel:0)
            let before = s.module, selection = s.selection
            action(s)
            XCTAssertNil(s.error); XCTAssertEqual(s.undoStack.count,1)
            let after = s.module, resultSelection = s.selection
            XCTAssertNotEqual(after,before)
            s.undo(); XCTAssertEqual(s.module,before); XCTAssertEqual(s.selection,selection)
            XCTAssertEqual(s.row,4); XCTAssertEqual(s.channel,0)
            s.redo(); XCTAssertEqual(s.module,after); XCTAssertEqual(s.selection,resultSelection)
        }
    }
    @MainActor func testTranslatedSymphonieViewRejectsCompositionMutations() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("TRACKER_TEST_SYMMOD requis")}
        let s = Studio(); let sourceMode = s.symScoreSource; s.symScoreSource = false; defer {s.symScoreSource = sourceMode}; s.open(url:URL(fileURLWithPath:path)); let original = s.module
        s.selectPattern(); s.transpose(1); s.clearSelection(); s.moveBlock(rows:1); s.duplicateBlock(); s.shiftLines(insert:true)
        let board = NSPasteboard(name:NSPasteboard.Name(UUID().uuidString)); defer {board.releaseGlobally()}
        s.copyBlock(to:board); s.cutBlock(to:board); s.pasteBlock(from:board)
        XCTAssertEqual(s.module,original); XCTAssertTrue(s.undoStack.isEmpty); XCTAssertFalse(s.canCompose)
        XCTAssertNil(board.data(forType:Studio.blockPasteboardType))
    }
}
