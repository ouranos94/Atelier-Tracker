import SwiftUI
import AppKit
import TrackerCore

struct EditorSnapshot {
    let module: Module
    let order: Int, row: Int, channel: Int, sample: Int, blockOrder: Int
    let block: PatternSelection?
    let sampleSelection: SampleRegion?
    let sampleZoom: Double, sampleViewOffset: Double
}
enum MusicalKeyboard: String,CaseIterable,Identifiable {
    case qwerty, azerty
    var id: String {rawValue}
    var title: String {rawValue.uppercased()}
    var lower: [String] {self == .qwerty ? ["z","s","x","d","c","v","g","b","h","n","j","m"] : ["w","s","x","d","c","v","g","b","h","n","j",","]}
    var upper: [String] {self == .qwerty ? ["q","2","w","3","e","r","5","t","6","y","7","u"] : ["a","é","z","\"","e","r","(","t","-","y","è","u"]}
    func note(for key: String) -> Int? {
        if let i = lower.firstIndex(of:key.lowercased()) {return i}
        return upper.firstIndex(of:key.lowercased()).map {$0+12}
    }
}

@MainActor extension Studio {
    static let blockPasteboardType = NSPasteboard.PasteboardType("studio.atelier.tracker.mod-block.v1")
    var canCompose: Bool {!playing && !rendering && !consolePreparing && !sampleEditorOpen && !symSourceSheetPresented && (!isSymphonie || symScoreSource && selectedSymEntry != nil)}
    var selection: PatternSelection {
        if blockOrder == order, let block, block.rowRange.lowerBound >= 0, block.rowRange.upperBound < rows, block.channels.lowerBound >= 0, block.channels.upperBound < module.channelCount {return block}
        return PatternSelection(row:min(rows-1,max(0,row)),channel:min(module.channelCount-1,max(0,channel)))
    }
    var editorSnapshot: EditorSnapshot {EditorSnapshot(module:module,order:order,row:row,channel:channel,sample:sample,blockOrder:blockOrder,block:block,sampleSelection:sampleSelection,sampleZoom:sampleZoom,sampleViewOffset:sampleViewOffset)}
    func restore(_ snapshot: EditorSnapshot) {
        module = snapshot.module
        if preparedAudio == nil, let duration = module.symphonie?.duration {clock.duration = duration}
        order = min(max(0,snapshot.order),module.orders.count-1)
        row = min(max(0,snapshot.row),rows-1); channel = min(max(0,snapshot.channel),module.channelCount-1)
        sample = min(max(0,snapshot.sample),module.samples.count-1)
        block = snapshot.block; blockOrder = snapshot.blockOrder
        sampleSelection = snapshot.sampleSelection; sampleZoom = snapshot.sampleZoom; sampleViewOffset = snapshot.sampleViewOffset
    }
    func beginEditGesture() {if gestureSnapshot == nil {gestureSnapshot = editorSnapshot; gestureChanged = false}}
    func endEditGesture() {gestureSnapshot = nil; gestureChanged = false}
    func extendSelection(toRow: Int,channel: Int) {
        selectCell(order:order,row:toRow,channel:channel,extending:true)
    }
    func selectPattern() {
        guard canCompose else {return}
        block = PatternSelection(row:0,channel:0,toRow:rows-1,toChannel:module.channelCount-1); blockOrder = order
        status = "Position sélectionnée · \(rows) lignes × \(module.channelCount) pistes"
    }
    func clearSelection() {
        if isSymphonie {clearSymBlock(); return}
        guard canCompose else {return}
        performPatternEdit("Sélection effacée") {notes,range in try PatternEditing.clear(&notes,selection:range); return range}
    }
    @discardableResult func copyBlock(to pasteboard: NSPasteboard = .general) -> Bool {
        if isSymphonie {return copySymBlock(to:pasteboard)}
        guard canCompose else {return false}
        do {
            let block = try PatternEditing.copy(module.patterns[pattern],selection:selection)
            let data = try JSONEncoder().encode(block)
            let text = (0..<block.height).map {r in (0..<block.width).map {c in
                let n = block.notes[r*block.width+c]
                return String(format:"%@ %02X %X%02X",n.label,n.sample,n.effect,n.parameter)
            }.joined(separator:" | ")}.joined(separator:"\n")
            pasteboard.clearContents()
            guard pasteboard.setData(data,forType:Self.blockPasteboardType) else {throw ModuleError.invalid("Le bloc n’a pas pu être copié dans le presse-papiers.")}
            pasteboard.setString(text,forType:.string)
            status = "Bloc copié · \(block.height) lignes × \(block.width) pistes"
            return true
        } catch {self.error = error.localizedDescription; return false}
    }
    func cutBlock(to pasteboard: NSPasteboard = .general) {
        guard canCompose else {return}
        guard copyBlock(to:pasteboard) else {return}; clearSelection(); status = "Bloc coupé"
    }
    func pasteBlock(from pasteboard: NSPasteboard = .general,mix: Bool = false) {
        if isSymphonie {pasteSymBlock(from:pasteboard,mix:mix); return}
        guard canCompose else {return}
        do {
            guard let data = pasteboard.data(forType:Self.blockPasteboardType) else {throw ModuleError.invalid("Copie d’abord un bloc MOD dans la partition. Le texte seul et les événements SymMOD ne peuvent pas être collés comme notes.")}
            let copied = try PatternBlock.decode(data), target = selection
            performPatternEdit(mix ? "Bloc mélangé" : "Bloc remplacé") {notes,_ in
                try PatternEditing.paste(copied,into:&notes,row:target.rowRange.lowerBound,channel:target.channels.lowerBound,mix:mix)
            }
        } catch {self.error = error.localizedDescription}
    }
    func transpose(_ semitones: Int,wholePattern: Bool = false) {
        if isSymphonie {transposeSymBlock(semitones,wholePosition:wholePattern); return}
        guard canCompose else {return}
        performPatternEdit("Transposition \(semitones > 0 ? "+" : "")\(semitones) demi-tons",wholePattern:wholePattern) {notes,range in
            try PatternEditing.transpose(&notes,selection:range,semitones:semitones); return range
        }
    }
    func moveBlock(rows: Int,channels: Int = 0,duplicate: Bool = false) {
        if isSymphonie {moveSymBlock(rows:rows,channels:channels,duplicate:duplicate); return}
        guard canCompose else {return}
        performPatternEdit(duplicate ? "Bloc dupliqué" : "Bloc déplacé") {notes,range in
            try PatternEditing.move(&notes,selection:range,rows:rows,channels:channels,duplicate:duplicate)
        }
    }
    func duplicateBlock() {moveBlock(rows:selection.height,duplicate:true)}
    func shiftLines(insert: Bool) {
        guard !isSymphonie else {status = "Insertion de lignes réservée aux patterns MOD"; return}
        guard canCompose else {return}
        let all = rowsAllTracks
        performPatternEdit(insert ? "Lignes insérées" : "Lignes supprimées") {notes,range in
            try PatternEditing.shiftLines(&notes,selection:range,insert:insert,allTracks:all); return range
        }
    }
    func performPatternEdit(_ title: String,wholePattern: Bool = false,_ action: (inout [Note],PatternSelection) throws -> PatternSelection) {
        guard canCompose else {return}
        do {
            let p = pattern, range = wholePattern ? PatternSelection(row:0,channel:0,toRow:63,toChannel:3) : selection
            var notes = module.patterns[p]
            let result = try action(&notes,range)
            guard notes != module.patterns[p] else {status = "Aucune donnée modifiée"; return}
            endEditGesture(); edit {$0.patterns[p] = notes}
            block = result; blockOrder = order; row = result.rowRange.lowerBound; channel = result.channels.lowerBound
            status = title + (module.orders.filter({$0 == p}).count > 1 ? " · pattern partagé : toutes ses occurrences sont modifiées" : "")
        } catch {self.error = error.localizedDescription}
    }
}
