import XCTest
@testable import TrackerCore

final class PatternEditingTests: XCTestCase {
    func fixture() -> [Note] {(0..<256).map {Note(period:Note.periods[$0%36],sample:$0%31+1,effect:10,parameter:$0%256)}}
    func testReversedSelectionCopiesRowsAndChannelsInOrder() throws {
        let notes = fixture(), selection = PatternSelection(row:5,channel:3,toRow:3,toChannel:1)
        let block = try PatternEditing.copy(notes,selection:selection)
        XCTAssertEqual(block.width,3); XCTAssertEqual(block.height,3)
        XCTAssertEqual(block.notes,Array(notes[13...15])+Array(notes[17...19])+Array(notes[21...23]))
        XCTAssertThrowsError(try PatternEditing.copy(notes,selection:PatternSelection(row:-1,channel:0)))
    }
    func testPasteOverflowAndIncompatibleEventsAreAtomic() throws {
        var notes = fixture(); let original = notes
        let block = PatternBlock(width:2,height:2,notes:Array(repeating:Note(period:428,sample:31),count:4))
        XCTAssertThrowsError(try PatternEditing.paste(block,into:&notes,row:63,channel:3))
        XCTAssertEqual(notes,original)
        XCTAssertThrowsError(try PatternEditing.paste(block,into:&notes,row:Int.max,channel:0))
        XCTAssertThrowsError(try PatternEditing.paste(PatternBlock(width:0,height:0,notes:[]),into:&notes,row:0,channel:0))
        var bad = block; bad.notes[0].displayEffect = "Z80"
        XCTAssertThrowsError(try PatternEditing.paste(bad,into:&notes,row:0,channel:0))
        bad = block; bad.width = Int.max
        XCTAssertThrowsError(try PatternBlock.decode(JSONEncoder().encode(bad)))
        XCTAssertThrowsError(try PatternBlock.decode(Data(repeating:0,count:131073)))
        XCTAssertEqual(notes,original)
    }
    func testMixPreservesEmptyFieldsAndCopiesEffectPair() throws {
        var notes = fixture(); let original = notes[0]
        let block = PatternBlock(width:1,height:1,notes:[Note(effect:0,parameter:0x37)])
        _ = try PatternEditing.paste(block,into:&notes,row:0,channel:0,mix:true)
        XCTAssertEqual(notes[0].period,original.period); XCTAssertEqual(notes[0].sample,original.sample)
        XCTAssertEqual(notes[0].effect,0); XCTAssertEqual(notes[0].parameter,0x37)
        _ = try PatternEditing.paste(PatternBlock(width:1,height:1,notes:[Note()]),into:&notes,row:0,channel:0,mix:true)
        XCTAssertEqual(notes[0].parameter,0x37)
        _ = try PatternEditing.paste(block,into:&notes,row:0,channel:0)
        XCTAssertEqual(notes[0],block.notes[0])
    }
    func testOverlappingMoveUsesSnapshotAndLeavesOtherTracks() throws {
        var notes = fixture(); let original = notes
        let selection = PatternSelection(row:1,channel:0,toRow:3,toChannel:1)
        let target = try PatternEditing.move(&notes,selection:selection,rows:1,channels:1)
        XCTAssertEqual(target,PatternSelection(row:2,channel:1,toRow:4,toChannel:2))
        for r in 0..<3 {for c in 0..<2 {XCTAssertEqual(notes[(r+2)*4+c+1],original[(r+1)*4+c])}}
        XCTAssertEqual(notes[4],Note()); XCTAssertEqual(notes[7],original[7]); XCTAssertEqual(notes[0],original[0])
        let moved = notes
        XCTAssertThrowsError(try PatternEditing.move(&notes,selection:target,rows:60,channels:0))
        XCTAssertEqual(notes,moved)
    }
    func testDuplicationKeepsSourceAndRejectsLastLineOverflow() throws {
        var notes = fixture(); let original = notes
        let selection = PatternSelection(row:0,channel:2,toRow:1,toChannel:3)
        _ = try PatternEditing.move(&notes,selection:selection,rows:2,channels:0,duplicate:true)
        XCTAssertEqual(Array(notes[0..<8]),Array(original[0..<8])); XCTAssertEqual(notes[10],original[2])
        let before = notes
        XCTAssertThrowsError(try PatternEditing.move(&notes,selection:PatternSelection(row:63,channel:3),rows:1,channels:0,duplicate:true))
        XCTAssertEqual(notes,before)
    }
    func testTransposeRejectsWholeActionAtPitchLimits() throws {
        var notes = Array(repeating:Note(),count:256)
        notes[0] = Note(period:428,sample:7,effect:0xC,parameter:32)
        notes[4] = Note(period:113,sample:2)
        let original = notes, selection = PatternSelection(row:0,channel:0,toRow:1)
        XCTAssertThrowsError(try PatternEditing.transpose(&notes,selection:selection,semitones:1))
        XCTAssertEqual(notes,original)
        try PatternEditing.transpose(&notes,selection:PatternSelection(row:0,channel:0),semitones:12)
        XCTAssertEqual(notes[0],Note(period:214,sample:7,effect:0xC,parameter:32))
        notes[0].period = 856
        XCTAssertThrowsError(try PatternEditing.transpose(&notes,selection:PatternSelection(row:0,channel:0),semitones:-1))
    }
    func testInsertDeleteTracksAndTailPolicy() throws {
        var notes = fixture(); let original = notes
        let selection = PatternSelection(row:62,channel:3)
        try PatternEditing.shiftLines(&notes,selection:selection,insert:true,allTracks:false)
        XCTAssertEqual(notes[251],Note()); XCTAssertEqual(notes[255],original[251])
        for i in 0..<256 where i%4 != 3 {XCTAssertEqual(notes[i],original[i])}
        notes = original
        try PatternEditing.shiftLines(&notes,selection:selection,insert:false,allTracks:true)
        XCTAssertEqual(Array(notes[248..<252]),Array(original[252..<256]))
        XCTAssertTrue(notes[252..<256].allSatisfy({$0 == Note()}))
        notes = original
        try PatternEditing.shiftLines(&notes,selection:PatternSelection(row:0,channel:0,toRow:63,toChannel:3),insert:true,allTracks:true)
        XCTAssertTrue(notes.allSatisfy({$0 == Note()}))
    }
}
