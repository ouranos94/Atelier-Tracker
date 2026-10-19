import XCTest
import TrackerCore
@testable import AtelierTracker

final class ScorePresentationTests: XCTestCase {
    func testOverviewFitsSixteenTracksAtMinimumWindowWidth() {
        let metrics = ScoreMetrics(font:11,zoom:1,compact:true)
        XCTAssertEqual(metrics.width(available:1120,channels:16),1120)
        // Higher font sizes and zoom must allocate scrollable space, rather than overlap cells.
        let large = ScoreMetrics(font:18,zoom:2,compact:true)
        XCTAssertGreaterThan(large.width(available:1120,channels:16),1120)
        XCTAssertGreaterThan(large.trackWidth,7*16*0.62)
        XCTAssertGreaterThan(large.rowHeight,2*18)
        let detail = ScoreMetrics(font:20,zoom:1,compact:false)
        XCTAssertGreaterThan(detail.trackWidth,12*20*0.62)
    }
    func testResizedPanelsLeaveRoomForTransportAndScore() {
        for window in [1120.0,1380,1920] {
            for saved in [180.0,220,360,10000,Double.nan] {
                let width = ScoreMetrics.panelWidth(saved:saved,available:window)
                XCTAssertTrue(width.isFinite)
                XCTAssertGreaterThanOrEqual(width,180)
                XCTAssertLessThanOrEqual(width,360)
                XCTAssertGreaterThanOrEqual(window-2*width-12,600)
            }
        }
    }
    @MainActor func testSymphonieSelectedTrackAndFormatChange() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("TRACKER_TEST_SYMMOD requis")}
        let s = Studio(); s.open(url:URL(fileURLWithPath:path))
        XCTAssertTrue(s.isOverview); XCTAssertEqual(Array(s.visibleChannels),Array(0..<16))
        s.channel = 15; s.channelPage = -2
        XCTAssertFalse(s.isOverview); XCTAssertEqual(Array(s.visibleChannels),[15])
        s.channel = 4; XCTAssertEqual(Array(s.visibleChannels),[4])
        s.newModule()
        XCTAssertEqual(Array(s.visibleChannels),[0,1,2,3]); XCTAssertFalse(s.isOverview)
    }
}
