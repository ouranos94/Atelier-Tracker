import XCTest
@testable import TrackerCore

final class CompositionCycleTests: XCTestCase {
    func base() throws -> Module {try SymMODComposer.create(title:"Notes",channels:4,rows:32)}
    func testPianoMoveResizeDeleteAndProtectedCollision() throws {
        let m = try base(),entry = try XCTUnwrap(m.symphonie?.orderSource?.first ?? nil),doc = try SymMODDocument(m.symphonie!.source)
        let first = try PianoEditing.edits(doc,entry:entry,channel:0,replacing:nil,row:2,pitch:36,duration:4,instrument:0,volume:75)
        let written = try SymMODDocument(doc.replacingEvents(first)),note = try XCTUnwrap(PianoEditing.notes(written,entry:entry,channel:0).first)
        XCTAssertEqual(note.duration,4);XCTAssertTrue(note.explicitStop);XCTAssertEqual(note.volume,75)
        let moved = try SymMODDocument(written.replacingEvents(PianoEditing.edits(written,entry:entry,channel:0,replacing:note,row:3,pitch:40,duration:7,instrument:0,volume:70)))
        let next = try XCTUnwrap(PianoEditing.notes(moved,entry:entry,channel:0).first)
        XCTAssertEqual(next.row,3);XCTAssertEqual(next.duration,7);XCTAssertEqual(next.pitch,40)
        XCTAssertThrowsError(try PianoEditing.edits(moved,entry:entry,channel:0,replacing:nil,row:4,pitch:50,duration:1,instrument:0,volume:50))
        XCTAssertThrowsError(try PianoEditing.edits(moved,entry:entry,channel:0,replacing:nil,row:31,pitch:50,duration:1,instrument:0,volume:50))
        let deleted = try SymMODDocument(moved.replacingEvents(PianoEditing.deleting(moved,entry:entry,channel:0,note:next)))
        XCTAssertEqual(deleted.events,doc.events)
        var bytes = doc.events;bytes.replaceSubrange(2*4*4..<2*4*4+4,with:SymMODEvent(command:20,parameter:9).bytes)
        let protected = try SymMODDocument(doc.replacingEventPayload(bytes))
        XCTAssertThrowsError(try PianoEditing.edits(protected,entry:entry,channel:0,replacing:nil,row:2,pitch:36,duration:4,instrument:0,volume:75))
    }
    func testExplicitStopActuallyStopsNativeVoice() throws {
        var m = try base()
        let pcm = SymPCM(samples:(0..<20000).map {Int16(sin(Double($0)*0.1)*24000)})
        m = try SymphonieDecoder.replacingPCM(in:m,index:0,pcm:pcm,name:"Tone")
        var settings = try SymMODDocument(m.symphonie!.playbackSource).instrument(0).settings
        settings.loop = SymMODLoop(enabled:true,start:0,length:6553600)
        m = try SymphonieDecoder.replacingInstrument(in:m,index:0,edit:settings)
        let doc = try SymMODDocument(m.symphonie!.playbackSource),entry = try XCTUnwrap(m.symphonie!.orderSource![0])
        m = try SymphonieDecoder.replacingEvents(in:m,edits:PianoEditing.edits(doc,entry:entry,channel:0,replacing:nil,row:0,pitch:36,duration:1,instrument:0,volume:100))
        let wav = try SymphonieDecoder.render(m,maximumDuration:0.6).wav
        let values = stride(from:44,to:wav.count,by:2).map {Double(Int16(bitPattern:UInt16(wav[$0])|UInt16(wav[$0+1])<<8))}
        XCTAssertGreaterThan(values.prefix(5000).map(abs).max() ?? 0,100)
        XCTAssertLessThan(values.suffix(5000).map(abs).max() ?? 1000,10)
        let voice = try SymLiveVoice(m);try voice.noteOn(instrument:0,pitch:36,velocity:100)
        var l = [Float](repeating:0,count:2048),r = l
        l.withUnsafeMutableBufferPointer {left in r.withUnsafeMutableBufferPointer {right in voice.render(count:2048,left:left.baseAddress!,right:right.baseAddress!)}}
        XCTAssertGreaterThan(l.map(abs).max() ?? 0,0.01)
        voice.noteOff()
    }
    func testMIDIParserRunningStatusRealtimeAndQuantizedAtomicTake() throws {
        var parser = MIDIByteParser()
        XCTAssertEqual(parser.feed([0x91,60,0xf8]),[])
        XCTAssertEqual(parser.feed([100,62,0,0x81,60,64]),[MIDINoteEvent(channel:2,note:60,velocity:100),MIDINoteEvent(channel:2,note:62,velocity:0),MIDINoteEvent(channel:2,note:60,velocity:0)])
        XCTAssertEqual(parser.feed([0xf0,1,2,3,0xf7,60,100]),[])
        XCTAssertEqual(MIDIEditing.quantize(5.2,step:4),4);XCTAssertEqual(MIDIEditing.quantize(6.1,step:4),8)
        let m = try base(),doc = try SymMODDocument(m.symphonie!.source),entry = try XCTUnwrap(m.symphonie!.orderSource![0])
        let notes = [MIDIGridNote(row:0,end:2,pitch:36,velocity:127),MIDIGridNote(row:4,end:6,pitch:38,velocity:64)]
        let output = try SymMODDocument(doc.replacingEvents(MIDIEditing.edits(doc,entry:entry,channel:0,instrument:0,notes:notes)))
        XCTAssertEqual(try PianoEditing.notes(output,entry:entry,channel:0).map(\.volume),[100,50])
        XCTAssertThrowsError(try MIDIEditing.edits(output,entry:entry,channel:0,instrument:0,notes:notes))
        XCTAssertEqual(doc.events,try SymMODDocument(m.symphonie!.source).events)
    }
    func testLibraryDedupPersistenceSearchAndManifestValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store = SampleLibraryStore(directory:root),pcm = SymPCM(samples:[0,1000,-1000,0])
        var entries = try store.adding(pcm,name:"Mélodie")
        XCTAssertEqual(try store.adding(pcm,name:"Same").count,1)
        XCTAssertTrue(entries[0].matches("MELODIE"));entries[0].favorite = true;try store.save(entries)
        XCTAssertEqual(try store.load(),entries)
        XCTAssertEqual(try SymPCM.decode(Data(contentsOf:store.url(entries[0]))).samples,pcm.samples)
        let bad = Data("[{\"id\":\"../../unsafe\",\"name\":\"x\",\"favorite\":false,\"frames\":1}]".utf8)
        try bad.write(to:root.appendingPathComponent("library.json"));XCTAssertThrowsError(try store.load())
    }
    func testAdjacentMIDIAndPCMContainerBounds() throws {
        let m = try base(),doc = try SymMODDocument(m.symphonie!.source),entry = try XCTUnwrap(m.symphonie!.orderSource![0])
        let notes = [MIDIGridNote(row:0,end:2,pitch:36,velocity:100),MIDIGridNote(row:2,end:4,pitch:40,velocity:90)]
        let output = try SymMODDocument(doc.replacingEvents(MIDIEditing.edits(doc,entry:entry,channel:0,instrument:0,notes:notes)))
        XCTAssertEqual(try PianoEditing.notes(output,entry:entry,channel:0).map(\.duration),[2,2])
        let pcm = SymPCM(samples:[0,100,-100,0]),wav = try pcm.wav()
        var padded = wav;padded.append(contentsOf:[0,0,0,0,255,255,255,255,0])
        XCTAssertEqual(try SymPCM.decode(padded).samples,pcm.samples)
        XCTAssertThrowsError(try SymPCM.decode(Data(wav.dropLast(2))))
        for id: Int32 in [-17,-18] {
            let size = id == -17 ? 8 : 4096
            let bytes = Data(repeating:1,count:size)
            let store = try SymMODStorage(doc.source)
            var record = Data(repeating:0,count:256);record[0] = 83;record[134] = 100
            var bank = doc.instrumentData;bank.replaceSubrange(0..<256,with:record)
            let slot = try XCTUnwrap(store.chunks.firstIndex {$0.id == -12})
            let changed = try SymMODDocument(store.replacing([try store.index(-14):SymMODStorage.block(-14,bank),slot:SymMODStorage.block(id,bytes)]))
            let decoded = try XCTUnwrap(changed.pcm(0))
            if id == -17 {XCTAssertEqual(Array(decoded.samples.prefix(3)),[256,512,768])}
            else {XCTAssertEqual(decoded.samples.count,4096);XCTAssertEqual(decoded.samples[0],256);XCTAssertEqual(decoded.samples[1],256)}
        }
    }

}
