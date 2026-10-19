import SwiftUI
import TrackerCore

struct MIDITake {
    let source: Data,entry: SymMODOrderSource,order: Int,channel: Int,instrument: Int
    var notes: [MIDIGridNote] = []
    var active: (note: Int,row: Int,velocity: Int)?
}
@MainActor extension Studio {
    func configureMIDI(enabled: Bool) {
        midiInput.stop();midiLivePlayer?.stop();midiLivePlayer = nil;midiActiveNote = nil
        midiEnabled = false
        guard enabled else {return}
        do {
            midiInput.receive = {[weak self] event in Task {@MainActor in self?.handleMIDI(event)}}
            try midiInput.start(source:midiSource == 0 ? nil : midiSource)
            midiEnabled = true;status = "Entrée MIDI active · piste \(channel+1)"
        } catch {self.error = error.localizedDescription}
    }
    func invalidateMIDIVoice() {midiLivePlayer?.stop();midiLivePlayer = nil;midiActiveNote = nil}
    func handleMIDI(_ event: MIDINoteEvent) {
        guard midiEnabled,(midiChannel == 0 || midiChannel == event.channel) else {return}
        midiLastEvent = "Canal \(event.channel) · note \(event.note) · vélocité \(event.velocity)"
        if !event.on {
            if midiTake?.active?.note == event.note {finishMIDINote()}
            if midiActiveNote == event.note {midiLivePlayer?.voice.noteOff();if !isSymphonie {stopSamplePreview()};midiActiveNote = nil};return
        }
        guard !rendering,!consolePreparing else {return}
        let pitch = event.note-24
        guard (0...84).contains(pitch) else {status = "Note hors plage Symphonie : MIDI 24…108";return}
        if midiTake != nil {
            finishMIDINote()
            if playing,playbackOrder == midiTake?.order {
                guard (midiTake?.notes.count ?? 0) < 256 else {status = "Prise MIDI : limite de 256 notes";return}
                midiTake?.active = (event.note,quantizedMIDIRow(),event.velocity)
            }
        } else if midiStepEntry && !playing && !paused && !symSourceSheetPresented {
            if isSymphonie,let doc = symArchive,let entry = selectedSymEntry {
                do {
                    let start = MIDIEditing.quantize(Double(row),step:midiQuantization)
                    let end = min(entry.length-1,start+max(1,midiQuantization))
                    let edits = try MIDIEditing.edits(doc,entry:entry,channel:channel,instrument:sample,notes:[MIDIGridNote(row:start,end:end,pitch:pitch,velocity:event.velocity)])
                    if applySymEvents(edits,title:"Note MIDI saisie") {selectCell(order:order,row:min(rows-1,end+1),channel:channel)}
                } catch {self.error = error.localizedDescription}
            } else if !isSymphonie,(36...71).contains(event.note) {
                var n = note;n.period = Note.periods[event.note-36];n.sample = sample+1;n.effect = 12;n.parameter = max(1,Int((Double(event.velocity)*64/127).rounded()))
                setNote(n);selectCell(order:order,row:min(63,row+max(1,midiQuantization)),channel:channel)
            }
        }
        do {
            if isSymphonie {
                if midiLivePlayer == nil {midiLivePlayer = try MIDILivePlayer(module)}
                try midiLivePlayer?.voice.noteOn(instrument:midiTake?.instrument ?? sample,pitch:pitch,velocity:event.velocity)
            } else if (36...71).contains(event.note),!playing {
                preview(period:Note.periods[event.note-36]);previewPlayer?.volume = Float(event.velocity)/127
            }
            midiActiveNote = event.note
        } catch {status = "MIDI : \(error.localizedDescription)"}
    }
    func quantizedMIDIRow() -> Int {
        guard let timeline = preparedAudio,let marker = timeline.position(at:clock.elapsed) else {return MIDIEditing.quantize(Double(playbackRow),step:midiQuantization)}
        let time = clock.elapsed
        let next = timeline.result.markers.drop(while:{$0.time <= marker.time}).first
        let fraction = next.map {max(0,min(1,(time-marker.time)/max(0.001,$0.time-marker.time)))} ?? 0
        return MIDIEditing.quantize(Double(marker.row)+fraction,step:midiQuantization)
    }
    func finishMIDINote() {
        guard var take = midiTake,let active = take.active else {return}
        let end = playbackOrder == take.order ? quantizedMIDIRow() : take.entry.length-1
        let stop = min(take.entry.length-1,max(active.row+1,end))
        if stop > active.row {take.notes.append(MIDIGridNote(row:active.row,end:stop,pitch:active.note-24,velocity:active.velocity))}
        take.active = nil;midiTake = take
    }
    func beginMIDITake() {
        guard midiEnabled,isSymphonie,let source = module.symphonie?.playbackSource,let entry = selectedSymEntry,!rendering,!consolePreparing else {return}
        midiTake = MIDITake(source:source,entry:entry,order:order,channel:channel,instrument:sample)
        loopMode = .off;playFromSelection();status = "Prise MIDI · position \(order) · terminer pour appliquer"
    }
    func endMIDITake(apply: Bool) {
        finishMIDINote();guard let take = midiTake else {return};midiTake = nil
        stop();invalidateMIDIVoice()
        guard apply else {status = "Prise MIDI annulée";return}
        guard module.symphonie?.playbackSource == take.source,let doc = symArchive else {error = "Le morceau a changé : prise MIDI non appliquée.";return}
        do {
            let edits = try MIDIEditing.edits(doc,entry:take.entry,channel:take.channel,instrument:take.instrument,notes:take.notes)
            _ = applySymEvents(edits,title:"Prise MIDI quantifiée · \(take.notes.count) notes")
        } catch {self.error = error.localizedDescription}
    }
}
struct MIDISettingsView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var sources = MIDIInput.sources()
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("Clavier MIDI").font(.title2.bold());Spacer();Button("Fermer") {dismiss()}}
            Toggle("Activer l’entrée MIDI",isOn:Binding(get:{s.midiEnabled},set:{s.configureMIDI(enabled:$0)}))
            HStack {
                Picker("Source",selection:$s.midiSource) {Text("Toutes les sources").tag(UInt32(0));ForEach(sources) {Text($0.name).tag($0.id)}}
                Button("Actualiser") {sources = MIDIInput.sources();if s.midiEnabled {s.configureMIDI(enabled:true)}}
            }
            Picker("Canal MIDI",selection:$s.midiChannel) {Text("Tous").tag(0);ForEach(1...16,id:\.self) {Text("\($0)").tag($0)}}
            Picker("Quantification",selection:$s.midiQuantization) {ForEach([1,2,4,8],id:\.self) {Text("\($0) ligne(s)").tag($0)}}.disabled(s.midiTake != nil)
            Toggle("Saisie pas à pas à l’arrêt",isOn:$s.midiStepEntry)
            Text("Instrument source \(s.sample+(s.isSymphonie ? 0 : 1)) · piste \(s.channel+1) · jeu monophonique, vélocité → volume. MIDI 24…108 en SymMOD ; 36…71 en MOD.").font(.caption).foregroundStyle(.secondary)
            Divider()
            if s.midiTake != nil {
                Text("Prise en cours : \(s.midiTake?.notes.count ?? 0) notes. Seule la position sélectionnée est enregistrée.")
                HStack {Button("Annuler la prise") {s.endMIDITake(apply:false)};Button("Terminer et appliquer") {s.endMIDITake(apply:true)}.buttonStyle(.borderedProminent)}
            } else {
                Button("Enregistrer une prise SymMOD") {s.beginMIDITake()}.disabled(!s.midiEnabled || !s.isSymphonie || s.selectedSymEntry == nil || s.rendering || s.consolePreparing)
                Text("La prise suit la position sélectionnée, sans boucle. Terminer arrête le transport et applique toutes les notes en une seule opération annulable. Un conflit avec des notes ou commandes existantes refuse toute la prise.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {Text(s.midiLastEvent).monospaced().font(.caption);Spacer();Button("Couper les notes") {s.invalidateMIDIVoice();s.stopSamplePreview()}}
            Text("Après branchement d’un clavier, utilise Actualiser. L’entrée reste active en fermant ce panneau.").font(.caption).foregroundStyle(.secondary)
        }.padding(26).frame(width:580).symEditorSurface().symMODErrorAlert(s)
        .onChange(of:s.midiSource) {_,_ in if s.midiEnabled {s.configureMIDI(enabled:true)}}
    }
}
