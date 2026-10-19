import SwiftUI
import TrackerCore

/// Editing uses source coordinates, never guessed coordinates from converted patterns.
struct SymMODEditorView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var document: SymMODDocument?
    @State private var loadError: String?
    @AppStorage("sym.editor.pattern") private var pattern = 0
    @State private var row = 0
    @State private var channel = 0
    @State private var command: UInt8 = 0
    @State private var rate = 0
    @State private var pitch = -1
    @State private var volume = 0
    @State private var instrument = 0
    private var editable: Bool {document?.canEdit == true && selected?.isEditableEvent == true && selected?.isNoteStop != true && !s.playing && !s.rendering && !s.consolePreparing}
    private var selected: SymMODEvent? {try? document?.event(pattern:pattern,row:row,channel:channel)}
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text("Patterns Symphonie d’origine").font(.title2.bold()); Spacer(); Button("Fermer") {dismiss()}}
            Text("Les coordonnées ci-dessous sont celles du fichier source. Une modification affecte toutes les positions qui réutilisent ce pattern, avec leurs transpositions. La grille principale reste la traduction du lecteur.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if let d = document {
                HStack {
                    Stepper("Pattern source \(pattern)",value:$pattern,in:0...d.patternCount-1).frame(width:210)
                    Text("\(d.patternCount) patterns · \(d.rows) lignes · \(d.channels) pistes · \(d.instrumentCount) instruments").font(.caption).foregroundStyle(.secondary)
                    Spacer(); Button(s.playing ? "Pause" : "Écouter le morceau") {s.play()}.disabled(s.rendering)
                }
                let references = d.positions.indices.filter {d.positions[$0].pattern == pattern && d.positions[$0].length > 0}
                Text("Emplacements de position (actifs ou inutilisés) : "+(references.isEmpty ? "aucune" : references.prefix(12).map(String.init).joined(separator:", ")+(references.count > 12 ? "…" : ""))).font(.caption).foregroundStyle(.secondary)
                ScrollView([.vertical,.horizontal]) {
                    LazyVStack(alignment:.leading,spacing:1) {
                        HStack(spacing:1) {Text("LIGNE").frame(width:44); ForEach(0..<d.channels,id:\.self) {c in Text(String(format:"P%02d",c+1)).frame(width:54)}}.font(.caption.bold())
                        ForEach(0..<d.rows,id:\.self) {r in
                            HStack(spacing:1) {
                                Text(String(format:"%03d",r)).font(.system(.caption,design:.monospaced)).frame(width:44)
                                ForEach(0..<d.channels,id:\.self) {c in
                                    let event = try? d.event(pattern:pattern,row:r,channel:c)
                                    Button {row = r; channel = c; readDraft()} label: {
                                        VStack(spacing:2) {
                                            Text(event?.pitchLabel ?? "?").font(.system(size:11,weight:.semibold,design:.monospaced))
                                            Text(event.map {String(format:"%02X %02X %02X",$0.command,$0.parameter,$0.instrument)} ?? "?").font(.system(size:7,design:.monospaced))
                                        }.frame(width:54,height:32).background(row == r && channel == c ? Color.accentColor.opacity(0.3) : Color.primary.opacity(r%4 == 0 ? 0.07 : 0.02))
                                    }.buttonStyle(.plain).accessibilityLabel("Source pattern \(pattern), ligne \(r), piste \(c+1), \(event?.pitchLabel ?? "vide")")
                                }
                            }
                        }
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                Divider()
                Text("Cellule source \(pattern) : \(row) · piste \(channel+1) — octets en hexadécimal : commande / hauteur signée / paramètre / instrument").font(.caption)
                if let event = selected {
                    Text(String(format:"%02X %02X %02X %02X",event.command,UInt8(bitPattern:event.pitch),event.parameter,event.instrument)).font(.system(.body,design:.monospaced))
                    Picker("Commande",selection:$command) {ForEach(SymMODEffect.allCases) {Text($0.title).tag($0.rawValue)}}.frame(width:300).disabled(!editable)
                    let effect = SymMODEffect(rawValue:command) ?? .note
                    HStack {
                        if effect == .note {Picker("Note",selection:$pitch) {Text("Aucune (−1)").tag(-1); ForEach(0...84,id:\.self) {i in Text("\(SymMODEvent(pitch:Int8(i)).pitchLabel) [\(i)]").tag(i)}}.frame(width:200)
                        Stepper("Instrument source \(instrument)",value:$instrument,in:0...max(0,min(255,d.instrumentCount-1))).frame(width:230)}
                        Stepper("Paramètre \(volume)",value:$volume,in:0...effect.parameterMaximum).frame(width:180)
                        if effect.usesRate {Stepper("Vitesse \(rate)",value:$rate,in:0...120).frame(width:140)}
                        Button("Appliquer") {apply(SymMODEvent(command:command,pitch:effect == .note ? Int8(pitch) : event.pitch,parameter:UInt8(volume),instrument:effect == .note ? UInt8(instrument) : effect.usesRate ? UInt8(rate) : event.instrument))}
                        Button("Effacer") {apply(SymMODEvent())}
                    }.disabled(!editable)
                    if event.isNoteStop {Button("Effacer l’arrêt de note") {apply(SymMODEvent())}.disabled(s.playing || s.rendering || s.consolePreparing)}
                    Text(effect.explanation).font(.caption).foregroundStyle(.secondary)
                }
                Text(!d.canEdit ? "Structure inconnue : consultation seule. Tous les octets sont conservés." : selected?.isEditableEvent != true ? "Commande protégée : conservée, non éditable et non écrasable." : s.playing || s.rendering ? "Mets la lecture en pause pour éditer." : "Notes et effets ordinaires éditables. Instruments numérotés depuis 0. Hauteurs affichées selon le lecteur, avant transposition de position. ⌘Z : annuler.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Text("Ferme cet éditeur, puis ⌘S pour le projet, ou Fichier → Exporter SymMOD pour un module modifié. Les propriétés mono ont leur éditeur séparé ; données audio, séquences et DSP sont conservés.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            } else {Text(loadError ?? "Chargement…").foregroundStyle(.secondary); Spacer()}
        }.padding(22).frame(width:1050,height:680)
        .symEditorSurface().symMODErrorAlert(s)
        .onAppear {reload()}
        .onChange(of:command) {_,_ in volume = min(volume,(SymMODEffect(rawValue:command) ?? .note).parameterMaximum); rate = min(rate,120)}
        .onChange(of:pattern) {_,_ in readDraft()}
        .onChange(of:s.module.symphonie?.playbackSource) {_,_ in reload()}
    }
    private func apply(_ event: SymMODEvent) {
        guard let document, s.module.symphonie?.playbackSource == document.source else {reload(); return}
        _ = s.applySymEvents([SymMODCellEdit(pattern:pattern,row:row,channel:channel,event:event)],title:"Événement source modifié")
    }
    private func reload() {
        do {
            guard let source = s.module.symphonie?.playbackSource else {document = nil; loadError = "Aucun SymMOD ouvert."; return}
            let d = try SymMODDocument(source); document = d; loadError = nil
            pattern = min(max(0,pattern),d.patternCount-1); row = min(max(0,row),d.rows-1); channel = min(max(0,channel),d.channels-1); readDraft()
        } catch {document = nil; loadError = error.localizedDescription}
    }
    private func readDraft() {guard let event = selected else {return}; command = event.command; rate = Int(event.instrument); pitch = min(84,max(-1,Int(event.pitch))); volume = Int(event.parameter); instrument = Int(event.instrument)}
}
