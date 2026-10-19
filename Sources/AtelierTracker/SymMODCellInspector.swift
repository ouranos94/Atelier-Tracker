import SwiftUI
import TrackerCore

/// Embedded beneath the main score, with the original source coordinates always visible.
struct SymMODCellInspector: View {
    @EnvironmentObject var s: Studio
    @State private var command: UInt8 = 0
    @State private var pitch = -1
    @State private var instrument = 0
    @State private var parameter = 0
    @State private var rate = 0
    @AppStorage("sym.inspector.expanded") private var showParameters = false
    private var effect: SymMODEffect {SymMODEffect(rawValue:command) ?? .note}
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {
                if let entry = s.selectedSymEntry, let cell = try? s.symArchive?.cell(in:entry,row:s.row,channel:s.channel) {
                    Text("SOURCE P\(cell.pattern) · L\(cell.row) · piste \(s.channel+1)").font(.system(size:10,weight:.semibold,design:.monospaced))
                    Text("position \(entry.position), séquence \(entry.sequence), transposition \(entry.transpose)").font(.caption).foregroundStyle(.secondary)
                } else {Text("Correspondance source non vérifiée · consultation seule").font(.caption)}
                Spacer()
                Button(showParameters ? "Réduire" : "Note et effet…") {showParameters.toggle()}
                Button("Écouter la note") {if let e = s.selectedSymEvent, e.command == 0, e.pitch >= 0 {s.auditionSymInstrument(Int(e.instrument),pitch:Int(e.pitch))}}.disabled(s.selectedSymEvent?.command != 0 || (s.selectedSymEvent?.pitch ?? -1) < 0 || s.playing)
            }
            if showParameters, let event = s.selectedSymEvent {
                if event.isEditableEvent && !event.isNoteStop {
                    ScrollView(.horizontal) {HStack {
                        Picker("Commande",selection:$command) {ForEach(SymMODEffect.allCases) {Text($0.title).tag($0.rawValue)}}.frame(width:230)
                        if effect == .note {
                            Picker("Note",selection:$pitch) {Text("—").tag(-1); ForEach(0...84,id:\.self) {Text(SymMODEvent(pitch:Int8($0)).pitchLabel).tag($0)}}.frame(width:120)
                            Stepper("Inst. \(instrument)",value:$instrument,in:0...max(0,min(255,(s.symArchive?.instrumentCount ?? 1)-1))).frame(width:130)
                        }
                        Stepper("\(effect == .note ? "Volume" : "Paramètre") \(parameter)",value:$parameter,in:0...effect.parameterMaximum).frame(width:150)
                        if effect.usesRate {Stepper("Vitesse \(rate)",value:$rate,in:0...120).frame(width:140)}
                        Spacer(minLength:0)
                        Button("Appliquer") {
                            let e = SymMODEvent(command:command,pitch:effect == .note ? Int8(pitch) : event.pitch,parameter:UInt8(parameter),instrument:effect == .note ? UInt8(instrument) : effect.usesRate ? UInt8(rate) : event.instrument)
                            s.editSelectedSymEvent(e)
                        }.buttonStyle(.borderedProminent)
                    }}.frame(height:36).disabled(!s.canCompose)
                    Text(effect.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                } else if event.isNoteStop {HStack {Text(event.summary).font(.caption);Button("Effacer l’arrêt") {s.editSelectedSymEvent(SymMODEvent())}.disabled(!s.canCompose)}} else {Text(event.summary+" · conservée ; édition et écrasement désactivés.").font(.caption).foregroundStyle(.secondary)}
            }
        }.padding(.horizontal,18).padding(.vertical,10)
        .onAppear {reload()}
        .onChange(of:s.selectedSymEvent) {_,_ in reload()}
        .onChange(of:command) {_,_ in parameter = min(parameter,effect.parameterMaximum); rate = min(rate,120)}
    }
    private func reload() {
        guard let e = s.selectedSymEvent else {return}
        command = e.command; pitch = Int(e.pitch); instrument = Int(e.instrument); parameter = Int(e.parameter); rate = Int(e.instrument)
    }
}
