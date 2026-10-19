import XCTest
@testable import TrackerCore

final class SymMODInstrumentTests: XCTestCase {
    func be(_ n: Int) -> Data {var v = UInt32(truncatingIfNeeded:n).bigEndian; return withUnsafeBytes(of:&v) {Data($0)}}
    func block(_ id: Int,_ data: Data) -> Data {be(id)+be(data.count)+data}
    func record() -> Data {
        var d = Data(repeating:0,count:256)
        d.replaceSubrange(0..<5,with:Data("Alpha".utf8)); d[134] = 75; d[140] = 8; d[142] = 0xAA
        d[150] = 71; d[151] = 82; d[152] = 93; d[153] = 104
        d[220] = 197; return d
    }
    func pack(_ data: Data) -> Data {
        var p = Data([80,65,67,75,255,255]); p.append(be(data.count))
        for start in stride(from:0,to:data.count,by:255) {
            let n = min(255,data.count-start); p.append(contentsOf:[0,UInt8(n)]); p.append(data.subdata(in:start..<start+n))
        }
        p.append(255); return p
    }
    func fixture(_ record: Data,packed: Bool = false) -> Data {
        var d = Data("SymM".utf8)
        for x in [1,-1,1,-2,1,-5,4] {d.append(be(x))}
        let instruments = record+record
        d.append(block(-14,packed ? pack(instruments) : instruments))
        d.append(block(-13,Data([0,24,100,0]))); d.append(block(-20,Data([4,5,6]))); d.append(be(-12))
        return d
    }
    func testOnlyChosenHeaderFieldsChangeAndFlagsArePreserved() throws {
        let source = fixture(record()), doc = try SymMODDocument(source), ins = try doc.instrument(0)
        XCTAssertTrue(ins.canEdit); XCTAssertTrue(ins.bypassDSP)
        var edit = ins.settings; edit.volume = 40; edit.finetune = -128; edit.transpose = 127; edit.ignorePositionTranspose = true
        let output = try doc.replacingInstrument(0,with:edit), changed = try SymMODDocument(output)
        let result = try changed.instrument(0)
        XCTAssertEqual(result.volume,40); XCTAssertEqual(result.finetune,-128); XCTAssertEqual(result.transpose,127)
        XCTAssertTrue(result.ignorePositionTranspose); XCTAssertTrue(result.bypassDSP)
        XCTAssertEqual(result.bytes[142],0xAB)
        XCTAssertEqual(try changed.instrument(1).bytes,try doc.instrument(1).bytes)
        XCTAssertEqual(changed.events,doc.events)
        XCTAssertEqual(zip(source,output).filter {$0 != $1}.count,4)
        for i in 0..<256 where ![134,138,139,142].contains(i) {XCTAssertEqual(result.bytes[i],ins.bytes[i])}
    }
    func testNoOpAndPackedTablePreserveUnrelatedBytes() throws {
        let source = fixture(record(),packed:true), doc = try SymMODDocument(source)
        let ins = try doc.instrument(1)
        XCTAssertEqual(try doc.replacingInstrument(1,with:ins.settings),source)
        var edit = ins.settings; edit.volume = 100
        let output = try doc.replacingInstrument(1,with:edit), changed = try SymMODDocument(output)
        XCTAssertEqual(try changed.instrument(0).bytes,try doc.instrument(0).bytes)
        XCTAssertEqual(try changed.instrument(1).volume,100)
        XCTAssertEqual(output.suffix(27),source.suffix(27)); XCTAssertEqual(changed.events,doc.events)
    }
    func testFineLoopsBoundsAndDisablingWithoutRewritingDormantValues() throws {
        let doc = try SymMODDocument(fixture(record())), ins = try doc.instrument(0)
        var edit = ins.settings
        edit.loop = SymMODLoop(enabled:true,start:Int(25.5*65536),length:Int(50.25*65536))
        let enabled = try SymMODDocument(doc.replacingInstrument(0,with:edit)), looped = try enabled.instrument(0)
        XCTAssertTrue(looped.fineLoops); XCTAssertEqual(looped.type,4); XCTAssertEqual(looped.loop,edit.loop)
        XCTAssertEqual(looped.bytes[140],24); XCTAssertEqual(looped.bytes[142],ins.bytes[142])
        var disable = looped.settings; disable.loop = SymMODLoop(enabled:false,start:0,length:0)
        let output = try SymMODDocument(enabled.replacingInstrument(0,with:disable)), disabled = try output.instrument(0)
        XCTAssertEqual(disabled.type,0)
        for i in 0..<256 where i != 128 {XCTAssertEqual(disabled.bytes[i],looped.bytes[i])}
        for loop in [SymMODLoop(enabled:true,start:-1,length:1),SymMODLoop(enabled:true,start:0,length:0),SymMODLoop(enabled:true,start:100*65536,length:1),SymMODLoop(enabled:true,start:0,length:Int.max)] {
            edit.loop = loop; XCTAssertThrowsError(try doc.replacingInstrument(0,with:edit))
        }
    }
    func testProtectedInstrumentsAndInvalidControlsAreRejected() throws {
        for field in [(128,UInt8(8)),(132,1),(132,2),(132,3),(134,255),(0,0)] {
            var r = record(); r[field.0] = field.1
            let d = try SymMODDocument(fixture(r)); XCTAssertFalse(try d.instrument(0).canEdit)
            XCTAssertThrowsError(try d.replacingInstrument(0,with:d.instrument(0).settings))
        }
        var virtual = record(); virtual.replaceSubrange(0..<4,with:Data("ViRT".utf8))
        let v = try SymMODDocument(fixture(virtual)); XCTAssertFalse(try v.instrument(0).canEdit)
        let d = try SymMODDocument(fixture(record()))
        for value in [-1,200,Int.max] {var edit = try d.instrument(0).settings; edit.volume = value; XCTAssertThrowsError(try d.replacingInstrument(0,with:edit))}
        var edit = try d.instrument(0).settings; edit.transpose = 128; XCTAssertThrowsError(try d.replacingInstrument(0,with:edit))
        XCTAssertThrowsError(try d.instrument(2))
        let unknown = try SymMODDocument(fixture(record())+Data([5,6,7,8]))
        XCTAssertThrowsError(try unknown.replacingInstrument(0,with:edit))
    }
    func real() throws -> Module {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Fixture SymMOD requise")}
        return try SymphonieDecoder.decode(Data(contentsOf:URL(fileURLWithPath:path)),title:"TheSecret")
    }
    func rms(_ a: Data,_ b: Data? = nil) -> Double {
        let x = a.dropFirst(44).withUnsafeBytes {Array($0.bindMemory(to:Int16.self))}
        let y = b?.dropFirst(44).withUnsafeBytes {Array($0.bindMemory(to:Int16.self))} ?? Array(repeating:0,count:x.count)
        return sqrt(zip(x,y).reduce(0) {let delta = Double($1.0)-Double($1.1); return $0+delta*delta}/Double(x.count))
    }
    func testRealInstrumentVolumeZeroMeansDefaultAndEditsReachAudio() throws {
        let module = try real(), doc = try SymMODDocument(module.symphonie!.source), ins = try doc.instrument(2)
        XCTAssertTrue(ins.canEdit); XCTAssertEqual(ins.volume,0)
        let muted = Set(0..<module.channelCount).subtracting([12])
        let before = try SymphonieDecoder.render(module,muted:muted,maximumDuration:2).wav
        var edit = ins.settings; edit.volume = 100
        let defaultVolume = try SymphonieDecoder.replacingInstrument(in:module,index:2,edit:edit)
        XCTAssertLessThan(rms(before,try SymphonieDecoder.render(defaultVolume,muted:muted,maximumDuration:2).wav),4)
        edit.volume = 50
        let changed = try SymphonieDecoder.replacingInstrument(in:module,index:2,edit:edit)
        let after = try SymphonieDecoder.render(changed,muted:muted,maximumDuration:2).wav
        XCTAssertGreaterThan(rms(before,after),8)
        // Compare decoded output, including its DSP/ramping; no fixed final gain ratio is promised.
        XCTAssertLessThan(rms(after)/rms(before),0.95)
        XCTAssertEqual(changed.symphonie?.source,module.symphonie?.source); XCTAssertEqual(changed.patterns,module.patterns)
        let saved = try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(changed))
        XCTAssertEqual(try SymphonieDecoder.refreshed(saved),changed)
        let read = try SymphonieDecoder.decode(changed.symphonie!.playbackSource,title:changed.title)
        XCTAssertLessThan(rms(after,try SymphonieDecoder.render(read,muted:muted,maximumDuration:2).wav),4)
    }
    func testRealTuningAndLoopSurviveNativeReopening() throws {
        let module = try real(), d = try SymMODDocument(module.symphonie!.source)
        var edit = try d.instrument(2).settings; edit.transpose = 12; edit.finetune = -64
        edit.loop = SymMODLoop(enabled:true,start:10*65536,length:40*65536)
        let changed = try SymphonieDecoder.replacingInstrument(in:module,index:2,edit:edit)
        let result = try SymMODDocument(changed.symphonie!.playbackSource), ins = try result.instrument(2)
        XCTAssertEqual(ins.transpose,12); XCTAssertEqual(ins.finetune,-64); XCTAssertEqual(ins.loop,edit.loop)
        let before = try SymphonieDecoder.render(module,maximumDuration:2).wav, after = try SymphonieDecoder.render(changed,maximumDuration:2).wav
        XCTAssertGreaterThan(rms(before,after),8)
        let fresh = try SymphonieDecoder.decode(changed.symphonie!.playbackSource,title:module.title)
        XCTAssertLessThan(rms(after,try SymphonieDecoder.render(fresh,maximumDuration:2).wav),4)
    }
}
