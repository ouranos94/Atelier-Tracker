import SwiftUI
import TrackerCore

struct PianoRollView: View {
    @EnvironmentObject var s: Studio
    @State private var selected: PianoNote?
    @State private var draftRow = 0
    @State private var pitch = 36
    @State private var duration = 4
    @State private var volume = 100
    @State private var zoom = 22.0
    private let keyHeight = 16.0
    private var entry: SymMODOrderSource? {s.symEntry(at:s.scoreOrder)}
    private var notes: [PianoNote] {guard let doc = s.symArchive,let entry else {return []};return (try? PianoEditing.notes(doc,entry:entry,channel:s.channel)) ?? []}
    private var editable: Bool {s.canCompose && s.scoreOrder == s.order}
    var body: some View {
        VStack(spacing:8) {
            HStack {
                Picker("Piste",selection:$s.channel) {ForEach(0..<s.module.channelCount,id:\.self) {Text("\($0+1)").tag($0)}}.frame(width:130)
                Text("Durées : arrêt source FE · une ligne libre avant la fin").font(.caption).foregroundStyle(.secondary)
                Spacer();Text("Zoom").font(.caption);Slider(value:$zoom,in:12...44).frame(width:100)
            }.padding(.horizontal)
            if let entry {
                ScrollViewReader {proxy in
                    ScrollView([.horizontal,.vertical]) {
                        ZStack(alignment:.topLeading) {
                            Canvas {ctx,size in
                                for p in 0...84 {
                                    let y = Double(84-p)*keyHeight
                                    let black = [1,3,6,8,10].contains(p%12)
                                    ctx.fill(Path(CGRect(x:0,y:y,width:size.width,height:keyHeight)),with:.color(.primary.opacity(black ? 0.07 : 0.02)))
                                    if p%12 == 0 {ctx.draw(Text("C\(p/12+2)").font(.system(size:9)),at:CGPoint(x:16,y:y+8))}
                                }
                                for r in 0...entry.length {
                                    let x = 40+Double(r)*zoom
                                    ctx.stroke(Path {p in p.move(to:CGPoint(x:x,y:0));p.addLine(to:CGPoint(x:x,y:size.height))},with:.color(.primary.opacity(r%4 == 0 ? 0.2 : 0.06)),lineWidth:1)
                                }
                                if s.scoreOrder == s.order {ctx.fill(Path(CGRect(x:40+Double(s.row)*zoom,y:0,width:zoom,height:size.height)),with:.color(.mint.opacity(0.08)))}
                                if s.scoreOrder == s.playbackOrder && (s.playing || s.paused) {
                                    let x = 40+Double(s.playbackRow)*zoom
                                    ctx.fill(Path(CGRect(x:x,y:0,width:2,height:size.height)),with:.color(.orange))
                                }
                            }.contentShape(Rectangle()).onTapGesture {point in
                                guard editable else {return};selected = nil
                                draftRow = max(0,min(entry.length-2,Int((point.x-40)/zoom)));pitch = max(0,min(84,84-Int(point.y/keyHeight)))
                                duration = max(1,min(duration,entry.length-draftRow-1));s.selectCell(order:s.order,row:draftRow,channel:s.channel)
                            }
                            ForEach(notes) {note in noteView(note)}
                            VStack(spacing:0) {ForEach(Array((0...84).reversed()),id:\.self) {p in Color.clear.frame(width:1,height:keyHeight).id(p)}}.allowsHitTesting(false)
                        }.frame(width:40+Double(entry.length)*zoom,height:85*keyHeight)
                    }.task {syncCursor();await Task.yield();proxy.scrollTo(pitch,anchor:.center)}
                    .onChange(of:s.module.symphonie?.playbackSource) {_,_ in proxy.scrollTo(pitch,anchor:.center)}
                }
                HStack(spacing:10) {
                    Stepper("Ligne \(draftRow)",value:$draftRow,in:0...max(0,entry.length-2))
                    Stepper("Note \(pitch)",value:$pitch,in:0...84)
                    Stepper("Durée \(duration)",value:$duration,in:1...max(1,entry.length-1))
                    Stepper("Vol. \(volume)",value:$volume,in:1...100)
                    Button(selected == nil ? "Ajouter" : "Appliquer") {write(old:selected,row:draftRow,pitch:pitch,duration:duration)}
                    Button("Effacer") {remove()}.disabled(selected == nil)
                }.font(.caption).padding(10).disabled(!editable)
                Text("Clic : choisir une case · glisser une note : déplacer · glisser son bord droit : durée · instrument source \(s.sample). Les commandes et chevauchements sont protégés.").font(.caption2).foregroundStyle(.secondary).padding(.horizontal)
            } else {ContentUnavailableView("Correspondance source indisponible",systemImage:"pianokeys",description:Text("Cette position n’a pas de correspondance vérifiée avec le fichier SymMOD."))}
        }.onChange(of:s.row) {_,_ in if selected?.row != s.row {selected = nil;syncCursor()}}
        .onChange(of:s.channel) {_,_ in selected = nil;syncCursor()}.onChange(of:s.order) {_,_ in selected = nil}
        .onChange(of:s.module.symphonie?.playbackSource) {_,_ in selected = nil}
    }
    private func noteView(_ note: PianoNote) -> some View {
        HStack(spacing:0) {
            Text("\(note.pitch)").font(.system(size:10,design:.monospaced)).padding(.leading,4).frame(maxWidth:.infinity,alignment:.leading)
                .contentShape(Rectangle()).onTapGesture {choose(note)}
                .gesture(DragGesture().onEnded {v in
                    guard editable else {return}
                    write(old:note,row:note.row+Int((v.translation.width/zoom).rounded()),pitch:note.pitch-Int((v.translation.height/keyHeight).rounded()),duration:note.duration)
                })
            Rectangle().fill(.white.opacity(0.6)).frame(width:5).contentShape(Rectangle())
                .gesture(DragGesture().onEnded {v in if editable {write(old:note,row:note.row,pitch:note.pitch,duration:note.duration+Int((v.translation.width/zoom).rounded()))}})
                .help("Glisser pour changer la durée")
        }.foregroundStyle(.black).frame(width:max(10,Double(note.duration)*zoom-2),height:keyHeight-2)
            .background(selected == note ? Color.orange : Color.mint,in:RoundedRectangle(cornerRadius:3))
            .offset(x:40+Double(note.row)*zoom,y:Double(84-note.pitch)*keyHeight+1)
            .accessibilityLabel("Note \(note.pitch), ligne \(note.row), durée \(note.duration), instrument \(note.instrument)")
    }
    private func syncCursor() {draftRow = s.row;if let e = s.selectedSymEvent,e.isEditableNote,e.pitch >= 0 {pitch = Int(e.pitch)}}
    private func choose(_ note: PianoNote) {selected = note;draftRow = note.row;pitch = note.pitch;duration = note.duration;volume = max(1,note.volume);s.selectCell(order:s.scoreOrder,row:note.row,channel:s.channel);s.sample = min(note.instrument,s.module.samples.count-1)}
    private func write(old: PianoNote?,row: Int,pitch: Int,duration: Int) {
        guard editable,let doc = s.symArchive,let entry else {return}
        do {
            let edits = try PianoEditing.edits(doc,entry:entry,channel:s.channel,replacing:old,row:row,pitch:pitch,duration:duration,instrument:old?.instrument ?? s.sample,volume:volume)
            if s.applySymEvents(edits,title:"Note piano-roll modifiée") {s.selectCell(order:s.order,row:row,channel:s.channel);selected = nil}
        } catch {s.error = error.localizedDescription}
    }
    private func remove() {
        guard let selected,let doc = s.symArchive,let entry else {return}
        do {_ = s.applySymEvents(try PianoEditing.deleting(doc,entry:entry,channel:s.channel,note:selected),title:"Note piano-roll effacée");self.selected = nil}
        catch {s.error = error.localizedDescription}
    }
}
