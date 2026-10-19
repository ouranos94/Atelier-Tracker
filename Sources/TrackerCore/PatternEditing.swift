import Foundation

public struct PatternSelection: Codable, Equatable, Sendable {
    public var anchorRow: Int, anchorChannel: Int, focusRow: Int, focusChannel: Int
    public init(row: Int,channel: Int,toRow: Int? = nil,toChannel: Int? = nil) {
        anchorRow = row; anchorChannel = channel; focusRow = toRow ?? row; focusChannel = toChannel ?? channel
    }
    public var rowRange: ClosedRange<Int> {min(anchorRow,focusRow)...max(anchorRow,focusRow)}
    public var channels: ClosedRange<Int> {min(anchorChannel,focusChannel)...max(anchorChannel,focusChannel)}
    public var height: Int {rowRange.count}
    public var width: Int {channels.count}
    public var isValid: Bool {rowRange.lowerBound >= 0 && rowRange.upperBound < 64 && channels.lowerBound >= 0 && channels.upperBound < 4}
    public func contains(row: Int,channel: Int) -> Bool {rowRange.contains(row) && channels.contains(channel)}
}

/// Only MOD events are transferable. Instruments remain references to destination sample slots.
public struct PatternBlock: Codable, Equatable, Sendable {
    public var version = 1
    public var format = "protracker4"
    public var width: Int, height: Int
    public var notes: [Note]
    public init(width: Int,height: Int,notes: [Note]) {self.width = width; self.height = height; self.notes = notes}
    public func validate() throws {
        guard version == 1, format == "protracker4", (1...4).contains(width), (1...64).contains(height), notes.count == width*height,
              notes.allSatisfy({(0...4095).contains($0.period) && (0...31).contains($0.sample) && (0...15).contains($0.effect) && (0...255).contains($0.parameter) && $0.displayNote == nil && $0.displayEffect == nil}) else {
            throw ModuleError.invalid("Le presse-papiers ne contient pas un bloc MOD compatible.")
        }
    }
    public static func decode(_ data: Data) throws -> PatternBlock {
        guard data.count <= 131072 else {throw ModuleError.invalid("Le bloc copié est trop volumineux.")}
        let block = try JSONDecoder().decode(Self.self,from:data); try block.validate(); return block
    }
}

public enum PatternEditing {
    private static func validate(_ notes: [Note],_ selection: PatternSelection) throws {
        guard notes.count == 256, selection.isValid else {throw ModuleError.invalid("Sélection hors du pattern MOD (64 lignes, 4 pistes).")}
    }
    public static func copy(_ notes: [Note],selection: PatternSelection) throws -> PatternBlock {
        try validate(notes,selection)
        return PatternBlock(width:selection.width,height:selection.height,notes:selection.rowRange.flatMap {r in selection.channels.map {notes[r*4+$0]}})
    }
    public static func clear(_ notes: inout [Note],selection: PatternSelection) throws {
        try validate(notes,selection)
        for r in selection.rowRange {for c in selection.channels {notes[r*4+c] = Note()}}
    }
    public static func paste(_ block: PatternBlock,into notes: inout [Note],row: Int,channel: Int,mix: Bool = false) throws -> PatternSelection {
        try block.validate()
        guard (0..<64).contains(row), (0..<4).contains(channel) else {throw ModuleError.invalid("Destination hors du pattern MOD.")}
        let selection = PatternSelection(row:row,channel:channel,toRow:row+block.height-1,toChannel:channel+block.width-1)
        try validate(notes,selection)
        for r in 0..<block.height {for c in 0..<block.width {
            let source = block.notes[r*block.width+c], index = (row+r)*4+channel+c
            if !mix {notes[index] = source}
            else {
                if source.period != 0 {notes[index].period = source.period}
                if source.sample != 0 {notes[index].sample = source.sample}
                if source.effect != 0 || source.parameter != 0 {notes[index].effect = source.effect; notes[index].parameter = source.parameter}
            }
        }}
        return selection
    }
    public static func transpose(_ notes: inout [Note],selection: PatternSelection,semitones: Int) throws {
        try validate(notes,selection)
        var result = notes
        for r in selection.rowRange {for c in selection.channels {
            let i = r*4+c, period = notes[i].period
            guard period > 0 else {continue}
            let nearest = Note.periods.indices.min(by:{abs(Note.periods[$0]-period) < abs(Note.periods[$1]-period)})!
            guard (-nearest...(Note.periods.count-1-nearest)).contains(semitones) else {throw ModuleError.invalid("Transposition impossible : une note dépasserait les trois octaves MOD. Aucune note n’a été modifiée.")}
            result[i].period = Note.periods[nearest+semitones]
        }}
        notes = result
    }
    public static func move(_ notes: inout [Note],selection: PatternSelection,rows: Int,channels: Int,duplicate: Bool = false) throws -> PatternSelection {
        guard (-63...63).contains(rows), (-3...3).contains(channels) else {throw ModuleError.invalid("Déplacement hors du pattern MOD.")}
        let block = try copy(notes,selection:selection)
        let target = PatternSelection(row:selection.rowRange.lowerBound+rows,channel:selection.channels.lowerBound+channels,toRow:selection.rowRange.upperBound+rows,toChannel:selection.channels.upperBound+channels)
        try validate(notes,target)
        var result = notes
        if !duplicate {try clear(&result,selection:selection)}
        _ = try paste(block,into:&result,row:target.rowRange.lowerBound,channel:target.channels.lowerBound)
        notes = result; return target
    }
    /// Fixed 64-row patterns: insertion discards the tail; deletion pads it with empty events.
    public static func shiftLines(_ notes: inout [Note],selection: PatternSelection,insert: Bool,allTracks: Bool) throws {
        try validate(notes,selection)
        let start = selection.rowRange.lowerBound, amount = selection.height, channels = allTracks ? 0...3 : selection.channels
        let original = notes
        for r in start..<64 {for c in channels {
            let source = insert ? r-amount : r+amount
            notes[r*4+c] = source >= start && source < 64 ? original[source*4+c] : Note()
        }}
    }
}
