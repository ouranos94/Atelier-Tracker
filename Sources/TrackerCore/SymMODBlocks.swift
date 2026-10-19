import Foundation
import CryptoKit

public struct SymMODBlock: Codable,Sendable {
    public var version = 1
    public let width: Int, height: Int, bank: String
    public var events: [SymMODEvent]
    public init(width: Int,height: Int,bank: String,events: [SymMODEvent]) {self.width = width; self.height = height; self.bank = bank; self.events = events}
    public func validate() throws {
        guard version == 1, (1...256).contains(width), (1...1024).contains(height), events.count == width*height, events.allSatisfy(\.isEditableEvent) else {throw ModuleError.invalid("Bloc SymMOD incompatible ou protégé.")}
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 32*1024*1024 else {throw ModuleError.invalid("Presse-papiers SymMOD trop volumineux.")}
        let value = try JSONDecoder().decode(Self.self,from:data); try value.validate(); return value
    }
}
extension SymMODDocument {
    public var instrumentBankID: String {SHA256.hash(data:instrumentData).map {String(format:"%02x",$0)}.joined()}
    public func copyBlock(entry: SymMODOrderSource,selection: PatternSelection) throws -> SymMODBlock {
        guard selection.rowRange.lowerBound >= 0, selection.rowRange.upperBound < entry.length,
              selection.channels.lowerBound >= 0, selection.channels.upperBound < channels else {throw ModuleError.invalid("Sélection hors de la position source.")}
        let cells = try selection.rowRange.flatMap {r in try selection.channels.map {c in
            let cell = try cell(in:entry,row:r,channel:c); return try event(pattern:cell.pattern,row:cell.row,channel:cell.channel)
        }}
        let block = SymMODBlock(width:selection.width,height:selection.height,bank:instrumentBankID,events:cells); try block.validate(); return block
    }
    public func editsForPaste(_ block: SymMODBlock,entry: SymMODOrderSource,row: Int,channel: Int,mix: Bool = false) throws -> [SymMODCellEdit] {
        try block.validate()
        guard block.bank == instrumentBankID else {throw ModuleError.invalid("La banque d’instruments a changé. Recopie le bloc dans ce morceau ; aucun remappage d’instrument implicite n’est effectué.")}
        guard row >= 0, channel >= 0, row < entry.length, channel < channels, block.height <= entry.length-row, block.width <= channels-channel else {throw ModuleError.invalid("Le bloc dépasse la position ou les pistes. Aucune cellule modifiée.")}
        var edits: [SymMODCellEdit] = []
        for r in 0..<block.height {for c in 0..<block.width {
            let e = block.events[r*block.width+c]
            // Mixing is event-based: an empty cell is skipped; commands are never combined.
            if mix && e == SymMODEvent() {continue}
            let cell = try cell(in:entry,row:row+r,channel:channel+c)
            edits.append(SymMODCellEdit(pattern:cell.pattern,row:cell.row,channel:cell.channel,event:e))
        }}
        return edits
    }
}
extension SymphonieDecoder {
    public static func replacingEvents(in module: Module,edits: [SymMODCellEdit]) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        let bytes = try SymMODDocument(sym.playbackSource).replacingEvents(edits)
        guard bytes != sym.playbackSource else {return module}
        var changed = module; changed.symphonie?.editedSource = bytes == sym.source ? nil : bytes
        return try refreshed(changed)
    }
}
