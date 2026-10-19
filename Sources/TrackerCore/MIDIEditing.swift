import Foundation

public struct MIDINoteEvent: Equatable,Sendable {
    public let channel: Int,note: Int,velocity: Int
    public var on: Bool {velocity > 0}
    public init(channel: Int,note: Int,velocity: Int) {self.channel = channel;self.note = note;self.velocity = velocity}
}
/// MIDI 1 byte stream, including running status, real-time interleaving and SysEx exclusion.
public struct MIDIByteParser {
    private var status: UInt8 = 0
    private var bytes: [UInt8] = []
    public init() {}
    public mutating func feed(_ input: [UInt8]) -> [MIDINoteEvent] {
        var result: [MIDINoteEvent] = []
        for b in input {
            if b >= 0xf8 {continue}
            if b >= 0x80 {status = b < 0xf0 ? b : 0;bytes.removeAll(keepingCapacity:true);continue}
            guard status >= 0x80 else {continue}
            bytes.append(b)
            let kind = status & 0xf0,needed = kind == 0xc0 || kind == 0xd0 ? 1 : 2
            if bytes.count == needed {
                if kind == 0x90 || kind == 0x80 {result.append(MIDINoteEvent(channel:Int(status&15)+1,note:Int(bytes[0]),velocity:kind == 0x80 ? 0 : Int(bytes[1])))}
                bytes.removeAll(keepingCapacity:true)
            }
        }
        return result
    }
}
public struct MIDIGridNote: Equatable,Sendable {
    public let row: Int,end: Int,pitch: Int,velocity: Int
    public init(row: Int,end: Int,pitch: Int,velocity: Int) {self.row = row;self.end = end;self.pitch = pitch;self.velocity = velocity}
}
public enum MIDIEditing {
    public static func quantize(_ row: Double,step: Int) -> Int {guard row.isFinite else {return 0};return Int((row/Double(max(1,step))).rounded())*max(1,step)}
    public static func edits(_ doc: SymMODDocument,entry: SymMODOrderSource,channel: Int,instrument: Int,notes: [MIDIGridNote]) throws -> [SymMODCellEdit] {
        guard !notes.isEmpty,notes.count <= 256 else {throw ModuleError.invalid("Prise MIDI vide ou supérieure à 256 notes.")}
        var current = doc, combined: [Int:SymMODCellEdit] = [:]
        for note in notes.sorted(by:{$0.row < $1.row}) {
            guard (1...127).contains(note.velocity) else {throw ModuleError.invalid("Vélocité MIDI invalide.")}
            let edits = try PianoEditing.edits(current,entry:entry,channel:channel,replacing:nil,row:note.row,pitch:note.pitch,duration:note.end-note.row,instrument:instrument,volume:max(1,Int((Double(note.velocity)*100/127).rounded())))
            current = try SymMODDocument(current.replacingEvents(edits))
            for edit in edits {combined[(edit.pattern*doc.rows+edit.row)*doc.channels+edit.channel] = edit}
        }
        return Array(combined.values)
    }
}
