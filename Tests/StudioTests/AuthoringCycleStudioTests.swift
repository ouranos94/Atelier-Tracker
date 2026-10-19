import XCTest
import CoreMIDI
import TrackerCore
@testable import AtelierTracker

final class AuthoringCycleStudioTests: XCTestCase {
    @MainActor func studio() throws -> Studio {
        let s = Studio();s.replaceModule(with:try SymMODComposer.create(title:"Cycle",channels:16,rows:32));return s
    }
    @MainActor func testAuthoringHistoryPCMImportFollowAndTransition() throws {
        let s = try studio(), original = s.module
        s.appendSymPosition();XCTAssertEqual(s.module.orders.count,2)
        s.appendSymPosition(reuse:true);XCTAssertEqual(s.symOccurrences(1),2)
        s.undo();XCTAssertEqual(s.module.orders.count,2);s.undo();XCTAssertEqual(s.module,original);s.redo()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let wav = root.appendingPathComponent("Tone.wav"),pcm = SymPCM(samples:(0..<10000).map {Int16(sin(Double($0)*0.1)*20000)})
        try pcm.wav().write(to:wav);try s.importSymPCM(url:wav,index:0)
        let imported = try XCTUnwrap(s.symArchive?.pcm(0)?.samples)
        XCTAssertEqual(imported.count,pcm.samples.count);XCTAssertLessThanOrEqual(zip(imported,pcm.samples).map {abs(Int($0)-Int($1))}.max() ?? 0,1)
        XCTAssertEqual(s.module.symphonie?.source,original.symphonie?.source)
        s.playbackOrder = 1;s.playbackRow = 8;s.order = 0;s.row = 2;s.phase = .playing
        XCTAssertEqual(s.scoreOrder,1);XCTAssertEqual(s.scoreRow,8)
        let generation = s.playbackGeneration;s.followPlayback = false
        XCTAssertEqual(s.scoreOrder,0);XCTAssertEqual(s.scoreRow,2);XCTAssertEqual(s.playbackGeneration,generation)
        s.followPlayback = true;XCTAssertEqual(s.scoreRow,8)
        s.phase = .stopped;s.fileURL = root.appendingPathComponent("Roundtrip.atelier");XCTAssertTrue(s.save())
        let copy = Studio();copy.open(url:s.fileURL!);XCTAssertEqual(copy.module,s.module)
        let sym = root.appendingPathComponent("Roundtrip.SymMOD");try s.exportSymMOD(to:sym)
        XCTAssertEqual(try SymMODDocument(Data(contentsOf:sym)).pcm(0)?.samples,imported)
        s.replaceModule(with:.demo());XCTAssertFalse(s.isSymphonie);XCTAssertEqual(s.meters.levels.count,4);XCTAssertNil(s.midiLivePlayer)
    }
    @MainActor func testQuantizedTakeSingleUndoAndFailureIsAtomic() throws {
        let s = try studio(),original = s.module,entry = try XCTUnwrap(s.selectedSymEntry)
        var take = MIDITake(source:s.module.symphonie!.playbackSource,entry:entry,order:0,channel:0,instrument:0)
        take.notes = [MIDIGridNote(row:0,end:2,pitch:36,velocity:127),MIDIGridNote(row:4,end:6,pitch:38,velocity:64)]
        s.midiTake = take;s.endMIDITake(apply:true)
        XCTAssertNil(s.error);XCTAssertEqual(s.undoStack.count,1);XCTAssertEqual(try PianoEditing.notes(s.symArchive!,entry:entry,channel:0).count,2)
        let changed = s.module;s.undo();XCTAssertEqual(s.module,original);s.redo();XCTAssertEqual(s.module,changed)
        take = MIDITake(source:changed.symphonie!.playbackSource,entry:entry,order:0,channel:0,instrument:0)
        take.notes = [MIDIGridNote(row:0,end:3,pitch:40,velocity:100)]
        s.midiTake = take;s.endMIDITake(apply:true)
        XCTAssertNotNil(s.error);XCTAssertEqual(s.module,changed);XCTAssertEqual(s.undoStack.count,1)
    }
    @MainActor func testCoreMIDIVirtualSourceReceivesRealPacketsAndNoteOff() async throws {
        var client: MIDIClientRef = 0,source: MIDIEndpointRef = 0
        XCTAssertEqual(MIDIClientCreateWithBlock("Atelier Test" as CFString,&client,nil),noErr)
        defer {MIDIEndpointDispose(source);MIDIClientDispose(client)}
        XCTAssertEqual(MIDISourceCreate(client,"Atelier Virtual Keyboard" as CFString,&source),noErr)
        let s = try studio();s.midiSource = source;s.configureMIDI(enabled:true)
        defer {s.configureMIDI(enabled:false)}
        XCTAssertTrue(s.midiEnabled);s.midiStepEntry = true;s.midiQuantization = 2
        let received = expectation(description:"CoreMIDI virtual note reaches Studio")
        s.midiInput.receive = {[weak s] event in Task {@MainActor in s?.handleMIDI(event);if event.on {received.fulfill()}}}
        var list = MIDIPacketList();let messages: [UInt8] = [0x90,60,100]
        withUnsafeMutablePointer(to:&list) {p in let packet = MIDIPacketListInit(p);messages.withUnsafeBufferPointer {bytes in _ = MIDIPacketListAdd(p,MemoryLayout<MIDIPacketList>.size,packet,0,bytes.count,bytes.baseAddress!)};XCTAssertEqual(MIDIReceived(source,p),noErr)}
        await fulfillment(of:[received],timeout:3)
        XCTAssertEqual(s.midiActiveNote,60);XCTAssertTrue(s.hasChanges)
        XCTAssertEqual(try s.symArchive?.event(pattern:0,row:0,channel:0).pitch,36)
        s.handleMIDI(MIDINoteEvent(channel:1,note:60,velocity:0));XCTAssertNil(s.midiActiveNote)
    }
}
