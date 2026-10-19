import XCTest
@testable import TrackerCore

final class SymMODArrangementTests: XCTestCase {
    func be(_ n: Int) -> Data {var v = UInt32(truncatingIfNeeded:n).bigEndian; return withUnsafeBytes(of:&v) {Data($0)}}
    func word(_ n: Int,_ d: inout Data,_ o: Int) {let v = UInt16(truncatingIfNeeded:n); d[o] = UInt8(v>>8); d[o+1] = UInt8(v&255)}
    func block(_ id: Int,_ d: Data) -> Data {be(id)+be(d.count)+d}
    func pack(_ d: Data) -> Data {SymMODInstrumentTests().pack(d)}
    func position(_ pattern: Int = 0) -> Data {
        var d = Data(repeating:71,count:32)
        for (o,n) in [(4,1),(8,pattern),(10,0),(12,8),(14,6),(16,0)] {word(n,&d,o)}
        return d
    }
    func sequence(start: Int = 0,length: Int = 2,info: Int = 0) -> Data {
        var d = Data(repeating:82,count:16)
        for (o,n) in [(0,start),(2,length),(4,3),(6,info),(8,0)] {word(n,&d,o)}
        return d
    }
    func fixture(packed: Bool = false,seq: Data? = nil) -> Data {
        var source = Data("SymM".utf8)
        for v in [1,-1,1,-2,8,-5,4] {source.append(be(v))}
        let positions = position()+position(1)+position()
        let sequences = seq ?? sequence()+sequence(info:1)+sequence(info:-1)+sequence()
        source.append(block(-10,packed ? pack(positions) : positions))
        source.append(block(-14,Data(repeating:0,count:256)))
        source.append(block(-15,packed ? pack(sequences) : sequences))
        source.append(block(-13,Data(repeating:0,count:64)))
        source.append(block(-20,Data([1,2,3,4,5]))); source.append(be(-12))
        return source
    }
    func testPositionFieldsPreserveOpaqueBytesAndOtherChunks() throws {
        let source = fixture(), d = try SymMODDocument(source)
        var p = d.positions[1]; p.start = 2; p.length = 4; p.speed = 3; p.repeats = 2; p.transpose = -12; p.pattern = 0
        let out = try d.replacingPosition(1,with:p), result = try SymMODDocument(out)
        XCTAssertEqual(result.positions[1],p); XCTAssertEqual(result.positions[0],d.positions[0]); XCTAssertEqual(result.sequences,d.sequences)
        XCTAssertEqual(result.events,d.events); XCTAssertEqual(result.instrumentData,d.instrumentData)
        let range = try XCTUnwrap(d.positionRange), allowed = [4,5,8,9,10,11,12,13,14,15,16,17].map {range.lowerBound+8+32+$0}
        XCTAssertEqual(out.count,source.count)
        for i in source.indices where !allowed.contains(i) {XCTAssertEqual(out[i],source[i])}
        XCTAssertEqual(try d.replacingPosition(1,with:d.positions[1]),source)
    }
    func testSequencesRespectTerminatorAndKeepLoopsFlagsPadding() throws {
        let source = fixture(), d = try SymMODDocument(source)
        XCTAssertEqual(d.activeSequenceIndices,[0]); XCTAssertFalse(d.canEditSequence(1)); XCTAssertFalse(d.canEditSequence(2)); XCTAssertFalse(d.canEditSequence(3))
        var q = d.sequences[0]; q.start = 1; q.length = 1; q.transpose = 12
        let out = try d.replacingSequence(0,with:q), result = try SymMODDocument(out)
        XCTAssertEqual(result.sequences[0],q); XCTAssertEqual(result.positions,d.positions)
        XCTAssertEqual(result.sequenceData.subdata(in:4..<8),d.sequenceData.subdata(in:4..<8))
        XCTAssertEqual(result.sequenceData.suffix(6),d.sequenceData.suffix(6))
        let span = try XCTUnwrap(d.sequenceRange)
        for i in source.indices where ![0,1,2,3,8,9].map({span.lowerBound+8+$0}).contains(i) {XCTAssertEqual(out[i],source[i])}
        XCTAssertEqual(try d.replacingSequence(0,with:d.sequences[0]),source)
        q.loops += 1; XCTAssertThrowsError(try d.replacingSequence(0,with:q))
    }
    func testPackedTablesPreserveOtherPayloadsAndNoOpBytes() throws {
        let source = fixture(packed:true), d = try SymMODDocument(source)
        XCTAssertEqual(try d.replacingPosition(0,with:d.positions[0]),source)
        XCTAssertEqual(try d.replacingSequence(0,with:d.sequences[0]),source)
        var p = d.positions[0]; p.repeats = 2
        let a = try SymMODDocument(d.replacingPosition(0,with:p))
        XCTAssertFalse(a.positionsPacked); XCTAssertTrue(a.sequencesPacked)
        XCTAssertEqual(a.sequenceData,d.sequenceData); XCTAssertEqual(a.source.suffix(source.count-d.positionRange!.upperBound),source.suffix(source.count-d.positionRange!.upperBound))
        var q = a.sequences[0]; q.length = 1
        let b = try SymMODDocument(a.replacingSequence(0,with:q))
        XCTAssertFalse(b.sequencesPacked); XCTAssertEqual(b.positions,a.positions)
        XCTAssertEqual(b.events,d.events); XCTAssertEqual(b.instrumentData,d.instrumentData)
        XCTAssertEqual(b.source.suffix(85),source.suffix(85))
    }
    func testInvalidBoundsAndProtectedStructuresNeverMutate() throws {
        let d = try SymMODDocument(fixture())
        for field in 0..<6 {
            for value in [-1,Int.max] {
                var p = d.positions[0]
                switch field {case 0:p.pattern = value; case 1:p.start = value; case 2:p.length = value; case 3:p.speed = value; case 4:p.repeats = value; default:p.transpose = value == -1 ? -25 : value}
                XCTAssertThrowsError(try d.replacingPosition(0,with:p))
            }
        }
        var p = d.positions[0]; p.start = 7; p.length = 2; XCTAssertThrowsError(try d.replacingPosition(0,with:p))
        p = d.positions[0]; p.speed = 0; XCTAssertThrowsError(try d.replacingPosition(0,with:p))
        for index in [-1,3,Int.max] {XCTAssertThrowsError(try d.replacingPosition(index,with:p))}
        for (start,length) in [(Int.max,1),(-1,1),(0,0),(2,2),(0,Int.max)] {
            var q = d.sequences[0]; q.start = start; q.length = length
            XCTAssertThrowsError(try d.replacingSequence(0,with:q))
        }
        for i in [1,2,3,Int.max] {XCTAssertThrowsError(try d.replacingSequence(i,with:d.sequences[0]))}
        let unknown = try SymMODDocument(fixture()+Data([1,2,3,4]))
        XCTAssertThrowsError(try unknown.replacingPosition(0,with:d.positions[0])); XCTAssertThrowsError(try unknown.replacingSequence(0,with:d.sequences[0]))
    }
    func testExpansionLimitIsCheckedBeforeNativeDecoding() throws {
        var seq = Data(); for _ in 0..<300 {seq.append(sequence(length:1))}
        let d = try SymMODDocument(fixture(seq:seq))
        var p = d.positions[0]; p.repeats = 16
        XCTAssertThrowsError(try d.replacingPosition(0,with:p))
    }
    func testRealPositionSpeedRangeTransposeAndZeroRepeat() throws {
        let module = try SymMODDocumentTests().realModule(), d = try SymMODDocument(module.symphonie!.source)
        var q = d.sequences[0]; q.length = 1
        let first = try SymphonieDecoder.replacingSequence(in:module,index:0,edit:q)
        var p = d.positions[0]; p.repeats = 0
        let zero = try SymphonieDecoder.replacingPosition(in:first,index:0,edit:p)
        XCTAssertEqual(zero.orders,first.orders); XCTAssertEqual(zero.symphonie!.duration,first.symphonie!.duration,accuracy:0.001)
        p = d.positions[0]; p.speed = 6
        let slower = try SymphonieDecoder.replacingPosition(in:first,index:0,edit:p)
        XCTAssertGreaterThan(slower.symphonie!.duration,first.symphonie!.duration)
        p = d.positions[0]; p.start = 1; p.length -= 1
        let cropped = try SymphonieDecoder.replacingPosition(in:first,index:0,edit:p)
        XCTAssertEqual(cropped.rowCount(pattern:cropped.orders[0]),p.length)
        p = d.positions[0]; p.transpose += 1
        let transposed = try SymphonieDecoder.replacingPosition(in:first,index:0,edit:p)
        XCTAssertNotEqual(transposed.patterns,first.patterns)
        XCTAssertGreaterThan(SymMODDocumentTests().rmsDifference(try SymphonieDecoder.render(first,maximumDuration:1).wav,try SymphonieDecoder.render(transposed,maximumDuration:1).wav),8)
    }
    func testRealArrangementRebuildsDurationOrdersAndSavedAudio() throws {
        let module = try SymMODDocumentTests().realModule(), source = module.symphonie!.source, d = try SymMODDocument(source)
        XCTAssertEqual(d.activeSequenceIndices,[0]); XCTAssertTrue(d.canEditPosition(0))
        var p = d.positions[0]; p.repeats = 2
        let repeated = try SymphonieDecoder.replacingPosition(in:module,index:0,edit:p)
        XCTAssertEqual(repeated.orders.count,module.orders.count+1)
        XCTAssertGreaterThan(repeated.symphonie!.duration,module.symphonie!.duration)
        XCTAssertEqual(repeated.symphonie!.source,source)
        let restored = try SymphonieDecoder.replacingPosition(in:repeated,index:0,edit:d.positions[0])
        XCTAssertNil(restored.symphonie!.editedSource)
        var q = d.sequences[0]; q.start = 1; q.length = 1; q.transpose = 1
        let changed = try SymphonieDecoder.replacingSequence(in:module,index:0,edit:q)
        XCTAssertEqual(changed.orders.count,1); XCTAssertLessThan(changed.symphonie!.duration,module.symphonie!.duration)
        let saved = try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(changed))
        XCTAssertEqual(try SymphonieDecoder.refreshed(saved),changed)
        let redecoded = try SymphonieDecoder.decode(changed.symphonie!.playbackSource,title:changed.title)
        XCTAssertEqual(redecoded.patterns,changed.patterns)
        let originalAudio = try SymphonieDecoder.render(module,maximumDuration:1).wav
        let changedAudio = try SymphonieDecoder.render(changed,maximumDuration:1).wav
        XCTAssertGreaterThan(SymMODDocumentTests().rmsDifference(originalAudio,changedAudio),8)
        XCTAssertLessThan(SymMODDocumentTests().rmsDifference(changedAudio,try SymphonieDecoder.render(redecoded,maximumDuration:1).wav),4)
    }
}
