import SwiftUI
import TrackerCore

struct ConsoleView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("Console de mixage").font(.title2.bold()); Spacer(); Button("Fermer") {dismiss()}}
            HStack {
                Button(s.playing ? "Pause" : "Lecture") {s.play()}.disabled(s.rendering)
                Button("Arrêt") {s.stop()}
                Picker("Source",selection:Binding(get:{s.consoleActive},set:{s.setConsoleActive($0)})) {
                    Text("Original").tag(false); Text("Console").tag(true)
                }.pickerStyle(.segmented).disabled(s.consoleCache == nil)
            }
            Text("La console rend chaque piste avec ses effets isolés. Les DSP partagés SymMOD peuvent sonner différemment du mix original. La balance atténue un côté de la stéréo existante.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if s.consoleCache == nil {
                HStack {
                    Button("Préparer les pistes") {s.prepareConsole()}.disabled(s.consolePreparing || s.rendering)
                    Text("Cache temporaire : ≈ \(Int(s.clock.duration*176400*Double(s.module.channelCount)/1048576)) Mio").foregroundStyle(.secondary)
                }
            }
            if s.consolePreparing {HStack {ProgressView(value:s.consoleProgress); Button("Annuler") {s.cancelConsolePreparation()}}}
            ScrollView(.horizontal) {
                HStack(alignment:.top,spacing:16) {ForEach(0..<s.module.channelCount,id:\.self) {c in
                    VStack(spacing:12) {
                        Text(String(format:"PISTE %02d",c+1)).font(.headline)
                        ConsoleTrackMeter(meters:s.meters,channel:c,muted:s.effectiveMuted.contains(c))
                        HStack {Button("M") {s.toggleMute(c)}.tint(s.muted.contains(c) ? .red : .accentColor).accessibilityLabel("Muet piste \(c+1)").accessibilityValue(s.muted.contains(c) ? "Actif" : "Inactif"); Button("S") {s.toggleSolo(c)}.tint(s.solos.contains(c) ? .orange : .accentColor).accessibilityLabel("Solo piste \(c+1)").accessibilityValue(s.solos.contains(c) ? "Actif" : "Inactif")}.buttonStyle(.bordered)
                        Text(String(format:"%.0f %%",s.trackMix(c).volume*100)).monospacedDigit()
                        Slider(value:Binding(get:{s.trackMix(c).volume},set:{s.setTrackVolume(c,$0)}),in:0...2,onEditingChanged:gesture).accessibilityLabel("Volume piste \(c+1)")
                        Text("Balance \(Int(s.trackMix(c).pan*100))").font(.caption)
                        Slider(value:Binding(get:{s.trackMix(c).pan},set:{s.setTrackPan(c,$0)}),in: -1...1,onEditingChanged:gesture).accessibilityLabel("Balance piste \(c+1)")
                        Button("Centrer") {s.setTrackPan(c,0)}
                    }.padding().frame(width:130).background(.quaternary,in:RoundedRectangle(cornerRadius:12)).disabled(!s.consoleActive || s.rendering)
                }}
            }
            HStack {
                Text("Général"); Slider(value:Binding(get:{s.mix.master},set:{value in s.editMix {$0.master = value}}),in:0...1,onEditingChanged:gesture).frame(maxWidth:350)
                Text(String(format:"%.0f %%",s.mix.master*100)).monospacedDigit()
                Button("Réinitialiser le mixage") {s.editMix {$0 = MixConfiguration(channels:s.module.channelCount)}}
            }.disabled(s.phase == .exporting)
            MasterStrip(meters:s.masterMeters)
            Text("Volumes, balances et niveau général sont enregistrés dans le projet Atelier. Muet et solo sont temporaires ; Muet est prioritaire sur Solo. Les commandes des pistes nécessitent la source Console.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            Text(s.status).font(.caption)
        }.padding(24).frame(width:940,height:690).onDisappear {s.endEditGesture()}
    }
    func gesture(_ editing: Bool) {if editing {s.beginEditGesture()} else {s.endEditGesture()}}
}
struct ConsoleTrackMeter: View {
    @ObservedObject var meters: TrackMeterState
    let channel: Int, muted: Bool
    var body: some View {TrackMeter(level:meters.level(for:channel),peak:meters.peak(for:channel),muted:muted).frame(width:24,height:110)}
}
struct MasterStrip: View {
    @ObservedObject var meters: MasterMeterState
    func db(_ x: Double) -> String {x > 0 ? String(format:"%.1f",20*log10(x)) : "−∞"}
    var body: some View {
        HStack(spacing:12) {
            Text("MASTER").font(.caption.bold())
            ProgressView(value:min(1,meters.left)).frame(width:90).accessibilityLabel("Niveau gauche")
            ProgressView(value:min(1,meters.right)).frame(width:90).accessibilityLabel("Niveau droit")
            Text("G \(db(meters.left))  D \(db(meters.right)) dBFS").font(.system(.caption,design:.monospaced)).frame(width:210,alignment:.leading)
            Button(meters.clipped ? "SATURATION · effacer" : "Crêtes OK") {meters.clipped = false}.foregroundStyle(meters.clipped ? .red : .secondary)
            Spacer()
        }.padding(.horizontal,20).padding(.vertical,6)
    }
}
struct MixExportView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Exporter l’audio").font(.title2.bold())
            Text("Écoute actuelle : \(s.consoleActive ? "Console" : "Original") · volume général appliqué.")
            Text("WAV stéréo float32, 44,1 kHz. Les crêtes ne sont pas écrêtées dans les fichiers ; baisse le niveau à l’écoute si nécessaire. Les pistes séparées partent toutes de zéro et finissent ensemble, sans queue d’effet ajoutée. Les DSP isolés peuvent différer des effets partagés du mix original.").foregroundStyle(.secondary)
            TextField("Nom de l’export",text:$s.exportName).textFieldStyle(.roundedBorder)
            HStack {Image(systemName:"folder"); TextField("Dossier de destination",text:$s.exportDirectory).textFieldStyle(.roundedBorder)}
                .dropDestination(for:URL.self) {urls,_ in
                    guard let url = urls.first, (try? url.resourceValues(forKeys:[.isDirectoryKey]).isDirectory) == true else {return false}
                    s.exportDirectory = url.path; return true
                }
            Text("Dépose un dossier du Finder ici, ou saisis son chemin. Les fichiers existants sont conservés.").font(.caption).foregroundStyle(.secondary)
            Button("Exporter le mixage complet") {s.chooseMixExport(separate:false)}
            Button("Exporter les pistes de la console") {s.chooseMixExport(separate:true)}.disabled(s.consoleCache == nil)
            if s.consoleCache == nil {Text("Prépare les pistes dans la console pour activer l’export séparé.").font(.caption)}
            Button("Fermer") {dismiss()}
        }.padding(28).frame(width:540).disabled(s.phase == .exporting || s.consolePreparing)
    }
}
