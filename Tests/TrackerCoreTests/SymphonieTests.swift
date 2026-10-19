import XCTest
@testable import TrackerCore

final class SymphonieTests: XCTestCase {
    func testSignatureAndExtensionRouting() {
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/unknown"),prefix:Data("SymM".utf8)),.symphonie)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/TheSecret.SymMOD"),prefix:Data()),.symphonie)
        XCTAssertEqual(ImportKind.identify(url:URL(fileURLWithPath:"/tmp/unknown.mod"),prefix:Data("SymM".utf8)),.symphonie)
    }
    func testRejectsInvalidSymphonie() {
        for data in [Data(),Data("SymM".utf8),Data("SymM".utf8)+Data(repeating:0,count:100)] {
            XCTAssertThrowsError(try SymphonieDecoder.decode(data))
        }
    }
    func testLegacyProjectsWithoutSymphonieFieldStillDecode() throws {
        let encoded = try JSONEncoder().encode(Module.demo())
        var json = try JSONSerialization.jsonObject(with:encoded) as! [String:Any]
        json.removeValue(forKey:"symphonie")
        let module = try JSONDecoder().decode(Module.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(module.symphonie); XCTAssertEqual(module.channelCount,4)
        XCTAssertEqual(module.rowCount(pattern:0),64)
    }
    func testTheSecretDecodeAndRender() throws {
        guard let path = ProcessInfo.processInfo.environment["TRACKER_TEST_SYMMOD"] else {throw XCTSkip("Définir TRACKER_TEST_SYMMOD pour le test du fichier externe.")}
        let data = try Data(contentsOf:URL(fileURLWithPath:path))
        let module = try SymphonieDecoder.decode(data,title:"TheSecret")
        XCTAssertEqual(module.channelCount,16)
        XCTAssertEqual(module.symphonie?.source,data)
        XCTAssertTrue(module.orders.allSatisfy({module.patterns.indices.contains($0)}))
        XCTAssertTrue(module.patterns.allSatisfy({!$0.isEmpty && $0.count%16 == 0}))
        XCTAssertTrue(module.patterns.joined().contains(where:{$0.sample > 0}))
        XCTAssertThrowsError(try MODCodec.encode(module))
        let restored = try JSONDecoder().decode(Module.self,from:JSONEncoder().encode(module))
        XCTAssertEqual(restored.symphonie?.source,data)
        let result = try Renderer.render(module)
        XCTAssertGreaterThan(result.duration,1)
        XCTAssertTrue(result.wav.dropFirst(44).contains(where:{$0 != 0}))
        XCTAssertTrue(result.meters.allSatisfy({$0.peaks.count == 16}))
        XCTAssertTrue(result.meters.contains(where:{$0.peaks.contains(where:{$0 > 0})}))
        XCTAssertTrue(result.markers.allSatisfy({module.orders.indices.contains($0.order) && $0.row < module.rowCount(pattern:module.orders[$0.order])}))
        let silent = try SymphonieDecoder.render(module,muted:Set(0..<16),maximumDuration:2)
        XCTAssertTrue(silent.wav.dropFirst(44).allSatisfy({$0 == 0}))
        XCTAssertTrue(silent.meters.allSatisfy({$0.peaks.allSatisfy({$0 == 0})}))
        let pattern = try SymphonieDecoder.render(module,onlyOrder:0,maximumDuration:20)
        XCTAssertTrue(pattern.markers.allSatisfy({$0.order == 0}))
        print("Symphonie : \(module.channelCount) pistes, \(module.samples.count) instruments, \(module.orders.count) positions, \(module.patterns.count) patterns ; durée estimée \(module.symphonie!.duration) s ; rendu \(result.duration) s ; \(result.warnings)")
    }
}
