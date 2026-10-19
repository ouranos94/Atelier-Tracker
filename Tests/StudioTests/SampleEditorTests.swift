import XCTest
import TrackerCore
@testable import AtelierTracker

final class SampleEditorTests: XCTestCase {
    @MainActor func testAllSampleOperationsRestoreDataLoopAndViewThroughUndoRedo() {
        for operation in SampleOperation.allCases {
            let s = Studio()
            s.selectSampleRegion(start:20,end:80); s.sampleZoom = 4; s.sampleViewOffset = 0.25
            let before = s.module, region = s.sampleSelection
            s.editSample(operation)
            XCTAssertNil(s.error); XCTAssertEqual(s.undoStack.count,1)
            let after = s.module, afterRegion = s.sampleSelection
            XCTAssertNotEqual(before,after)
            s.undo(); XCTAssertEqual(s.module,before); XCTAssertEqual(s.sampleSelection,region)
            XCTAssertEqual(s.sampleZoom,4); XCTAssertEqual(s.sampleViewOffset,0.25)
            s.redo(); XCTAssertEqual(s.module,after); XCTAssertEqual(s.sampleSelection,afterRegion)
        }
    }
    @MainActor func testLoopGestureIsOneActionAndSwitchingSampleStopsPreview() {
        let s = Studio(), before = s.module
        s.beginEditGesture()
        for end in [120,100,80] {s.setSampleLoop(start:8,end:end)}
        s.endEditGesture(); XCTAssertEqual(s.undoStack.count,1)
        s.undo(); XCTAssertEqual(s.module,before); s.redo(); XCTAssertEqual(s.currentSample.loopStart,8); XCTAssertEqual(s.currentSample.loopLength,72)
        s.previewSample(loop:true); XCTAssertTrue(s.samplePreviewing); XCTAssertEqual(s.previewPlayer?.numberOfLoops,-1)
        s.sample = 1; XCTAssertFalse(s.samplePreviewing); XCTAssertNil(s.previewPlayer); XCTAssertNil(s.sampleSelection)
    }
    @MainActor func testSelectionPreviewAndStopCannotChangeSong() async throws {
        let s = Studio(), before = s.module
        s.selectSampleRegion(start:20,end:80); s.previewSample()
        XCTAssertTrue(s.samplePreviewing)
        s.stop(); XCTAssertFalse(s.samplePreviewing); XCTAssertNil(s.previewPlayer)
        try await Task.sleep(nanoseconds:100_000_000)
        XCTAssertFalse(s.samplePreviewing); XCTAssertEqual(s.module,before); XCTAssertTrue(s.undoStack.isEmpty)
        s.previewSample(loop:true); XCTAssertTrue(s.samplePreviewing)
        s.play(); XCTAssertFalse(s.samplePreviewing); XCTAssertNil(s.previewPlayer)
        s.stop()
    }
    func testViewportEndpointsForShortAndZoomedSamples() {
        let tiny = SampleViewport(length:2,zoom:64,offset:1)
        XCTAssertEqual(tiny.start,0); XCTAssertEqual(tiny.end,2)
        let view = SampleViewport(length:10000,zoom:10,offset:1)
        XCTAssertEqual(view.start,9000); XCTAssertEqual(view.end,10000)
        XCTAssertEqual(view.point(at:-1,width:100),9000); XCTAssertEqual(view.point(at:1000,width:100),10000)
        XCTAssertEqual(SampleViewport(length:0,zoom:.nan,offset:.infinity).end,0)
        XCTAssertNil(SampleEditing.alignedRegion(start:1,end:1,length:2))
    }
    @MainActor func testSymphonieSampleEditsAndPreviewsRemainDisabled() async throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("TRACKER_TEST_SYMMOD requis")}
        let s = Studio(); s.open(url:URL(fileURLWithPath:path)); let before = s.module
        s.editSample(.trim); s.setSampleLoop(start:0,end:8); s.previewSample()
        XCTAssertEqual(s.module,before); XCTAssertFalse(s.samplePreviewing); XCTAssertTrue(s.undoStack.isEmpty)
    }
}
