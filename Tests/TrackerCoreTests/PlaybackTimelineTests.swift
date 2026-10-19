import XCTest
@testable import TrackerCore

final class PlaybackTimelineTests: XCTestCase {
    func testPositionsAndPatternRanges() throws {
        var module = Module.demo()
        module.orders = [0,0]
        let timeline = try PlaybackTimeline(Renderer.render(module))
        XCTAssertEqual(timeline.position(at:0)?.row,0)
        let second = try XCTUnwrap(timeline.range(order:1))
        XCTAssertEqual(timeline.range(order:0)?.end,second.start)
        XCTAssertEqual(timeline.position(at:second.start)?.order,1)
        XCTAssertEqual(timeline.position(at:timeline.duration)?.row,63)
        XCTAssertEqual(timeline.time(order:1,row:0),second.start)
        XCTAssertNil(timeline.time(order:3,row:0))
        XCTAssertNil(timeline.boundedRange(start:2,end:1))
        XCTAssertNil(timeline.boundedRange(start:0,end:0.001))
        XCTAssertNil(timeline.boundedRange(start:.nan,end:3))
    }
    func testSeekSlicePreservesAudioStateAndLoopLength() throws {
        let timeline = try PlaybackTimeline(Renderer.render(.demo()))
        let range = try XCTUnwrap(timeline.boundedRange(start:0.5,end:1.5))
        let plain = try timeline.wav(in:range)
        let smooth = try timeline.wav(in:range,smoothLoop:true)
        let start = Int((range.start*44100).rounded())
        XCTAssertEqual(plain.count,44100*4+44)
        XCTAssertEqual(plain.dropFirst(44),timeline.result.wav[(44+start*4)..<(44+start*4+44100*4)])
        XCTAssertEqual(smooth.count,plain.count)
        XCTAssertEqual(smooth[44..<48],Data(repeating:0,count:4))
        XCTAssertEqual(smooth.suffix(4),Data(repeating:0,count:4))
        XCTAssertEqual(smooth[400..<smooth.count-400],plain[400..<plain.count-400])
        let size = (0..<4).reduce(0) {$0 | Int(plain[40+$1]) << (8*$1)}
        XCTAssertEqual(size,plain.count-44)
    }
}
