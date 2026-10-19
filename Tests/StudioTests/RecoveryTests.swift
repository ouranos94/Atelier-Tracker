import XCTest
import TrackerCore
@testable import AtelierTracker

final class RecoveryTests: XCTestCase {
    func folder() -> URL {FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)}
    @MainActor func testAutosaveCapturesSampleEditsAndRestoresSelections() async throws {
        let directory = folder(); defer {try? FileManager.default.removeItem(at:directory)}
        let s = Studio(); await s.enableRecovery(directory:directory)
        s.selectSampleRegion(start:16,end:80); s.sampleZoom = 4
        s.editSample(.trim)
        await s.recoveryJob?.value
        let records = await s.recoveryStore!.candidates()
        XCTAssertEqual(records.first?.module,s.module)
        XCTAssertEqual(records.first?.sampleSelection,s.sampleSelection)
        let restored = Studio(); await restored.enableRecovery(directory:directory)
        XCTAssertNotNil(restored.recoveryCandidate)
        restored.restoreRecovery()
        XCTAssertEqual(restored.module,s.module); XCTAssertEqual(restored.sampleSelection,s.sampleSelection)
        XCTAssertTrue(restored.hasChanges); XCTAssertTrue(restored.undoStack.isEmpty)
        await restored.recoveryJob?.value
        await restored.clearRecovery()
    }
    @MainActor func testPreviousRecoverySurvivesCorruptOrInvalidCurrent() async throws {
        let directory = folder(); defer {try? FileManager.default.removeItem(at:directory)}
        let store = RecoveryStore(directory:directory), s = Studio()
        let valid = s.recoveryRecord
        try await store.save(valid)
        var invalid = valid; invalid.module.orders = []
        try await store.save(valid)
        try JSONEncoder().encode(invalid).write(to:directory.appendingPathComponent("current.json"))
        await s.enableRecovery(directory:directory)
        XCTAssertEqual(s.recoveryCandidate?.module,valid.module)
        try await store.save(valid) // An invalid current must not replace the good previous copy.
        try Data("incomplete write".utf8).write(to:directory.appendingPathComponent("current.json"))
        let candidates = await store.candidates()
        XCTAssertEqual(candidates.count,1); XCTAssertEqual(candidates.first?.module,valid.module)
    }
    @MainActor func testSavingProjectCancelsPendingAutosaveAndClearsRecovery() async throws {
        let directory = folder(); defer {try? FileManager.default.removeItem(at:directory)}
        let s = Studio(); await s.enableRecovery(directory:directory)
        s.edit {$0.title = "Recovery test"}
        let pending = s.recoveryJob
        s.fileURL = directory.appendingPathComponent("saved.atelier")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        XCTAssertTrue(s.save())
        await pending?.value; await s.recoveryResetJob?.value
        let records = await s.recoveryStore!.candidates()
        XCTAssertTrue(records.isEmpty); XCTAssertFalse(s.hasChanges)
        let saved = try JSONDecoder().decode(Module.self,from:Data(contentsOf:s.fileURL!))
        XCTAssertEqual(saved,s.module)
    }
    @MainActor func testNewSessionCannotReceiveAnOldPendingRecovery() async throws {
        let directory = folder(); defer {try? FileManager.default.removeItem(at:directory)}
        let s = Studio(); await s.enableRecovery(directory:directory)
        s.edit {$0.title = "Old"}; let pending = s.recoveryJob
        // Model replacement is the successful-open path, without a discard dialog in this test.
        s.replaceModule(with:Module())
        s.hasChanges = false
        await pending?.value; await s.recoveryResetJob?.value
        let empty = await s.recoveryStore!.candidates()
        XCTAssertTrue(empty.isEmpty)
        s.edit {$0.title = "New"}; await s.recoveryJob?.value
        let records = await s.recoveryStore!.candidates()
        XCTAssertEqual(records.first?.module.title,"New")
        await s.clearRecovery()
    }
}
