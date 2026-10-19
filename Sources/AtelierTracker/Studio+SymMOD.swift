import SwiftUI
import TrackerCore

@MainActor extension Studio {
    func editSymNote(pattern: Int,row: Int,channel: Int,event: SymMODEvent) {
        guard isSymphonie, !playing, !rendering, !consolePreparing else {return}
        do {
            let changed = try SymphonieDecoder.replacingNote(in:module,pattern:pattern,row:row,channel:channel,event:event)
            guard changed != module else {status = "Événement inchangé"; return}
            try ModuleValidation.validate(changed)
            endEditGesture(); let previous = editorSnapshot
            stop(clearCache:true); undoStack.append(previous)
            if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
            module = changed; hasChanges = true; scheduleRecovery()
            status = "Événement SymMOD modifié · pattern source \(pattern), ligne \(row), piste \(channel+1) · toutes ses occurrences"
        } catch {self.error = error.localizedDescription}
    }
    func editSymInstrument(_ index: Int,edit: SymMODInstrumentEdit,expectedSource: Data) {
        guard isSymphonie, !playing, !rendering, !consolePreparing, module.symphonie?.playbackSource == expectedSource else {return}
        do {
            let changed = try SymphonieDecoder.replacingInstrument(in:module,index:index,edit:edit)
            guard changed != module else {status = "Instrument inchangé"; return}
            try ModuleValidation.validate(changed)
            endEditGesture(); let previous = editorSnapshot
            stop(clearCache:true); undoStack.append(previous)
            if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
            module = changed; hasChanges = true; scheduleRecovery()
            status = "Instrument SymMOD source \(index) modifié · toutes ses notes"
        } catch {self.error = error.localizedDescription}
    }
    func editSymPosition(_ index: Int,edit: SymMODPosition,expectedSource: Data) {
        editSymArrangement(expectedSource:expectedSource,label:"Position source \(index) modifiée") {
            try SymphonieDecoder.replacingPosition(in:module,index:index,edit:edit)
        }
    }
    func editSymSequence(_ index: Int,edit: SymMODSequence,expectedSource: Data) {
        editSymArrangement(expectedSource:expectedSource,label:"Séquence source \(index) modifiée") {
            try SymphonieDecoder.replacingSequence(in:module,index:index,edit:edit)
        }
    }
    private func editSymArrangement(expectedSource: Data,label: String,change: () throws -> Module) {
        guard isSymphonie, !playing, !rendering, !consolePreparing, module.symphonie?.playbackSource == expectedSource else {return}
        do {
            let changed = try change()
            guard changed != module else {status = "Arrangement inchangé"; return}
            try ModuleValidation.validate(changed)
            endEditGesture(); let previous = editorSnapshot
            stop(clearCache:true); undoStack.append(previous)
            if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
            module = changed
            order = min(max(0,order),module.orders.count-1); row = min(max(0,row),rows-1)
            block = nil; blockOrder = order
            clock.duration = module.symphonie?.duration ?? 0
            hasChanges = true; scheduleRecovery(); status = label+" · lecture reconstruite"
        } catch {self.error = error.localizedDescription}
    }
    func exportSymMOD(to url: URL) throws {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        // Re-read with the native playback decoder before writing the modified source.
        _ = try SymphonieDecoder.decode(sym.playbackSource)
        guard !FileManager.default.fileExists(atPath:url.path) else {throw ModuleError.invalid("Ce nom existe déjà. Choisis un autre nom pour conserver le fichier existant.")}
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".Atelier-Sym-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:temporary)}
        try sym.playbackSource.write(to:temporary,options:.atomic)
        try FileManager.default.moveItem(at:temporary,to:url)
        status = "SymMOD exporté : \(url.lastPathComponent)"
    }
    func exportSymMOD() {
        guard isSymphonie, !rendering else {return}
        exportName = module.title+" — édition"
        symExportPresented = true
    }
    func chooseSymMODExport() {
        let name = exportName.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains(":"), !name.contains("\0") else {error = "Choisis un nom de fichier valide."; return}
        let path = (exportDirectory as NSString).expandingTildeInPath
        var directory: ObjCBool = false
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath:path,isDirectory:&directory), directory.boolValue else {error = "Le dossier de destination n’existe pas."; return}
        let filename = name.lowercased().hasSuffix(".symmod") ? name : name+".SymMOD"
        do {try exportSymMOD(to:URL(fileURLWithPath:path,isDirectory:true).appendingPathComponent(filename)); symExportPresented = false}
        catch {self.error = error.localizedDescription}
    }
}
struct SymMODExportView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Exporter le SymMOD").font(.title2.bold())
            Text("Les notes, instruments et positions/séquences modifiés sont écrits dans le module. Les données audio et DSP restent conservés. Le mixage de console reste propre au projet Atelier.").foregroundStyle(.secondary)
            TextField("Nom du fichier",text:$s.exportName).textFieldStyle(.roundedBorder)
            TextField("Dossier de destination",text:$s.exportDirectory).textFieldStyle(.roundedBorder)
                .dropDestination(for:URL.self) {urls,_ in
                    guard let url = urls.first, (try? url.resourceValues(forKeys:[.isDirectoryKey]).isDirectory) == true else {return false}
                    s.exportDirectory = url.path; return true
                }
            Text("Dépose un dossier du Finder ici, ou saisis son chemin. Un fichier existant n’est jamais remplacé.").font(.caption).foregroundStyle(.secondary)
            HStack {Button("Annuler") {dismiss()}; Spacer(); Button("Exporter SymMOD") {s.chooseSymMODExport()}.buttonStyle(.borderedProminent)}
        }.padding(24).frame(width:550).symEditorSurface().symMODErrorAlert(s)
    }
}

// Present errors from the source editors on their own sheet, so they can be corrected immediately.
extension View {
    func symMODErrorAlert(_ studio: Studio) -> some View {
        alert("Atelier Tracker",isPresented:Binding(get:{studio.error != nil},set:{if !$0 {studio.error = nil}})) {
            Button("OK") {studio.error = nil}
        } message: {Text(studio.error ?? "")}
    }
}
