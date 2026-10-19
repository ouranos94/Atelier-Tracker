import Foundation

public struct PianoNote: Identifiable,Equatable,Sendable {
    public var id: Int {row}
    public let row: Int, pitch: Int, instrument: Int, volume: Int, duration: Int
    public let explicitStop: Bool
}
extension SymMODEvent {
    public var isNoteStop: Bool {command == 0 && pitch == -1 && parameter == 254 && instrument == 0}
    public static var noteStop: Self {Self(parameter:254)}
}
public enum PianoEditing {
    public static func notes(_ doc: SymMODDocument,entry: SymMODOrderSource,channel: Int) throws -> [PianoNote] {
        var result: [PianoNote] = [], active: (Int,SymMODEvent)?
        func finish(_ end: Int,_ stopped: Bool) {
            if let (r,e) = active {result.append(PianoNote(row:r,pitch:Int(e.pitch),instrument:Int(e.instrument),volume:Int(e.parameter),duration:max(1,end-r),explicitStop:stopped))};active = nil
        }
        for r in 0..<entry.length {
            let cell = try doc.cell(in:entry,row:r,channel:channel), e = try doc.event(pattern:cell.pattern,row:cell.row,channel:cell.channel)
            if e.isEditableNote && e.pitch >= 0 {finish(r,false);active = (r,e)}
            else if e.isNoteStop {finish(r,true)}
        }
        finish(entry.length,false);return result
    }
    public static func edits(_ doc: SymMODDocument,entry: SymMODOrderSource,channel: Int,replacing old: PianoNote?,row: Int,pitch: Int,duration: Int,instrument: Int,volume: Int) throws -> [SymMODCellEdit] {
        guard row >= 0, row < entry.length-1, duration >= 1, duration < entry.length-row,
              (0...84).contains(pitch), (0...255).contains(instrument), instrument < doc.instrumentCount, (1...100).contains(volume) else {throw ModuleError.invalid("Note hors limites : hauteur 0…84, volume 1…100 et une ligne libre pour l’arrêt avant la fin de position.")}
        let existing = try notes(doc,entry:entry,channel:channel)
        if let old {guard existing.contains(old) else {throw ModuleError.invalid("La note a changé : sélectionne-la à nouveau.")}}
        let end = row+duration
        for note in existing where note != old {
            guard end <= note.row || row >= note.row+note.duration else {throw ModuleError.invalid("Chevauchement de notes sur une piste monophonique. Aucune modification.")}
        }
        var permitted = Set<Int>(), byRow: [Int:SymMODEvent] = [:]
        if let old {permitted.insert(old.row);byRow[old.row] = SymMODEvent();if old.explicitStop {permitted.insert(old.row+old.duration);byRow[old.row+old.duration] = SymMODEvent()}}
        for r in [row,end] where !permitted.contains(r) {
            let cell = try doc.cell(in:entry,row:r,channel:channel), e = try doc.event(pattern:cell.pattern,row:cell.row,channel:cell.channel)
            let sharedStop = r == row && e.isNoteStop && existing.contains {$0 != old && $0.row+$0.duration == row && $0.explicitStop}
            let nextOnset = r == end && existing.contains {$0 != old && $0.row == end}
            guard e == SymMODEvent() || sharedStop || nextOnset else {throw ModuleError.invalid("Le début ou l’arrêt écraserait une commande existante. Choisis une ligne vide.")}
        }
        byRow[row] = SymMODEvent(pitch:Int8(pitch),parameter:UInt8(volume),instrument:UInt8(instrument))
        if !existing.contains(where:{$0 != old && $0.row == end}) {byRow[end] = .noteStop}
        return try byRow.map {r,e in let c = try doc.cell(in:entry,row:r,channel:channel);return SymMODCellEdit(pattern:c.pattern,row:c.row,channel:c.channel,event:e)}
    }
    public static func deleting(_ doc: SymMODDocument,entry: SymMODOrderSource,channel: Int,note: PianoNote) throws -> [SymMODCellEdit] {
        guard try notes(doc,entry:entry,channel:channel).contains(note) else {throw ModuleError.invalid("Note périmée.")}
        let rows = [note.row]+(note.explicitStop ? [note.row+note.duration] : [])
        return try rows.map {r in let c = try doc.cell(in:entry,row:r,channel:channel);return SymMODCellEdit(pattern:c.pattern,row:c.row,channel:c.channel,event:SymMODEvent())}
    }
}
