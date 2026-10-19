import Foundation

public enum SymMODEffect: UInt8,CaseIterable,Identifiable,Sendable {
    case note = 0, volumeUp = 1, volumeDown = 2, pitchUp = 3, pitchDown = 4, speed = 9, tremolo = 12, vibrato = 13
    public var id: UInt8 {rawValue}
    public var title: String {
        switch self {case .note:return "Note / volume"; case .volumeUp:return "Monter le volume"; case .volumeDown:return "Baisser le volume"; case .pitchUp:return "Monter la hauteur"; case .pitchDown:return "Baisser la hauteur"; case .speed:return "Vitesse du morceau"; case .tremolo:return "Trémolo"; case .vibrato:return "Vibrato"}
    }
    public var explanation: String {
        switch self {
        case .note:return "Hauteur source avant transposition. Volume 0 : conserver le niveau précédent ; 1…100 : niveau. Une cellule ne contient qu’une commande."
        case .volumeUp,.volumeDown:return "Intensité source 0…255 ; 0 arrête le glissement. Le lecteur approxime ce glissement continu selon la vitesse du pattern."
        case .pitchUp,.pitchDown:return "Intensité source 0…255 ; 0 arrête le glissement. Le lecteur approxime ce glissement continu selon la vitesse du pattern."
        case .speed:return "Commande globale : 1…31 ticks par ligne ; 0 utilise 4 ticks. Le tempo en BPM reste distinct."
        case .tremolo:return "Profondeur et vitesse source 0…120 (paliers de 8 dans le lecteur). 0/0 arrête le trémolo ; une composante nulle seule ne garantit pas l’arrêt."
        case .vibrato:return "Profondeur 0…15 ; vitesse source 0…120, en paliers de 8 dans le lecteur. 0/0 arrête le vibrato."
        }
    }
    public var parameterMaximum: Int {switch self {case .note:return 100; case .speed:return 31; case .tremolo:return 120; case .vibrato:return 15; default:return 255}}
    public var usesRate: Bool {self == .tremolo || self == .vibrato}
}
extension SymMODEvent {
    public var effect: SymMODEffect? {SymMODEffect(rawValue:command)}
    public var isEditableEvent: Bool {
        if isNoteStop {return true}
        guard let effect else {return false}
        if effect == .note {return isEditableNote}
        return Int(parameter) <= effect.parameterMaximum && (!effect.usesRate || instrument <= 120)
    }
    public var summary: String {
        if isNoteStop {return "Arrêt de note (source FE)"}
        guard let effect else {return String(format:"Commande protégée %02X · %02X %02X %02X",command,UInt8(bitPattern:pitch),parameter,instrument)}
        if effect == .note && parameter > 100 {return String(format:"Commande de note protégée · paramètre %02X · instrument %02X",parameter,instrument)}
        if effect == .note {return "\(pitchLabel) · instrument source \(instrument) · volume \(parameter)"}
        return effect.title+" · \(parameter)"+(effect.usesRate ? " · vitesse \(instrument)" : "")
    }
}
public struct SymMODCellEdit: Sendable {
    public let pattern: Int, row: Int, channel: Int
    public let event: SymMODEvent
    public init(pattern: Int,row: Int,channel: Int,event: SymMODEvent) {self.pattern = pattern; self.row = row; self.channel = channel; self.event = event}
}
extension SymMODDocument {
    /// Validate the entire gesture before modifying any byte. Opaque events cannot be overwritten.
    public func replacingEvents(_ edits: [SymMODCellEdit]) throws -> Data {
        guard canEdit, edits.count <= 262144 else {throw ModuleError.invalid("Structure protégée ou édition trop volumineuse.")}
        var payload = events, seen = Set<Int>()
        for edit in edits {
            let previous = try event(pattern:edit.pattern,row:edit.row,channel:edit.channel), e = edit.event
            guard previous.isEditableEvent, e.isEditableEvent, e.command != 0 || Int(e.instrument) < instrumentCount else {throw ModuleError.invalid("Sélection contenant une commande protégée, un effet hors limites ou un instrument inexistant. Aucune cellule modifiée.")}
            let offset = ((edit.pattern*rows+edit.row)*channels+edit.channel)*4
            guard seen.insert(offset).inserted else {throw ModuleError.invalid("Cellule dupliquée dans une même édition.")}
            payload.replaceSubrange(offset..<offset+4,with:e.bytes)
        }
        guard payload != events else {return source}
        return try replacingEventPayload(payload)
    }
}
