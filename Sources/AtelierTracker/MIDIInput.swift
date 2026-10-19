import SwiftUI
import CoreMIDI
import AVFoundation
import TrackerCore

struct MIDIEndpoint: Identifiable {let id: MIDIEndpointRef;let name: String}
final class MIDIInput: @unchecked Sendable {
    private var client: MIDIClientRef = 0, port: MIDIPortRef = 0
    private var connected: [MIDIEndpointRef] = []
    private var parsers: [UInt:MIDIByteParser] = [:]
    private let lock = NSLock()
    var receive: (@Sendable (MIDINoteEvent) -> Void)?
    static func sources() -> [MIDIEndpoint] {(0..<MIDIGetNumberOfSources()).map {i in
        let id = MIDIGetSource(i);var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(id,kMIDIPropertyDisplayName,&name)
        return MIDIEndpoint(id:id,name:name?.takeRetainedValue() as String? ?? "MIDI \(id)")
    }}
    func start(source: MIDIEndpointRef?) throws {
        stop()
        guard MIDIClientCreateWithBlock("Atelier Tracker" as CFString,&client,nil) == noErr else {throw ModuleError.invalid("Création du client MIDI impossible.")}
        let result = MIDIInputPortCreateWithBlock(client,"Clavier" as CFString,&port) {[weak self] packets,ref in self?.read(packets,key:UInt(bitPattern:ref))}
        guard result == noErr else {stop();throw ModuleError.invalid("Ouverture du port MIDI impossible : \(result).")}
        for endpoint in Self.sources() where source == nil || endpoint.id == source {
            if MIDIPortConnectSource(port,endpoint.id,UnsafeMutableRawPointer(bitPattern:UInt(endpoint.id))) == noErr {connected.append(endpoint.id)}
        }
    }
    private func read(_ list: UnsafePointer<MIDIPacketList>,key: UInt) {
        lock.lock()
        let raw = UnsafeRawPointer(list)
        var cursor = raw.advanced(by:MemoryLayout<MIDIPacketList>.offset(of:\.packet)!)
        var parser = parsers[key] ?? MIDIByteParser(),events: [MIDINoteEvent] = []
        for _ in 0..<Int(list.pointee.numPackets) {
            let packet = cursor.assumingMemoryBound(to:MIDIPacket.self)
            let data = cursor.advanced(by:MemoryLayout<MIDIPacket>.offset(of:\.data)!).assumingMemoryBound(to:UInt8.self)
            events += parser.feed(Array(UnsafeBufferPointer(start:data,count:Int(packet.pointee.length))))
            cursor = UnsafeRawPointer(MIDIPacketNext(packet))
        }
        parsers[key] = parser;lock.unlock()
        for event in events {receive?(event)}
    }
    func stop() {
        if port != 0 {for endpoint in connected {MIDIPortDisconnectSource(port,endpoint)};MIDIPortDispose(port)}
        if client != 0 {MIDIClientDispose(client)}
        client = 0;port = 0;connected = [];lock.lock();parsers = [:];lock.unlock()
    }
    deinit {stop()}
}
@MainActor final class MIDILivePlayer {
    let voice: SymLiveVoice
    private let engine = AVAudioEngine()
    init(_ module: Module) throws {
        let voice = try SymLiveVoice(module);self.voice = voice
        let format = AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
        let source = AVAudioSourceNode(format:format) {_,_,frames,list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count >= 2,let l = buffers[0].mData,let r = buffers[1].mData else {return -50}
            voice.render(count:Int(frames),left:l.assumingMemoryBound(to:Float.self),right:r.assumingMemoryBound(to:Float.self));return noErr
        }
        engine.attach(source);engine.connect(source,to:engine.mainMixerNode,format:format);try engine.start()
    }
    func stop() {voice.noteOff();engine.stop()}
    deinit {engine.stop()}
}
