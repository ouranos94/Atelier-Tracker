import XCTest
@testable import TrackerCore

final class SymMODCompositionTests: XCTestCase {
    func real() throws -> Module {try SymMODDocumentTests().realModule()}
    func testMappingEveryRealOrderRowAndMismatchProtection() throws {
        let m = try real(), d = try SymMODDocument(m.symphonie!.source), map = try XCTUnwrap(m.symphonie!.orderSource)
        XCTAssertEqual(map.count,m.orders.count)
        let forged = try JSONDecoder().decode(SymMODOrderSource.self,from:JSONSerialization.data(withJSONObject:["sequence":0,"position":0,"pattern":Int.max,"start":0,"length":1,"transpose":0]))
        XCTAssertThrowsError(try d.cell(in:forged,row:0,channel:0))
        for o in m.orders.indices {
            let entry = try XCTUnwrap(map[o]); XCTAssertEqual(entry.length,m.rowCount(pattern:m.orders[o]))
            XCTAssertEqual(try d.cell(in:entry,row:0,channel:0).pattern,entry.pattern)
            XCTAssertEqual(try d.cell(in:entry,row:entry.length-1,channel:d.channels-1).row,entry.start+entry.length-1)
        }
        var rows = m.patterns.map {$0.count/m.channelCount}; rows[m.orders[0]] += 1
        XCTAssertNil(d.orderMapping(orders:m.orders,patternRows:rows))
        XCTAssertNil(d.orderMapping(orders:Array(m.orders.dropLast()),patternRows:m.patterns.map {$0.count/m.channelCount}))
        let repeated = try SymphonieDecoder.replacingPosition(in:m,index:0,edit:{var p = d.positions[0];p.repeats = 2;return p}())
        XCTAssertEqual(repeated.symphonie!.orderSource![0],repeated.symphonie!.orderSource![1])
        var old = try JSONSerialization.jsonObject(with:JSONEncoder().encode(m)) as! [String:Any]
        var sym = old["symphonie"] as! [String:Any]; sym.removeValue(forKey:"orderSource"); old["symphonie"] = sym
        let decoded = try JSONDecoder().decode(Module.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertNil(decoded.symphonie!.orderSource); XCTAssertEqual(try SymphonieDecoder.refreshed(decoded),m)
    }
    func testBatchAtomicityPACKAndProtectedCells() throws {
        let helpers = SymMODDocumentTests(), source = helpers.fixture(packed:true), d = try SymMODDocument(source)
        let ordinary = SymMODCellEdit(pattern:0,row:0,channel:0,event:SymMODEvent(command:1,pitch:-1,parameter:90))
        let protected = SymMODCellEdit(pattern:0,row:0,channel:1,event:SymMODEvent())
        XCTAssertThrowsError(try d.replacingEvents([ordinary,protected]))
        XCTAssertThrowsError(try d.replacingEvents([ordinary,ordinary]))
        let out = try d.replacingEvents([ordinary]), edited = try SymMODDocument(out)
        XCTAssertEqual(try edited.event(pattern:0,row:0,channel:0).command,1)
        XCTAssertEqual(out.suffix(39),source.suffix(39)); XCTAssertEqual(edited.instrumentData,d.instrumentData)
        XCTAssertEqual(try edited.replacingEvents([ordinary]),out)
        XCTAssertThrowsError(try d.replacingEvents([SymMODCellEdit(pattern:0,row:0,channel:0,event:SymMODEvent(command:24))]))
        XCTAssertThrowsError(try d.replacingEvents([SymMODCellEdit(pattern:0,row:0,channel:0,event:SymMODEvent(command:13,parameter:16))]))
        for effect in SymMODEffect.allCases {XCTAssertFalse(effect.explanation.isEmpty)}
    }
    func testBlockBoundsBankAndPreservingEffectsDuringTransposePreparation() throws {
        let m = try real(), d = try SymMODDocument(m.symphonie!.source), entry = try XCTUnwrap(m.symphonie!.orderSource![0])
        let range = PatternSelection(row:0,channel:12,toRow:0,toChannel:13)
        let block = try d.copyBlock(entry:entry,selection:range)
        XCTAssertEqual(block.width,2); XCTAssertEqual(block.height,1)
        let copied = try SymMODBlock.decode(JSONEncoder().encode(block))
        let edits = try d.editsForPaste(copied,entry:entry,row:4,channel:12)
        let changed = try SymMODDocument(d.replacingEvents(edits))
        XCTAssertEqual(try changed.event(pattern:entry.pattern,row:entry.start+4,channel:12),block.events[0])
        XCTAssertThrowsError(try d.editsForPaste(block,entry:entry,row:entry.length,channel:12))
        XCTAssertThrowsError(try d.editsForPaste(block,entry:entry,row:0,channel:15))
        let other = SymMODBlock(width:2,height:1,bank:"other",events:block.events)
        XCTAssertThrowsError(try d.editsForPaste(other,entry:entry,row:0,channel:0))
        let empty = SymMODBlock(width:1,height:1,bank:d.instrumentBankID,events:[SymMODEvent()])
        XCTAssertTrue(try d.editsForPaste(empty,entry:entry,row:0,channel:0,mix:true).isEmpty)
        XCTAssertThrowsError(try SymMODBlock(width:Int.max,height:1,bank:"",events:[]).validate())
    }
    func testSupportedEffectsSurviveExportAndReachAudio() throws {
        let m = try real(), d = try SymMODDocument(m.symphonie!.source)
        let before = try SymphonieDecoder.render(m,maximumDuration:1).wav
        for effect in [SymMODEffect.volumeDown,.pitchUp,.vibrato,.tremolo,.speed] {
            let event = SymMODEvent(command:effect.rawValue,pitch:-1,parameter:effect == .speed ? 9 : effect == .vibrato ? 8 : 90,instrument:effect.usesRate ? 64 : 0)
            let changed = try SymphonieDecoder.replacingEvents(in:m,edits:[SymMODCellEdit(pattern:0,row:2,channel:12,event:event)])
            XCTAssertEqual(try SymMODDocument(changed.symphonie!.playbackSource).event(pattern:0,row:2,channel:12),event)
            XCTAssertEqual(changed.symphonie!.source,m.symphonie!.source)
            let after = try SymphonieDecoder.render(changed,maximumDuration:1).wav
            XCTAssertGreaterThan(SymMODDocumentTests().rmsDifference(before,after),8,"\(effect)")
            let reopened = try SymphonieDecoder.decode(changed.symphonie!.playbackSource,title:changed.title)
            XCTAssertEqual(reopened.patterns,changed.patterns)
            XCTAssertEqual(try SymMODDocument(reopened.symphonie!.source).instrumentData,d.instrumentData)
        }
    }
    func testAuditionDoesNotLeakSongNotesIntoPreview() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let original = try SymphonieDecoder.decode(Data(contentsOf:root.appendingPathComponent("Fixtures/SymMOD/mono.SymMOD")))
        let doc = try SymMODDocument(original.symphonie!.source)
        var events = Data(); for _ in 0..<doc.events.count/4 {events.append(SymMODEvent().bytes)}
        let silentSong = try SymphonieDecoder.decode(doc.replacingEventPayload(events))
        let a = try SymphonieDecoder.audition(original,instrument:2,seconds:0.4)
        let b = try SymphonieDecoder.audition(silentSong,instrument:2,seconds:0.4)
        XCTAssertGreaterThan(a.peaks.max() ?? 0,0.01)
        XCTAssertLessThan(SymMODDocumentTests().rmsDifference(a.wav,b.wav),4)
    }
    func testIsolatedAuditionRendersInstrumentAndRejectsEmptySlot() throws {
        let m = try real(), d = try SymMODDocument(m.symphonie!.source)
        let result = try SymphonieDecoder.audition(m,instrument:2,seconds:0.4)
        XCTAssertGreaterThan(result.peaks.max() ?? 0,0.001); XCTAssertGreaterThan(result.wav.count,44)
        XCTAssertGreaterThan(result.duration,0.1); XCTAssertLessThanOrEqual(result.duration,0.4)
        let empty = try XCTUnwrap((0..<d.instrumentCount).first {(try? d.instrument($0).name.isEmpty) == true})
        XCTAssertThrowsError(try SymphonieDecoder.audition(m,instrument:empty))
        XCTAssertThrowsError(try SymphonieDecoder.audition(m,instrument:2,pitch:Int.max))
        XCTAssertThrowsError(try SymphonieDecoder.audition(m,instrument:2,seconds:.infinity))
        let before = try SymphonieDecoder.audition(m,instrument:0,seconds:0.4)
        XCTAssertNotEqual(before.peaks,result.peaks)
    }
}
