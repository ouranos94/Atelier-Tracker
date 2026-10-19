import XCTest
@testable import TrackerCore

final class SymMODCorpusTests: XCTestCase {
    var root: URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    func testOriginalSyntheticCorpusAndIndependentStructuralAudit() throws {
        let directory = root.appendingPathComponent("Tests/Fixtures/SymMOD")
        let cases = try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).filter {$0.pathExtension.lowercased() == "symmod"}.sorted {$0.path < $1.path}
        XCTAssertEqual(cases.count,10)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:temporary,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:temporary)}
        for url in cases {
            let source = try Data(contentsOf:url), doc = try SymMODDocument(source)
            let module = try SymphonieDecoder.decode(source,title:url.deletingPathExtension().lastPathComponent)
            XCTAssertEqual(module.channelCount,doc.channels,url.lastPathComponent)
            let mapping = try XCTUnwrap(module.symphonie!.orderSource,url.lastPathComponent)
            let entry = try XCTUnwrap(mapping.compactMap {$0}.first)
            let cell = try doc.cell(in:entry,row:0,channel:0)
            let edit = SymMODEvent(pitch:36,parameter:70,instrument:0)
            let changed = try SymphonieDecoder.replacingEvents(in:module,edits:[SymMODCellEdit(pattern:cell.pattern,row:cell.row,channel:cell.channel,event:edit)])
            XCTAssertEqual(changed.symphonie!.source,source)
            let exported = temporary.appendingPathComponent(url.lastPathComponent)
            try changed.symphonie!.playbackSource.write(to:exported)
            let reopened = try SymphonieDecoder.decode(Data(contentsOf:exported),title:changed.title)
            XCTAssertEqual(reopened.patterns,changed.patterns)
            let audio = try SymphonieDecoder.render(module,maximumDuration:0.4).wav
            XCTAssertGreaterThan(SymMODInstrumentTests().rms(audio),1,url.lastPathComponent)
            let after = try SymphonieDecoder.render(changed,maximumDuration:0.4).wav
            XCTAssertLessThan(SymMODDocumentTests().rmsDifference(after,try SymphonieDecoder.render(reopened,maximumDuration:0.4).wav),4)
            let process = Process(), pipe = Pipe()
            process.executableURL = URL(fileURLWithPath:"/usr/bin/python3")
            process.arguments = [root.appendingPathComponent("scripts/audit-symmod.py").path,url.path,"--compare",exported.path,"--allow-events"]
            process.standardOutput = pipe; process.standardError = pipe
            try process.run(); let report = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus,0,String(data:report,encoding:.utf8) ?? "Audit failed")
            let parsed = try JSONSerialization.jsonObject(with:report) as! [String:Any]
            XCTAssertEqual(parsed["channels"] as? Int,doc.channels)
            let comparison = parsed["comparison"] as! [String:Any]
            XCTAssertFalse(comparison["byte_exact"] as! Bool)
            XCTAssertEqual((comparison["changes"] as! [[String:Any]]).count,1)
            if url.lastPathComponent == "cross-pattern.SymMOD" {XCTAssertEqual(try doc.cell(in:entry,row:3,channel:0).pattern,1)}
            if url.lastPathComponent == "sequences.SymMOD" {XCTAssertEqual(mapping.count,3); XCTAssertNil(mapping[1])}
            if url.lastPathComponent == "virtual.SymMOD" {XCTAssertTrue(try doc.instrument(3).isVirtual)}
            if url.lastPathComponent == "stereo.SymMOD" {XCTAssertEqual(try doc.instrument(0).channel,1); XCTAssertEqual(try doc.instrument(1).channel,2)}
        }
    }
}
