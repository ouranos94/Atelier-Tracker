import AppKit
import TrackerCore

@MainActor extension Studio {
    static let symBlockPasteboardType = NSPasteboard.PasteboardType("studio.atelier.tracker.symmod-block.v1")
    func symEntry(at order: Int) -> SymMODOrderSource? {
        guard let map = module.symphonie?.orderSource, map.indices.contains(order) else {return nil}; return map[order]
    }
    var selectedSymEntry: SymMODOrderSource? {symEntry(at:order)}
    func symEvent(order: Int,row: Int,channel: Int) -> SymMODEvent? {
        guard let doc = symArchive, let entry = symEntry(at:order), let cell = try? doc.cell(in:entry,row:row,channel:channel) else {return nil}
        return try? doc.event(pattern:cell.pattern,row:cell.row,channel:cell.channel)
    }
    var selectedSymEvent: SymMODEvent? {symEvent(order:order,row:row,channel:channel)}
    @discardableResult func applySymEvents(_ edits: [SymMODCellEdit],title: String) -> Bool {
        guard isSymphonie, !playing, !rendering, !consolePreparing else {return false}
        do {
            let changed = try SymphonieDecoder.replacingEvents(in:module,edits:edits)
            guard changed != module else {status = "Aucune cellule modifiée"; return true}
            try ModuleValidation.validate(changed)
            endEditGesture(); let previous = editorSnapshot
            stop(clearCache:true); undoStack.append(previous)
            if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
            module = changed; clock.duration = changed.symphonie?.duration ?? 0
            order = min(order,module.orders.count-1); row = min(row,rows-1)
            hasChanges = true; scheduleRecovery(); status = title+" · toutes les occurrences source"
            return true
        } catch {self.error = error.localizedDescription; return false}
    }
    func editSelectedSymEvent(_ event: SymMODEvent) {
        guard canCompose, let d = symArchive, let entry = selectedSymEntry, let cell = try? d.cell(in:entry,row:row,channel:channel) else {return}
        _ = applySymEvents([SymMODCellEdit(pattern:cell.pattern,row:cell.row,channel:cell.channel,event:event)],title:"Événement source modifié")
    }
    func enterSymNote(_ index: Int) {
        guard canCompose, let current = selectedSymEvent, current.isEditableNote else {status = "Choisis une cellule de note ordinaire pour saisir au clavier"; return}
        guard (2...9).contains(octave), (0...23).contains(index), (0...255).contains(sample) else {status = "Octave, touche ou instrument source hors limites"; return}
        let pitch = (octave-2)*12+index
        guard (0...84).contains(pitch), sample < (symArchive?.instrumentCount ?? 0) else {status = "Hauteur ou instrument source hors limites"; return}
        var written = true
        if recording {
            var e = current; e.pitch = Int8(pitch); e.instrument = UInt8(sample)
            guard let d = symArchive, let entry = selectedSymEntry, let cell = try? d.cell(in:entry,row:row,channel:channel) else {return}
            written = applySymEvents([SymMODCellEdit(pattern:cell.pattern,row:cell.row,channel:cell.channel,event:e)],title:"Note source saisie")
            if written {selectCell(order:order,row:min(rows-1,row+advance),channel:channel)}
        }
        if written {auditionSymInstrument(sample,pitch:pitch)}
    }
    private func symEdits(_ range: PatternSelection,transform: (SymMODEvent) throws -> SymMODEvent) throws -> [SymMODCellEdit] {
        guard let d = symArchive, let entry = selectedSymEntry else {throw ModuleError.invalid("Correspondance source non vérifiée.")}
        _ = try d.copyBlock(entry:entry,selection:range)
        return try range.rowRange.flatMap {r in try range.channels.map {c in
            let cell = try d.cell(in:entry,row:r,channel:c), e = try d.event(pattern:cell.pattern,row:cell.row,channel:cell.channel)
            return SymMODCellEdit(pattern:cell.pattern,row:cell.row,channel:cell.channel,event:try transform(e))
        }}
    }
    func clearSymBlock() {
        guard canCompose else {return}
        do {_ = applySymEvents(try symEdits(selection,transform:{_ in SymMODEvent()}),title:"Bloc SymMOD effacé")}
        catch {self.error = error.localizedDescription}
    }
    func copySymBlock(to pasteboard: NSPasteboard) -> Bool {
        guard canCompose, let d = symArchive, let entry = selectedSymEntry else {return false}
        do {
            let block = try d.copyBlock(entry:entry,selection:selection), data = try JSONEncoder().encode(block)
            pasteboard.clearContents(); guard pasteboard.setData(data,forType:Self.symBlockPasteboardType) else {throw ModuleError.invalid("Copie impossible.")}
            pasteboard.setString(block.events.map(\.summary).joined(separator:"\n"),forType:.string)
            status = "Bloc SymMOD copié · \(block.height) × \(block.width)"; return true
        } catch {self.error = error.localizedDescription; return false}
    }
    func pasteSymBlock(from pasteboard: NSPasteboard,mix: Bool) {
        guard canCompose, let d = symArchive, let entry = selectedSymEntry else {return}
        do {
            guard let data = pasteboard.data(forType:Self.symBlockPasteboardType) else {throw ModuleError.invalid("Copie d’abord un bloc SymMOD. Les blocs MOD et le texte ne sont pas convertis implicitement.")}
            let block = try SymMODBlock.decode(data), target = selection
            let edits = try d.editsForPaste(block,entry:entry,row:target.rowRange.lowerBound,channel:target.channels.lowerBound,mix:mix)
            if applySymEvents(edits,title:"Bloc SymMOD collé") {self.block = PatternSelection(row:target.rowRange.lowerBound,channel:target.channels.lowerBound,toRow:target.rowRange.lowerBound+block.height-1,toChannel:target.channels.lowerBound+block.width-1); blockOrder = order}
        } catch {self.error = error.localizedDescription}
    }
    func transposeSymBlock(_ semitones: Int,wholePosition: Bool) {
        guard canCompose, (-84...84).contains(semitones) else {return}
        let range = wholePosition ? PatternSelection(row:0,channel:0,toRow:rows-1,toChannel:module.channelCount-1) : selection
        do {
            let edits = try symEdits(range) {event in
                var e = event
                if e.command == 0 && e.pitch >= 0 {
                    let pitch = Int(e.pitch)+semitones
                    guard (0...84).contains(pitch) else {throw ModuleError.invalid("Transposition hors des hauteurs source 0…84 ; aucune note modifiée.")}
                    e.pitch = Int8(pitch)
                }
                return e
            }
            _ = applySymEvents(edits,title:"Bloc SymMOD transposé")
        } catch {self.error = error.localizedDescription}
    }
    func moveSymBlock(rows delta: Int,channels: Int,duplicate: Bool) {
        guard canCompose, let d = symArchive, let entry = selectedSymEntry, (-1023...1023).contains(delta), (-255...255).contains(channels) else {return}
        do {
            let range = selection, copied = try d.copyBlock(entry:entry,selection:range)
            let r = range.rowRange.lowerBound+delta, c = range.channels.lowerBound+channels
            let pasted = try d.editsForPaste(copied,entry:entry,row:r,channel:c)
            var byCell: [String:SymMODCellEdit] = [:]
            if !duplicate {for edit in try symEdits(range,transform:{_ in SymMODEvent()}) {byCell["\(edit.pattern):\(edit.row):\(edit.channel)"] = edit}}
            for edit in pasted {byCell["\(edit.pattern):\(edit.row):\(edit.channel)"] = edit}
            if applySymEvents(Array(byCell.values),title:duplicate ? "Bloc SymMOD dupliqué" : "Bloc SymMOD déplacé") {
                block = PatternSelection(row:r,channel:c,toRow:r+copied.height-1,toChannel:c+copied.width-1); blockOrder = order; row = r; channel = c
            }
        } catch {self.error = error.localizedDescription}
    }
}
