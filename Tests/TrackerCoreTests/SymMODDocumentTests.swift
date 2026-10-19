import XCTest
@testable import TrackerCore

final class SymMODDocumentTests: XCTestCase {
    func be(_ n: Int) -> Data {var v = UInt32(truncatingIfNeeded:n).bigEndian; return withUnsafeBytes(of:&v) {Data($0)}}
    func block(_ id: Int,_ data: Data) -> Data {be(id)+be(data.count)+data}
    func fixture(events: Data? = nil,packed: Bool = false) -> Data {
        let raw = events ?? Data([0,24,80,0,24,1,42,1,0,255,0,0,0,36,100,1])
        let payload = packed ? Data([80,65,67,75,255,255])+be(raw.count)+Data([0,UInt8(raw.count)])+raw+Data([255]) : raw
        var result = Data("SymM".utf8)
        for n in [1,-1,2,-2,2,-5,4] {result.append(be(n))}
        let chunks: [Data] = [block(-14,Data(repeating:0,count:512)),block(-10,Data(repeating:0,count:32)),block(-13,payload),block(-15,Data(repeating:0,count:16)),block(-20,Data([9,8,7])),be(-12)]
        for chunk in chunks {result.append(chunk)}
        return result
    }
    func testUnchangedIsByteExactAndSourceCoordinates() throws {
        let input = fixture(), d = try SymMODDocument(input)
        XCTAssertEqual(d.encoded,input); XCTAssertEqual(d.patternCount,1); XCTAssertEqual(d.rows,2); XCTAssertEqual(d.channels,2)
        XCTAssertEqual(try d.event(pattern:0,row:1,channel:1).pitch,36)
        XCTAssertEqual(d.positions.count,1); XCTAssertEqual(d.sequences.count,1)
        XCTAssertThrowsError(try d.event(pattern:1,row:0,channel:0))
    }
    func testUncompressedEditChangesOnlyRequestedBytes() throws {
        let input = fixture(), d = try SymMODDocument(input)
        var e = try d.event(pattern:0,row:0,channel:0); e.pitch = 25; e.parameter = 60
        let output = try d.replacingNote(pattern:0,row:0,channel:0,with:e)
        XCTAssertEqual(output.count,input.count)
        XCTAssertEqual(zip(input,output).filter {$0 != $1}.count,2)
        let changed = try SymMODDocument(output)
        XCTAssertEqual(try changed.event(pattern:0,row:0,channel:0),e)
        XCTAssertEqual(try changed.event(pattern:0,row:0,channel:1),try d.event(pattern:0,row:0,channel:1))
        XCTAssertThrowsError(try d.replacingNote(pattern:0,row:0,channel:1,with:SymMODEvent()))
        XCTAssertThrowsError(try d.replacingNote(pattern:0,row:0,channel:0,with:SymMODEvent(parameter:101)))
        XCTAssertThrowsError(try d.replacingNote(pattern:0,row:0,channel:0,with:SymMODEvent(instrument:2)))
    }
    func testPackedEditPreservesOtherChunksAndNoOpPreservesCompression() throws {
        let input = fixture(packed:true), d = try SymMODDocument(input)
        let original = try d.event(pattern:0,row:1,channel:1)
        XCTAssertEqual(try d.replacingNote(pattern:0,row:1,channel:1,with:original),input)
        var note = original; note.pitch = 40
        let output = try d.replacingNote(pattern:0,row:1,channel:1,with:note)
        let changed = try SymMODDocument(output)
        XCTAssertEqual(try changed.event(pattern:0,row:1,channel:1),note)
        XCTAssertEqual(output.suffix(39),input.suffix(39))
        XCTAssertEqual(output.prefix(580),input.prefix(580))
    }
    func testAllPACKCommandsAndMalformedInput() throws {
        let prefix = Data([80,65,67,75,255,255])
        let payload = prefix+be(22)+Data([0,2,7,8,1,2,1,2,3,4,2,5,6,7,8,3,4,255])
        let decoded = try SymMODDocument.unpack(payload)
        XCTAssertEqual(decoded,Data([7,8,1,2,3,4,1,2,3,4,5,6,7,8,5,6,7,8,0,0,0,0]))
        var invalids: [Data] = [prefix]
        invalids.append(prefix+be(1)+Data([0,4,1,2,3,4]))
        invalids.append(prefix+be(10)+Data([255]))
        invalids.append(prefix+be(100_000_000)+Data([1,1,0,0,0,0]))
        invalids.append(prefix+be(1)+Data([4,1]))
        for invalid in invalids {XCTAssertThrowsError(try SymMODDocument.unpack(invalid))}
        for data in [Data(),fixture().dropLast(5),Data("SymM".utf8)+Data(repeating:0,count:12)] {XCTAssertThrowsError(try SymMODDocument(Data(data)))}
    }
    func testUnknownTailIsRetainedButNotEditable() throws {
        let input = fixture()+Data([0,1,2,3,4,5]), d = try SymMODDocument(input)
        XCTAssertEqual(d.encoded,input); XCTAssertFalse(d.canEdit)
        XCTAssertThrowsError(try d.replacingNote(pattern:0,row:0,channel:0,with:SymMODEvent()))
    }
    func rmsDifference(_ a: Data,_ b: Data) -> Double {
        XCTAssertEqual(a.count,b.count)
        let x = a.dropFirst(44).withUnsafeBytes {Array($0.bindMemory(to:Int16.self))}
        let y = b.dropFirst(44).withUnsafeBytes {Array($0.bindMemory(to:Int16.self))}
        return sqrt(zip(x,y).reduce(0.0) {let delta = Double($1.0)-Double($1.1); return $0+delta*delta}/Double(max(1,min(x.count,y.count))))
    }
    func testRealCompressedPatternIsReadableAfterEditing() throws {
        let module = try realModule(), original = module.symphonie!.source
        let doc = try SymMODDocument(original)
        let range = try XCTUnwrap(original.range(of:doc.events))
        var packed = Data([80,65,67,75,255,255]); packed.append(be(doc.events.count))
        for start in stride(from:0,to:doc.events.count,by:255) {
            let count = min(255,doc.events.count-start)
            packed.append(contentsOf:[0,UInt8(count)]); packed.append(doc.events.subdata(in:start..<start+count))
        }
        packed.append(255)
        var source = original; source.replaceSubrange(range.lowerBound-4..<range.upperBound,with:be(packed.count)+packed)
        let decoded = try SymphonieDecoder.decode(source,title:module.title)
        XCTAssertEqual(decoded.patterns,module.patterns)
        let archive = try SymMODDocument(source)
        var target: (Int,Int)?
        for r in 0..<archive.rows {for c in 0..<archive.channels {if target == nil, try archive.event(pattern:0,row:r,channel:c).isEditableNote {target = (r,c)}}}
        let (r,c) = try XCTUnwrap(target)
        let changed = try SymphonieDecoder.replacingNote(in:decoded,pattern:0,row:r,channel:c,event:SymMODEvent(pitch:35,parameter:80))
        XCTAssertEqual(changed.symphonie?.source,source)
        let result = try SymMODDocument(changed.symphonie!.playbackSource)
        XCTAssertEqual(try result.event(pattern:0,row:r,channel:c).pitch,35)
        let reopened = try SymphonieDecoder.decode(result.encoded,title:module.title)
        XCTAssertEqual(changed.patterns,reopened.patterns)
    }
    func realModule() throws -> Module {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Fixture SymMOD requise")}
        return try SymphonieDecoder.decode(Data(contentsOf:URL(fileURLWithPath:path)),title:"TheSecret")
    }
    func testRealSourceEditReachesDecoderAndAudioAndProject() throws {
        var module = try realModule(); module.mix = MixConfiguration(channels:16)
        let source = module.symphonie!.source, d = try SymMODDocument(source)
        XCTAssertEqual(d.patternCount,128); XCTAssertEqual(d.encoded,source)
        let pos = d.positions[d.sequences[0].start]
        var location: (Int,Int,SymMODEvent)?
        for r in pos.start..<min(d.rows,pos.start+8) {for c in 0..<d.channels {
            let e = try d.event(pattern:pos.pattern,row:r,channel:c)
            if location == nil && e.isEditableNote && e.pitch >= 0 && e.parameter > 0 {location = (r,c,e)}
        }}
        let (r,c,original) = try XCTUnwrap(location)
        var edited = original; edited.pitch = original.pitch == 84 ? 83 : original.pitch+1
        let changed = try SymphonieDecoder.replacingNote(in:module,pattern:pos.pattern,row:r,channel:c,event:edited)
        XCTAssertEqual(changed.symphonie?.source,source); XCTAssertNotNil(changed.symphonie?.editedSource)
        XCTAssertNotEqual(changed.patterns,module.patterns); XCTAssertEqual(changed.mix,module.mix)
        let before = try SymphonieDecoder.render(module,maximumDuration:2), after = try SymphonieDecoder.render(changed,maximumDuration:2)
        XCTAssertGreaterThan(rmsDifference(before.wav,after.wav),8)
        let stored = try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(changed))
        let reopened = try SymphonieDecoder.refreshed(stored)
        XCTAssertEqual(reopened,changed)
        let exported = try SymphonieDecoder.decode(changed.symphonie!.playbackSource,title:changed.title)
        XCTAssertEqual(exported.patterns,changed.patterns)
        XCTAssertLessThan(rmsDifference(try SymphonieDecoder.render(exported,maximumDuration:2).wav,after.wav),4)
        let restored = try SymphonieDecoder.replacingNote(in:changed,pattern:pos.pattern,row:r,channel:c,event:original)
        XCTAssertNil(restored.symphonie?.editedSource); XCTAssertEqual(restored.symphonie?.source,source)
    }
}
