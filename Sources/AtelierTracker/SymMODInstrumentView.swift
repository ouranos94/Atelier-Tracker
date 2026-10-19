import SwiftUI
import TrackerCore

struct SymMODInstrumentView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var document: SymMODDocument?
    @State private var instruments: [SymMODInstrument] = []
    @AppStorage("sym.instrument.selected") private var selected = 0
    @State private var loadError: String?
    @State private var draft = SymMODInstrumentEdit(volume:100,finetune:0,transpose:0,ignorePositionTranspose:false)
    @State private var rewriteLoop = false
    @State private var loopEnabled = false
    @State private var loopStart = 0.0
    @State private var loopLength = 0.0
    private var instrument: SymMODInstrument? {instruments.indices.contains(selected) ? instruments[selected] : nil}
    private var editable: Bool {document?.canEdit == true && instrument?.canEdit == true && !s.playing && !s.rendering && !s.consolePreparing}
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("Instruments Symphonie d’origine").font(.title2.bold()); Spacer(); Button(s.playing ? "Pause" : "Écouter le morceau") {s.play()}.disabled(s.rendering); Button("Fermer") {dismiss()}}
            Text("Les propriétés s’appliquent à toutes les notes de cet instrument. Les numéros source commencent à 0. L’import PCM remplace uniquement le sample choisi.").foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack(alignment:.top,spacing:24) {
                ScrollViewReader {proxy in
                    List(selection:Binding<Int?>(get:{selected},set:{value in
                        if let value {selected = value;s.sample = value; readDraft()}
                    })) {ForEach(instruments.indices,id:\.self) {i in
                        HStack {Text(String(format:"%03d",i)).monospaced(); Text(instruments[i].name.isEmpty ? "Vide" : instruments[i].isVirtual ? "Instrument virtuel" : instruments[i].name.components(separatedBy:"/").last ?? instruments[i].name).lineLimit(1); Spacer(); if !instruments[i].canEdit {Image(systemName:"lock")}}
                            .padding(.vertical,3).tag(i).id(i).accessibilityLabel("Instrument source \(i), \(instruments[i].name.isEmpty ? "vide" : instruments[i].name)")
                    }}.onAppear {proxy.scrollTo(selected,anchor:.center)}
                }.frame(width:270)
                ScrollView {
                    VStack(alignment:.leading,spacing:18) {
                        if let ins = instrument {
                            Text("SOURCE \(selected)").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(ins.isVirtual ? "Instrument virtuel / transwave" : ins.name.isEmpty ? "Emplacement vide" : ins.name).font(.headline).textSelection(.enabled)
                            Text("\(ins.kindDescription) · type \(ins.type) · canal \(ins.channel) · \(ins.bypassDSP ? "DSP contournés" : "DSP actifs")").font(.caption).foregroundStyle(.secondary)
                            SymPCMEditorView(index:selected).id(selected)
                            SymMODInstrumentPreview(index:selected,instrument:ins)
                            Group {
                                Stepper("Volume instrument : \(draft.volume)",value:$draft.volume,in:0...199)
                                Text(draft.volume == 0 ? "0 = volume par défaut (100), pas silence." : draft.volume > 100 ? "101…199 : amplification avec compression Symphonie." : "1…100 : niveau de l’instrument.").font(.caption).foregroundStyle(.secondary)
                                Stepper("Transposition : \(draft.transpose) demi-tons",value:$draft.transpose,in: -128...127)
                                Stepper("Accord fin : \(draft.finetune) (\(String(format:"%.2f",Double(draft.finetune)*100/128)) cents)",value:$draft.finetune,in: -128...127)
                                Toggle("Ignorer les transpositions de position et de séquence",isOn:$draft.ignorePositionTranspose)
                                Divider()
                                Text("BOUCLE").font(.caption.bold())
                                Text("\(ins.loop.enabled ? "Activée" : "Désactivée") · départ \(String(format:"%.4f",Double(ins.loop.start)/65536)) % · longueur \(String(format:"%.4f",Double(ins.loop.length)/65536)) %").font(.caption)
                                Toggle("Modifier la boucle",isOn:$rewriteLoop)
                                if rewriteLoop {
                                    Toggle("Boucle continue",isOn:$loopEnabled)
                                    Stepper("Départ : \(String(format:"%.4f",loopStart)) %",value:$loopStart,in:0...100,step:0.1).disabled(!loopEnabled)
                                    Stepper("Longueur : \(String(format:"%.4f",loopLength)) %",value:$loopLength,in:0...100,step:0.1).disabled(!loopEnabled)
                                    Text("Départ + longueur ≤ 100 %. Les nouvelles limites utilisent la précision fine Symphonie ; le lecteur les arrondit aux points du sample.").font(.caption).foregroundStyle(.secondary)
                                }
                                if !ins.fineLoops {Text("Ancien système de boucle : conservé tant que ses limites ne sont pas changées. Une modification peut changer ses arrondis.").font(.caption).foregroundStyle(.secondary)}
                                HStack {Button("Revenir aux valeurs courantes") {readDraft()}; Spacer(); Button("Appliquer") {apply()}.buttonStyle(.borderedProminent)}
                            }.disabled(!editable)
                            if !ins.canEdit {Text("Consultation seule : instrument vide, virtuel, stéréo, sustain ou propriétés non prises en charge.").foregroundStyle(.secondary)}
                            else if document?.canEdit != true {Text("Structure inconnue : édition désactivée.").foregroundStyle(.secondary)}
                            else if !editable {Text("Mets la lecture en pause et attends la fin des préparations pour éditer.").foregroundStyle(.secondary)}
                        } else {Text(loadError ?? "Aucun instrument source.").foregroundStyle(.secondary)}
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,8)
                }
            }.frame(maxHeight:.infinity)
            Divider()
            Text("Appliquer arrête le transport et invalide ses caches. Relance le morceau pour écouter le résultat. ⌘Z / ⇧⌘Z : annuler / rétablir. Ferme cet éditeur avant d’enregistrer le projet ou d’exporter le SymMOD.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.padding(24).frame(width:1000,height:700)
        .symEditorSurface().symMODErrorAlert(s)
        .onDisappear {s.cancelSymAudition()}
        .onAppear {selected = s.sample;reload()}
        .onChange(of:s.module.symphonie?.playbackSource) {_,_ in reload()}
    }
    private func reload() {
        do {
            guard let source = s.module.symphonie?.playbackSource else {document = nil; instruments = []; loadError = "Aucun SymMOD ouvert."; return}
            let doc = try SymMODDocument(source); document = doc
            instruments = try (0..<doc.instrumentCount).map {try doc.instrument($0)}
            selected = min(max(0,selected),max(0,instruments.count-1)); loadError = nil; readDraft()
        } catch {document = nil; instruments = []; loadError = error.localizedDescription}
    }
    private func readDraft() {
        s.cancelSymAudition()
        guard let ins = instrument else {return}
        draft = ins.settings; rewriteLoop = false; loopEnabled = ins.loop.enabled
        loopStart = min(100,Double(ins.loop.start)/65536); loopLength = min(100,Double(ins.loop.length)/65536)
    }
    private func apply() {
        guard editable, let doc = document, s.module.symphonie?.playbackSource == doc.source else {reload(); return}
        var settings = draft
        if rewriteLoop {settings.loop = SymMODLoop(enabled:loopEnabled,start:Int((loopStart*65536).rounded()),length:Int((loopLength*65536).rounded()))}
        s.editSymInstrument(selected,edit:settings,expectedSource:doc.source)
    }
}
