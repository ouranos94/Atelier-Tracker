import XCTest
@testable import TrackerCore

final class SymMODAuthoringTests: XCTestCase {
    func wave(_ count: Int = 4096) -> SymPCM {SymPCM(samples:(0..<count).map {Int16(sin(Double($0)*0.12)*20000)})}
    func testCreateAppendReuseDuplicateRemoveAndSourcePreservation() throws {
        for channels in [1,4,16,32] {
            let m = try SymMODComposer.create(title:"Création",channels:channels,rows:32,instruments:8)
            let d = try SymMODDocument(m.symphonie!.source)
            XCTAssertEqual(m.channelCount,channels);XCTAssertEqual(d.patternCount,1);XCTAssertEqual(d.positions.count,1);XCTAssertEqual(d.instrumentCount,8)
            XCTAssertTrue(SymMODComposer.canExpand(d));XCTAssertNotNil(m.symphonie!.orderSource)
            let a = try SymMODComposer.append(in:m), b = try SymMODComposer.append(in:a,pattern:0)
            XCTAssertEqual(try SymMODDocument(b.symphonie!.playbackSource).patternCount,2);XCTAssertEqual(b.orders.count,3)
            let c = try SymMODComposer.append(in:b,pattern:0,duplicate:true)
            XCTAssertEqual(try SymMODDocument(c.symphonie!.playbackSource).patternCount,3)
            let removed = try SymMODComposer.removePosition(in:c,index:1)
            XCTAssertEqual(removed.orders.count,3);XCTAssertEqual(removed.symphonie!.source,m.symphonie!.source)
            XCTAssertThrowsError(try SymMODComposer.removePosition(in:m,index:0))
            XCTAssertEqual(try SymphonieDecoder.decode(removed.symphonie!.playbackSource,title:removed.title).patterns,removed.patterns)
        }
        XCTAssertThrowsError(try SymMODComposer.create(title:"bad",channels:Int.max))
    }
    func testPCMImportExactWaveLoopAndAudibleExport() throws {
        let m = try SymMODComposer.create(title:"PCM",channels:4), source = m.symphonie!.source
        let pcm = wave(), changed = try SymphonieDecoder.replacingPCM(in:m,index:0,pcm:pcm,name:"Oscillateur")
        let doc = try SymMODDocument(changed.symphonie!.playbackSource)
        XCTAssertEqual(try doc.pcm(0)?.samples,pcm.samples);XCTAssertEqual(try doc.instrument(0).name,"Oscillateur")
        XCTAssertEqual(changed.symphonie!.source,source);XCTAssertTrue(try doc.instrument(0).canEdit)
        let withNote = try SymphonieDecoder.replacingEvents(in:changed,edits:[SymMODCellEdit(pattern:0,row:0,channel:0,event:SymMODEvent(pitch:36,parameter:100))])
        XCTAssertGreaterThan(SymMODInstrumentTests().rms(try SymphonieDecoder.render(withNote,maximumDuration:0.3).wav),20)
        var settings = try doc.instrument(0).settings;settings.loop = SymMODLoop(enabled:true,start:25*65536,length:50*65536)
        let looped = try SymphonieDecoder.replacingInstrument(in:withNote,index:0,edit:settings)
        XCTAssertEqual(try SymMODDocument(looped.symphonie!.playbackSource).pcm(0)?.samples,pcm.samples)
        XCTAssertEqual(try SymMODDocument(looped.symphonie!.playbackSource).instrument(0).loop,settings.loop)
        XCTAssertThrowsError(try doc.replacingPCM(100,pcm:pcm,name:"bad"))
    }
    func testRealPCMAndOtherBlocksArePreservedWhenReplacingOneSlot() throws {
        let m = try SymMODDocumentTests().realModule(), doc = try SymMODDocument(m.symphonie!.source)
        let raw = try XCTUnwrap(doc.pcm(2));XCTAssertFalse(raw.samples.isEmpty)
        let before = try SymMODStorage(doc.source), out = try doc.replacingPCM(2,pcm:wave(),name:"Replacement")
        let after = try SymMODStorage(out), changedIDs = zip(before.chunks,after.chunks).filter {$0.raw != $1.raw}.map {$0.0.id}
        XCTAssertEqual(changedIDs,[-14,-11]);XCTAssertEqual(try SymMODDocument(out).events,doc.events)
        let model = try SymphonieDecoder.replacingPCM(in:m,index:2,pcm:wave(),name:"Replacement")
        XCTAssertEqual(model.symphonie!.source,doc.source)
        XCTAssertEqual(try SymMODDocument(model.symphonie!.playbackSource).positions,doc.positions)
    }
}
