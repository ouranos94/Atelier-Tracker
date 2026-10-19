import XCTest
import AVFoundation
@testable import TrackerCore

final class MixingTests: XCTestCase {
    func cache(channels: Int = 2,frames: Int = 2000) throws -> StemCache {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
        let files = try (0..<channels).map {c -> URL in
            var data = Data(repeating:0,count:44)
            for _ in 0..<frames*2 {var value = Int16(c == 0 ? 16384 : 8192).littleEndian; withUnsafeBytes(of:&value) {data.append(contentsOf:$0)}}
            let url = dir.appendingPathComponent("\(c).wav"); try data.write(to:url); return url
        }
        return try StemCache(directory:dir,files:files,frameCount:frames)
    }
    func render(_ dsp: ConsoleDSP,_ frames: Int) -> [Float] {
        var left = [Float](repeating:0,count:frames),right = left
        left.withUnsafeMutableBufferPointer {l in right.withUnsafeMutableBufferPointer {r in dsp.render(count:frames,left:l.baseAddress!,right:r.baseAddress!)}}
        return left
    }
    func testMuteSoloPanAndValidation() throws {
        var mix = MixConfiguration(channels:2); mix.tracks[0].pan = 1
        XCTAssertEqual(mix.gains(channel:0,muted:[],solo:[]).0,0)
        XCTAssertEqual(mix.gains(channel:0,muted:[0],solo:[0]).1,0)
        XCTAssertEqual(mix.gains(channel:1,muted:[],solo:[0]).0,0)
        mix.master = .nan; XCTAssertThrowsError(try mix.validate(channels:2))
    }
    func testActualMixLiveGainSeekAndClip() throws {
        let cache = try cache(), dsp = try ConsoleDSP(cache:cache)
        var mix = MixConfiguration(channels:2)
        try dsp.apply(mix); dsp.playing = true
        XCTAssertEqual(render(dsp,10)[0],0.75,accuracy:0.00001)
        mix.tracks[0].volume = 2; mix.tracks[1].volume = 2
        try dsp.apply(mix)
        let samples = render(dsp,600)
        XCTAssertEqual(samples.last!,1); XCTAssertTrue(dsp.peaks().clipped)
        try dsp.apply(mix,muted:[0,1]); XCTAssertEqual(render(dsp,1000).last!,0)
        dsp.playing = false; let frame = dsp.frame; XCTAssertTrue(render(dsp,10).allSatisfy {$0 == 0}); XCTAssertEqual(dsp.frame,frame)
        dsp.frame = 5; XCTAssertEqual(dsp.frame,5)
        dsp.looping = true; dsp.playing = true; _ = render(dsp,3000); XCTAssertLessThan(dsp.frame,cache.frameCount); XCTAssertTrue(dsp.playing)
    }
    func testFloatExportsAlignedAndReconstructMix() throws {
        let cache = try cache(); var mix = MixConfiguration(channels:2); mix.tracks[0].volume = 2
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:parent)}
        let full = parent.appendingPathComponent("mix.wav"), stems = parent.appendingPathComponent("stems")
        try MixExporter.write(cache:cache,mix:mix,separate:false,to:full)
        try MixExporter.write(cache:cache,mix:mix,separate:true,to:stems)
        let audio = try AVAudioFile(forReading:full); XCTAssertEqual(audio.length,AVAudioFramePosition(cache.frameCount)); XCTAssertEqual(audio.fileFormat.channelCount,2)
        func samples(_ url: URL) throws -> [Float] {let data = try Data(contentsOf:url); XCTAssertEqual(data.count,44+cache.frameCount*8); XCTAssertEqual(data[20],3); return data.dropFirst(44).withUnsafeBytes {Array($0.bindMemory(to:Float.self))}}
        let a = try samples(stems.appendingPathComponent("Piste-01.wav")), b = try samples(stems.appendingPathComponent("Piste-02.wav")), sum = try samples(full)
        for i in sum.indices {XCTAssertEqual(a[i]+b[i],sum[i],accuracy:0.000001)}
        XCTAssertEqual(sum[0],1.25); XCTAssertThrowsError(try MixExporter.write(cache:cache,mix:mix,separate:false,to:full))
    }
    func testCancellationLeavesNoPartialExport() async throws {
        let cache = try cache(frames:20000)
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:parent)}
        let task = Task {try MixExporter.write(cache:cache,mix:MixConfiguration(channels:2),separate:true,to:parent.appendingPathComponent("stems")) {value in if value > 0 {withUnsafeCurrentTask {$0?.cancel()}}}}
        do {try await task.value; XCTFail("Expected cancellation")} catch is CancellationError {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:parent.path),[])
    }
    func testNativeMODStemsMatchOriginalBeforeQuantization() throws {
        let timeline = try PlaybackTimeline(Renderer.render(.demo()))
        let stems = try StemCache.prepare(module:.demo(),timeline:timeline)
        let dsp = try ConsoleDSP(cache:stems,clampOutput:false); try dsp.apply(MixConfiguration(channels:4)); dsp.playing = true
        let mixed = render(dsp,timeline.frameCount)
        timeline.result.wav.withUnsafeBytes {bytes in
            let original = bytes.baseAddress!.advanced(by:44).assumingMemoryBound(to:Int16.self)
            for frame in stride(from:0,to:timeline.frameCount,by:73) {XCTAssertEqual(mixed[frame],Float(original[frame*2])/32768,accuracy:5.0/32768)}
        }
    }
    func testRealSymphonieSixteenIsolatedTracks() throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Fixture SymMOD requise")}
        var module = try SymphonieDecoder.decode(Data(contentsOf:URL(fileURLWithPath:path)),title:"Test")
        module.mix = MixConfiguration(channels:module.channelCount); module.mix?.tracks[15].volume = 0.25
        let timeline = try PlaybackTimeline(SymphonieDecoder.render(module,maximumDuration:0.15))
        let stems = try StemCache.prepare(module:module,timeline:timeline)
        XCTAssertEqual(stems.channels,16); XCTAssertEqual(stems.frameCount,timeline.frameCount)
        XCTAssertTrue(stems.files.allSatisfy {((try? Data(contentsOf:$0).count) ?? 0) == 44+timeline.frameCount*4})
        let dsp = try ConsoleDSP(cache:stems); try dsp.apply(module.mix!); dsp.playing = true
        XCTAssertTrue(render(dsp,timeline.frameCount).allSatisfy { $0.isFinite })
        let reopened = try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(module))
        XCTAssertEqual(reopened.mix,module.mix); XCTAssertEqual(reopened.symphonie?.source,module.symphonie?.source)
    }
    func testMixProjectRoundTripAndLegacy() throws {
        var module = Module.demo(); module.mix = MixConfiguration(channels:4); module.mix?.tracks[2].pan = -0.7
        let saved = try JSONEncoder().encode(module)
        XCTAssertEqual(try JSONDecoder().decode(Module.self,from:saved),module)
        module.mix = nil; XCTAssertNil(try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(module)).mix)
    }
}
