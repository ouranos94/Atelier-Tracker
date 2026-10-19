import SwiftUI
import TrackerCore

struct SymMODArrangementView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var document: SymMODDocument?
    @State private var loadError: String?
    @AppStorage("sym.arrangement.sequences") private var sequences = false
    @AppStorage("sym.arrangement.selected") private var selected = 0
    @State private var pattern = 0
    @State private var start = 0
    @State private var length = 1
    @State private var speed = 6
    @State private var repeats = 1
    @State private var transpose = 0
    private var available: Bool {!s.playing && !s.rendering && !s.consolePreparing}
    private var editable: Bool {
        guard let d = document else {return false}
        return available && (sequences ? d.canEditSequence(selected) : d.canEditPosition(selected))
    }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Arrangement Symphonie d’origine").font(.title2.bold()); Spacer()
                Button(s.playing ? "Pause" : "Écouter le morceau") {s.play()}.disabled(s.rendering)
                Button("Fermer") {dismiss()}
            }
            Text("Une séquence lit une plage de positions. Chaque position choisit un pattern source et ses lignes. Modifier une position affecte toutes les séquences qui la référencent. Les numéros commencent à 0.").foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if let d = document {
                Picker("Table source",selection:$sequences) {Text("Positions (\(d.positions.count))").tag(false); Text("Séquences (\(d.sequences.count))").tag(true)}.pickerStyle(.segmented)
                HStack(alignment:.top,spacing:24) {
                    List(selection:Binding<Int?>(get:{selected},set:{if let value = $0 {selected = value; readDraft()}})) {
                        ForEach(0..<(sequences ? d.sequences.count : d.positions.count),id:\.self) {i in
                            HStack(alignment:.top) {
                                Text(String(format:"%03d",i)).monospaced()
                                if sequences {
                                    let item = d.sequences[i]
                                    VStack(alignment:.leading) {Text(item.info == -1 ? "Fin des séquences" : item.info == 1 ? "Séquence ignorée" : item.length == 0 ? "Emplacement vide" : "Positions \(item.start)…\(item.start+max(0,item.length)-1)"); Text(d.activeSequenceIndices.contains(i) ? "Active · \(item.length) positions" : "Conservée · consultation seule").font(.caption).foregroundStyle(.secondary)}
                                } else {
                                    let item = d.positions[i]
                                    VStack(alignment:.leading) {Text("Pattern \(item.pattern)"); Text("Ligne \(item.start) · \(item.length) lignes").font(.caption).foregroundStyle(.secondary)}
                                }
                                Spacer()
                                if sequences ? !d.canEditSequence(i) : !d.canEditPosition(i) {Image(systemName:"lock").foregroundStyle(.secondary)}
                            }.padding(.vertical,3).tag(i).accessibilityLabel("\(sequences ? "Séquence" : "Position") source \(i)")
                        }
                    }.frame(width:310)
                    ScrollView {
                        VStack(alignment:.leading,spacing:18) {
                            Text("\(sequences ? "SÉQUENCE" : "POSITION") SOURCE \(selected)").font(.headline)
                            if sequences, d.sequences.indices.contains(selected) {
                                let item = d.sequences[selected]
                                Text("État \(item.info) · boucle source \(item.loops) conservée").font(.caption).foregroundStyle(.secondary)
                                Group {
                                    Stepper("Première position : \(start)",value:$start,in:0...max(0,min(65535,d.positions.count-1)))
                                    Stepper("Nombre de positions : \(length)",value:$length,in:1...max(1,min(65535,d.positions.count)))
                                    Stepper("Transposition : \(transpose) demi-tons",value:$transpose,in: -24...24)
                                }.disabled(!editable)
                                Text("La plage doit rester dans la table des positions et contenir des positions prises en charge. Les séquences actives sont jouées dans l’ordre, jusqu’au marqueur de fin.").font(.caption).foregroundStyle(.secondary)
                                Button("Voir la première position") {selected = min(max(0,item.start),max(0,d.positions.count-1)); sequences = false; readDraft()}.disabled(d.positions.isEmpty)
                                Text("Les boucles de séquence ne sont pas appliquées par le lecteur actuel. Elles restent intactes, avec les marqueurs de fin et d’exclusion.").font(.caption).foregroundStyle(.secondary)
                            } else if !sequences, d.positions.indices.contains(selected) {
                                Group {
                                    Stepper("Pattern source : \(pattern)",value:$pattern,in:0...min(65535,d.patternCount-1))
                                    Stepper("Première ligne : \(start)",value:$start,in:0...d.rows-1)
                                    Stepper("Nombre de lignes : \(length)",value:$length,in:1...d.rows)
                                    Stepper("Vitesse : \(speed) ticks",value:$speed,in:1...31)
                                    Stepper("Répétitions source : \(repeats)",value:$repeats,in:0...16)
                                    Stepper("Transposition : \(transpose) demi-tons",value:$transpose,in: -24...24)
                                }.disabled(!editable)
                                Text("0 et 1 répétition source jouent la position une fois. Première ligne + longueur ≤ \(d.rows). Les transpositions de position et de séquence se cumulent, sauf instruments configurés pour les ignorer.").font(.caption).foregroundStyle(.secondary)
                                let refs = d.activeSequenceIndices.filter {let q = d.sequences[$0]; return selected >= q.start && selected-q.start < q.length}
                                Text(refs.isEmpty ? "Aucune séquence active ne référence cette position : son édition n’affectera pas l’écoute actuelle." : "Séquences actives utilisant cette position : "+refs.map(String.init).joined(separator:", ")).font(.caption).foregroundStyle(.secondary)
                            }
                            Divider()
                            HStack {Button("Revenir aux valeurs courantes") {readDraft()}; Spacer(); Button("Appliquer") {apply()}.buttonStyle(.borderedProminent)}.disabled(!editable)
                            if !editable {Text(!available ? "Mets la lecture en pause et attends la fin des préparations pour éditer." : "Consultation seule : structure inconnue, marqueur, séquence inactive ou position hors des limites prises en charge.").font(.caption).foregroundStyle(.secondary)}
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,8)
                    }
                }.frame(maxHeight:.infinity)
            } else {Text(loadError ?? "Chargement…").foregroundStyle(.secondary); Spacer()}
            Divider()
            Text("Appliquer arrête le transport, reconstruit la partition et annule ses caches et points A/B. ⌘Z / ⇧⌘Z : annuler / rétablir. Ferme l’éditeur avant d’enregistrer le projet ou d’exporter le SymMOD.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.padding(24).frame(width:1000,height:700)
        .symEditorSurface().symMODErrorAlert(s)
        .onAppear {reload()}
        .onChange(of:sequences) {_,_ in
            if let d = document {selected = min(max(0,selected),max(0,(sequences ? d.sequences.count : d.positions.count)-1))}; readDraft()
        }
        .onChange(of:s.module.symphonie?.playbackSource) {_,_ in reload()}
    }
    private func reload() {
        do {
            guard let bytes = s.module.symphonie?.playbackSource else {document = nil; loadError = "Aucun SymMOD ouvert."; return}
            let d = try SymMODDocument(bytes); document = d; loadError = nil
            selected = min(max(0,selected),max(0,(sequences ? d.sequences.count : d.positions.count)-1)); readDraft()
        } catch {document = nil; loadError = error.localizedDescription}
    }
    private func readDraft() {
        guard let d = document else {return}
        if sequences, d.sequences.indices.contains(selected) {let q = d.sequences[selected]; start = q.start; length = q.length; transpose = q.transpose}
        else if !sequences, d.positions.indices.contains(selected) {let p = d.positions[selected]; pattern = p.pattern; start = p.start; length = p.length; speed = p.speed; repeats = p.repeats; transpose = p.transpose}
    }
    private func apply() {
        guard editable, let d = document, s.module.symphonie?.playbackSource == d.source else {reload(); return}
        if sequences {
            var edit = d.sequences[selected]; edit.start = start; edit.length = length; edit.transpose = transpose
            s.editSymSequence(selected,edit:edit,expectedSource:d.source)
        } else {
            var edit = d.positions[selected]; edit.pattern = pattern; edit.start = start; edit.length = length; edit.speed = speed; edit.repeats = repeats; edit.transpose = transpose
            s.editSymPosition(selected,edit:edit,expectedSource:d.source)
        }
    }
}
