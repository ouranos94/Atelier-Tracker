import XCTest
@testable import TrackerCore

final class SampleEditingTests: XCTestCase {
    func sample() -> Sample {
        var s = Sample(); s.data = (0..<16).map {Int8($0*4-32)}; s.loopStart = 4; s.loopLength = 8; return s
    }
    func testTrimIntersectsAndOffsetsLoop() throws {
        var s = sample()
        let range = try SampleEditing.apply(.trim,to:&s,region:SampleRegion(start:6,end:14))
        XCTAssertEqual(s.data,Array(sample().data[6..<14])); XCTAssertEqual(s.loopStart,0); XCTAssertEqual(s.loopLength,6)
        XCTAssertEqual(range,SampleRegion(start:0,end:8))
        s = sample(); _ = try SampleEditing.apply(.trim,to:&s,region:SampleRegion(start:12,end:16))
        XCTAssertEqual(s.loopLength,0)
    }
    func testDeletionRemapsLoopBeforeInsideAndAcrossSelection() throws {
        for (region,start,length) in [(SampleRegion(start:0,end:2),2,8),(.init(start:6,end:8),4,6),(.init(start:2,end:14),0,0),(.init(start:12,end:16),4,8)] {
            var s = sample()
            XCTAssertNil(try SampleEditing.apply(.delete,to:&s,region:region))
            XCTAssertEqual(s.loopStart,start); XCTAssertEqual(s.loopLength,length)
            XCTAssertEqual(s.data.count,16-region.count)
            XCTAssertLessThanOrEqual(s.loopStart+s.loopLength,s.data.count)
        }
        var s = sample(); _ = try SampleEditing.apply(.delete,to:&s,region:.init(start:0,end:16))
        XCTAssertTrue(s.data.isEmpty); XCTAssertEqual(s.loopLength,0)
    }
    func testProcessingDoesNotWrapAtSignedExtremesAndLeavesOutsideUntouched() throws {
        var s = Sample(); s.data = [10,20,-128,127,30,40]
        _ = try SampleEditing.apply(.invert,to:&s,region:.init(start:2,end:4))
        XCTAssertEqual(s.data,[10,20,127,-127,30,40])
        s.data = [0,0,-128,64,0,0]
        _ = try SampleEditing.apply(.normalize,to:&s,region:.init(start:2,end:4))
        XCTAssertEqual(s.data,[0,0,-127,64,0,0])
        s.data = [10,20,30,40,50,60]
        _ = try SampleEditing.apply(.reverse,to:&s,region:.init(start:2,end:6))
        XCTAssertEqual(s.data,[10,20,60,50,40,30])
    }
    func testFadeEndpointsAndSilence() throws {
        var s = Sample(); s.data = [100,100,100,100]
        _ = try SampleEditing.apply(.fadeIn,to:&s,region:.init(start:0,end:4)); XCTAssertEqual(s.data,[0,33,67,100])
        s.data = [-100,-100,-100,-100]
        _ = try SampleEditing.apply(.fadeOut,to:&s,region:.init(start:0,end:4)); XCTAssertEqual(s.data,[-100,-67,-33,0])
        s.data = [0,0]; _ = try SampleEditing.apply(.normalize,to:&s,region:.init(start:0,end:2)); XCTAssertEqual(s.data,[0,0])
    }
    func testInvalidRegionsAndLoopAreRejectedWithoutMutation() throws {
        var s = sample(); let before = s
        for region in [SampleRegion(start:0,end:0),.init(start:3,end:8),.init(start:0,end:18),.init(start:Int.min,end:Int.max)] {
            XCTAssertThrowsError(try SampleEditing.apply(.trim,to:&s,region:region)); XCTAssertEqual(s,before)
        }
        XCTAssertThrowsError(try SampleEditing.setLoop(&s,region:.init(start:0,end:2))); XCTAssertEqual(s,before)
        try SampleEditing.setLoop(&s,region:.init(start:2,end:16)); XCTAssertEqual(s.loopLength,14)
        try SampleEditing.setLoop(&s,region:nil); XCTAssertEqual(s.loopStart,0); XCTAssertEqual(s.loopLength,0)
    }
    func testEditedSamplesRoundTripThroughMOD() throws {
        for operation in SampleOperation.allCases {
            var m = Module(); m.samples[0] = sample()
            _ = try SampleEditing.apply(operation,to:&m.samples[0],region:.init(start:2,end:10))
            let restored = try MODCodec.decode(MODCodec.encode(m))
            XCTAssertEqual(restored.samples[0].data,m.samples[0].data)
            XCTAssertEqual(restored.samples[0].loopStart,m.samples[0].loopStart)
            XCTAssertEqual(restored.samples[0].loopLength > 2 ? restored.samples[0].loopLength : 0,m.samples[0].loopLength)
        }
    }
    func testKeyboardPreviewSustainsLoopAndKeepsAttack() throws {
        var s = Sample(); s.data = [64,64,16,16,32,32]; s.loopStart = 2; s.loopLength = 4; s.volume = 64
        let audio = try SampleEditing.previewWAV(s,region:.init(start:0,end:6),sustain:0.25)
        XCTAssertEqual((audio.count-44)/4,11025)
        XCTAssertEqual(audio[45],64)
        for i in stride(from:100,to:audio.count,by:4) {XCTAssertTrue([16,32].contains(Int(audio[i+1])))}
    }
    func testPreviewContainsOnlySelectedSamplesAtCorrectMODPitch() throws {
        var s = Sample(); s.data = [0,0,64,64,0,0]; s.volume = 64
        let region = SampleRegion(start:2,end:4)
        let c3 = try SampleEditing.previewWAV(s,region:region,period:214)
        let c2 = try SampleEditing.previewWAV(s,region:region,period:428)
        XCTAssertGreaterThan(c2.count,c3.count)
        for i in stride(from:44,to:c3.count,by:2) {XCTAssertEqual(c3[i],0); XCTAssertEqual(c3[i+1],64)}
        XCTAssertThrowsError(try SampleEditing.previewWAV(s,region:.init(start:0,end:0)))
    }
}
