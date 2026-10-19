import SwiftUI
import TrackerCore

struct SampleLabView: View {
    @EnvironmentObject private var s: Studio
    @Environment(\.colorScheme) private var scheme
    @State private var expanded = false
    private var palette: StudioPalette {StudioPalette(scheme:scheme)}
    var body: some View {
        VStack(spacing:9) {
            HStack {
                Text("SAMPLE LAB").font(.system(size:9,weight:.semibold)).foregroundStyle(palette.secondary)
                Text(s.currentSample.name.isEmpty ? "Sample vide" : s.currentSample.name).font(.system(size:12)).lineLimit(1)
                Spacer()
                Button("Éditer") {expanded = true}.help("Ouvrir l’éditeur de samples")
                Button {s.previewSample()} label:{Image(systemName:"play.fill")}.help("Écouter la sélection ou tout le sample à C-3").disabled(s.sampleRegion == nil || !s.canEditSamples)
                Button {s.stopSamplePreview()} label:{Image(systemName:"stop.fill")}.help("Arrêter la préécoute").disabled(!s.samplePreviewing)
                Button("Importer…") {s.importSample()}
            }.buttonStyle(.plain)
            SampleWaveView().frame(height:78)
            HStack {
                Text("MONO · 8 BITS · \(s.currentSample.data.count) points")
                Spacer()
                Text("C-3 · 16 574 Hz · \(String(format:"%.3f",Double(s.currentSample.data.count)/SampleEditing.referenceRate)) s")
            }.font(.system(size:9,design:.monospaced)).foregroundStyle(palette.secondary)
        }.padding(18).background(palette.panel)
            .sheet(isPresented:$expanded) {SampleEditorWorkspace().environmentObject(s)}
    }
}
struct SampleWaveView: View {
    @EnvironmentObject private var s: Studio
    @Environment(\.colorScheme) private var scheme
    @AppStorage("keyboard.layout") private var keyboardLayout = MusicalKeyboard.qwerty.rawValue
    @State private var loopDragPoint: Int?
    @FocusState private var waveFocused: Bool
    private var palette: StudioPalette {StudioPalette(scheme:scheme)}
    var body: some View {
        GeometryReader { geometry in
            let sample = s.currentSample
            let viewport = SampleViewport(length:sample.data.count,zoom:s.sampleZoom,offset:s.sampleViewOffset)
            ZStack(alignment:.topLeading) {
                Canvas {context,size in
                    let center = size.height/2
                    context.fill(Path(CGRect(x:0,y:center,width:size.width,height:1)),with:.color(palette.secondary.opacity(0.3)))
                    if let selected = s.sampleSelection {
                        let x = max(0,viewport.x(for:selected.start,width:size.width)), end = min(size.width,viewport.x(for:selected.end,width:size.width))
                        if end > x {context.fill(Path(CGRect(x:x,y:0,width:end-x,height:size.height)),with:.color(palette.accent.opacity(0.18)))}
                    }
                    if sample.loopLength > 2 {
                        let x = max(0,viewport.x(for:sample.loopStart,width:size.width)), end = min(size.width,viewport.x(for:sample.loopStart+sample.loopLength,width:size.width))
                        if end > x {context.fill(Path(CGRect(x:x,y:0,width:end-x,height:12)),with:.color(palette.effect.opacity(0.4)))}
                    }
                    guard viewport.end > viewport.start, size.width > 0 else {return}
                    var path = Path()
                    let pixels = max(1,Int(size.width))
                    for pixel in 0..<pixels {
                        let from = viewport.start+pixel*(viewport.end-viewport.start)/pixels
                        let end = min(viewport.end,max(from+1,viewport.start+(pixel+1)*(viewport.end-viewport.start)/pixels))
                        guard from < end else {continue}
                        let samples = sample.data[from..<end]
                        let low = Double(samples.min() ?? 0)/128, high = Double(samples.max() ?? 0)/128
                        path.move(to:CGPoint(x:Double(pixel),y:center-low*(center-14)))
                        path.addLine(to:CGPoint(x:Double(pixel),y:center-high*(center-14)+1))
                    }
                    context.stroke(path,with:.color(palette.accent),lineWidth:1)
                }.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:0).onChanged {value in
                        guard s.canEditSamples else {return}
                        waveFocused = true
                        let a = viewport.point(at:value.startLocation.x,width:geometry.size.width)
                        let b = viewport.point(at:value.location.x,width:geometry.size.width)
                        s.selectSampleRegion(start:min(a,b),end:min(sample.data.count,max(a,b)+2))
                    })
                if sample.loopLength > 2 {
                    marker(point:sample.loopStart,isStart:true,viewport:viewport,size:geometry.size)
                    marker(point:sample.loopStart+sample.loopLength,isStart:false,viewport:viewport,size:geometry.size)
                }
                if sample.data.isEmpty {Text("Importe un WAV / AIFF pour créer un sample").font(.caption).foregroundStyle(palette.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)}
            }.background(palette.background).clipped()
        }.focusable().focused($waveFocused).focusEffectDisabled()
            .onKeyPress {press in
                guard press.modifiers.isEmpty, s.canEditSamples,
                      let note = (MusicalKeyboard(rawValue:keyboardLayout) ?? .qwerty).note(for:press.characters) else {return .ignored}
                let index = (s.octave-1)*12+note
                guard Note.periods.indices.contains(index) else {return .handled}
                s.previewSample(period:Note.periods[index],noteAudition:s.sampleSelection == nil); return .handled
            }
            .accessibilityElement(children:.contain)
            .accessibilityLabel("Forme d’onde du sample. Sélectionner une plage par glissement ou avec les contrôles de début et de fin dans l’éditeur.")
    }
    @ViewBuilder func marker(point: Int,isStart: Bool,viewport: SampleViewport,size: CGSize) -> some View {
        if point >= viewport.start && point <= viewport.end {
            let x = viewport.x(for:point,width:size.width)
            VStack(spacing:0) {
                Text(isStart ? "A" : "B").font(.system(size:9,weight:.bold)).frame(width:16,height:16).background(palette.effect)
                Rectangle().fill(palette.effect).frame(width:1)
            }.foregroundStyle(palette.background).frame(width:16,height:size.height)
                .contentShape(Rectangle()).offset(x:min(max(0,x-8),max(0,size.width-16)))
                .gesture(DragGesture(minimumDistance:0).onChanged {value in
                    guard s.canEditSamples else {return}
                    if loopDragPoint == nil {loopDragPoint = point; s.beginEditGesture()}
                    let origin = viewport.x(for:loopDragPoint ?? point,width:size.width)
                    let candidate = viewport.point(at:origin+value.translation.width,width:size.width)/2*2
                    if isStart {s.setSampleLoop(start:min(candidate,s.currentSample.loopStart+s.currentSample.loopLength-4),end:s.currentSample.loopStart+s.currentSample.loopLength)}
                    else {s.setSampleLoop(start:s.currentSample.loopStart,end:max(candidate,s.currentSample.loopStart+4))}
                }.onEnded {_ in loopDragPoint = nil; s.endEditGesture()})
                .accessibilityElement().accessibilityLabel(isStart ? "Début de boucle" : "Fin de boucle")
                .accessibilityValue("\(point) points")
                .accessibilityAdjustableAction {direction in
                    let next = point+(direction == .increment ? 2 : -2)
                    s.endEditGesture()
                    if isStart {s.setSampleLoop(start:min(max(0,next),s.currentSample.loopStart+s.currentSample.loopLength-4),end:s.currentSample.loopStart+s.currentSample.loopLength)}
                    else {s.setSampleLoop(start:s.currentSample.loopStart,end:min(s.currentSample.data.count,max(next,s.currentSample.loopStart+4)))}
                }
        }
    }
}
struct SampleEditorWorkspace: View {
    @EnvironmentObject private var s: Studio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private var palette: StudioPalette {StudioPalette(scheme:scheme)}
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text("Éditeur de samples").font(.title2.bold())
                Text(s.currentSample.name.isEmpty ? "Sample \(s.sample+1)" : s.currentSample.name).foregroundStyle(palette.secondary)
                Spacer(); Button("Fermer") {s.stopSamplePreview(); dismiss()}
            }.padding(18)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    HStack {
                        Text("Mono · signé 8 bits · \(s.currentSample.data.count) points · C-3 ≈ 16 574 Hz")
                        Spacer()
                        Button("Écouter") {s.previewSample()}.disabled(s.sampleRegion == nil)
                        Button("Écouter la boucle") {s.previewSample(loop:true)}.disabled(s.currentSample.loopLength < 4)
                        Button("Arrêter") {s.stopSamplePreview()}.disabled(!s.samplePreviewing)
                    }.font(.caption)
                    SampleWaveView().frame(height:180)
                    HStack {
                        Text("Zoom \(Int(s.sampleZoom))×").frame(width:80,alignment:.leading)
                        Slider(value:$s.sampleZoom,in:1...64,step:1).accessibilityLabel("Zoom de la forme d’onde")
                        Button("Vue entière") {s.sampleZoom = 1; s.sampleViewOffset = 0}
                        Text("Défilement")
                        Slider(value:$s.sampleViewOffset,in:0...1).accessibilityLabel("Position dans le sample").disabled(s.sampleZoom <= 1)
                    }.font(.caption)
                    selectionControls
                    HStack {
                        ForEach(SampleOperation.allCases) {operation in
                            Button(operation.title) {s.editSample(operation)}
                                .disabled(s.sampleRegion == nil || ((operation == .trim || operation == .delete) && s.sampleSelection == nil))
                        }
                    }.controlSize(.small)
                    Divider()
                    loopControls
                    Text(s.recoveryStatus).font(.caption).foregroundStyle(palette.secondary)
                    Text("Glisse dans la forme d’onde pour sélectionner ; les limites sont paires et la fin est exclue. Les poignées orange A/B règlent la boucle du sample (4 points minimum). Cliquer la forme d’onde puis jouer au clavier écoute sans enregistrer de note dans le pattern.").font(.caption).foregroundStyle(palette.secondary)
                    Text("Le MOD contient des points mono signés sur 8 bits, sans fréquence fixe. La durée est donnée à C-3 (horloge PAL, avant finetune). L’import WAV/AIFF convertit en mono 8 bits à 16 574 Hz et limite à 131 070 points, soit environ 7,91 s. La source reste intacte. Découper enlève des données du projet ; ⌘Z les restitue.").font(.caption).foregroundStyle(palette.secondary)
                }.padding(18).disabled(!s.canEditSamples)
            }
        }.frame(width:1000,height:660).background(palette.panel).foregroundStyle(palette.text)
            .onAppear {s.sampleEditorOpen = true}
            .onDisappear {s.sampleEditorOpen = false; s.endEditGesture(); s.stopSamplePreview()}
            .onChange(of:s.isSymphonie) {_,isSymphonie in if isSymphonie {dismiss()}}
    }
    @ViewBuilder var selectionControls: some View {
        if let range = s.sampleRegion {
            HStack {
                Stepper("Début \(range.start)",value:Binding(get:{range.start},set:{s.selectSampleRegion(start:$0,end:range.end)}),in:0...max(0,range.end-2),step:2)
                Stepper("Fin \(range.end)",value:Binding(get:{range.end},set:{s.selectSampleRegion(start:range.start,end:$0)}),in:min(range.start+2,s.currentSample.data.count)...s.currentSample.data.count,step:2)
                Text("\(range.count) points · \(String(format:"%.2f",Double(range.count)/SampleEditing.referenceRate*1000)) ms").monospacedDigit()
                Button("Tout") {s.selectSampleRegion(start:0,end:s.currentSample.data.count)}
                Button("Désélectionner") {s.sampleSelection = nil}
            }.font(.caption)
        } else {Text("Sample vide : importe un fichier audio depuis Sample Lab.").font(.caption).foregroundStyle(palette.secondary)}
    }
    var loopControls: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("Boucle du sample").font(.headline)
                Button("Boucler la sélection") {s.loopSampleSelection()}.disabled((s.sampleRegion?.count ?? 0) < 4)
                Button("Désactiver") {s.disableSampleLoop()}.disabled(s.currentSample.loopLength < 4)
            }
            if s.currentSample.loopLength >= 4 {
                let start = s.currentSample.loopStart, end = start+s.currentSample.loopLength
                HStack {
                    Stepper("A · \(start)",value:Binding(get:{start},set:{s.setSampleLoop(start:$0,end:end)}),in:0...max(0,end-4),step:2)
                    Stepper("B · \(end)",value:Binding(get:{end},set:{s.setSampleLoop(start:start,end:$0)}),in:min(start+4,s.currentSample.data.count)...s.currentSample.data.count,step:2)
                    Text("\(s.currentSample.loopLength) points").monospacedDigit()
                }.font(.caption)
            }
        }
    }
}
