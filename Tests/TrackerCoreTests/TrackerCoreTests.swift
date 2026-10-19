import XCTest
@testable import TrackerCore
final class TrackerCoreTests: XCTestCase {
    func testMetersMeasureActualSignalAndVolume() throws {
        var m = Module(); var sample = Sample()
        sample.data = Array(repeating:64,count:8); sample.volume = 32; sample.loopLength = 8
        m.samples[0] = sample; m.patterns[0][0] = Note(period:428,sample:1)
        m.patterns[0][4] = Note(effect:0xC,parameter:0)
        let result = try Renderer.render(m)
        XCTAssertEqual(result.meters[0].peaks,[0.25,0,0,0])
        XCTAssertEqual(result.meters[1].time,0.02,accuracy:0.0001)
        XCTAssertTrue(result.meters.filter({$0.time >= 0.12}).allSatisfy({$0.peaks.allSatisfy({$0 == 0})}))
        XCTAssertEqual(result.meters.count,384)
    }
    func testMutedMetersAreSilent() throws {
        let result = try Renderer.render(.demo(),muted:[0,2])
        XCTAssertTrue(result.meters.allSatisfy({$0.peaks[0] == 0 && $0.peaks[2] == 0}))
        XCTAssertTrue(result.meters.contains(where:{$0.peaks[1] > 0}))
        XCTAssertTrue(result.meters.allSatisfy({$0.peaks.count == 4 && $0.peaks.allSatisfy({$0 >= 0 && $0 <= 1})}))
    }
    func testShortTransientIsCapturedAndTrailingWindowIncluded() throws {
        var m = Module(); var sample = Sample(); sample.data = [127,0]
        m.samples[0] = sample; m.patterns[0][0] = Note(period:428,sample:1)
        m.patterns[0][4] = Note(effect:0xB,parameter:127); m.bpm = 137
        let result = try Renderer.render(m)
        XCTAssertGreaterThan(result.meters[0].peaks[0],0.99)
        XCTAssertTrue(result.meters.dropFirst().allSatisfy({$0.peaks[0] == 0}))
        XCTAssertLessThan(result.meters.last!.time,result.duration)
        XCTAssertLessThanOrEqual(result.duration-result.meters.last!.time,0.0201)
    }
    func testMODRoutingBeforeAudioDecoder() throws {
        let header = try MODCodec.encode(.demo()).prefix(1084)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/song.MOD"),prefix:Data()),.module)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/mod.song"),prefix:Data()),.module)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/song"),prefix:header),.module)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/sample.wav"),prefix:header),.module)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/sample.wav"),prefix:Data("RIFF".utf8)),.audio)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/song.atelier"),prefix:Data()),.project)
    }
    func testMODRoundTrip() throws {
        var m = Module.demo(); m.title = "Round trip"; m.patterns[0][48] = Note(period:320,sample:31,effect:0xC,parameter:40)
        let decoded = try MODCodec.decode(MODCodec.encode(m))
        XCTAssertEqual(decoded.title,m.title); XCTAssertEqual(decoded.samples[3].data,m.samples[3].data)
        XCTAssertEqual(decoded.patterns[0][48],m.patterns[0][48]); XCTAssertEqual(decoded.orders,[0])
    }
    func testRejectsTruncationAndInvalidOrders() throws {
        let encoded = try MODCodec.encode(.demo())
        XCTAssertThrowsError(try MODCodec.decode(encoded.prefix(1500)))
        var bad = encoded; bad[952] = 255
        XCTAssertThrowsError(try MODCodec.decode(bad))
        XCTAssertThrowsError(try MODCodec.decode(Data()))
    }
    func testStereoPCMAndDuration() throws {
        let result = try Renderer.render(.demo())
        XCTAssertEqual(String(data:result.wav.prefix(4),encoding:.ascii),"RIFF")
        XCTAssertEqual(result.markers.count,64); XCTAssertEqual(result.duration,7.68,accuracy:0.01)
        XCTAssertTrue(result.wav.dropFirst(44).contains(where:{$0 != 0}))
        XCTAssertTrue(result.warnings.isEmpty)
    }
    func testMuteProducesSilence() throws {
        let result = try Renderer.render(.demo(),muted:[0,1,2,3])
        XCTAssertTrue(result.wav.dropFirst(44).allSatisfy({$0 == 0}))
    }
    func testJumpLoopTerminates() throws {
        var m = Module(); m.patterns[0][0] = Note(effect:0xB,parameter:0)
        let result = try Renderer.render(m)
        XCTAssertEqual(result.markers.count,1); XCTAssertFalse(result.warnings.isEmpty)
    }
    func testTempoEffect() throws {
        var m = Module(); m.patterns[0][0] = Note(effect:0xF,parameter:250)
        XCTAssertEqual(try Renderer.render(m).duration,3.84,accuracy:0.01)
    }
    func testCustomTempoRoundTrip() throws {
        var m = Module.demo(); m.bpm = 140; m.speed = 4
        let decoded = try MODCodec.decode(MODCodec.encode(m))
        XCTAssertEqual(decoded.bpm,140); XCTAssertEqual(decoded.speed,4)
    }
    func testNoSilentTempoLossOnMODExport() {
        var m = Module.demo(); m.bpm = 140
        for i in 0..<4 {m.patterns[0][i].effect = 0xC; m.patterns[0][i].parameter = 32}
        XCTAssertThrowsError(try MODCodec.encode(m))
    }
    func testUnusedPatternsDoNotShiftSamples() throws {
        var m = Module.demo(); m.patterns.append(Array(repeating:Note(),count:256))
        let decoded = try MODCodec.decode(MODCodec.encode(m))
        XCTAssertEqual(decoded.samples[0].data,m.samples[0].data)
    }
}
