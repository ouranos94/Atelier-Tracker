import SwiftUI
import TrackerCore

struct SymPCMEditorView: View {
    @EnvironmentObject var s: Studio
    let index: Int
    @State private var importVisible = false
    @State private var importPath = ""
    @State private var pcm: SymPCM?
    @State private var problem: String?
    @State private var start = 0
    @State private var end = 0
    @State private var loadedSource: Data?
    private var unlocked: Bool {!s.playing && !s.rendering && !s.consolePreparing && loadedSource == s.module.symphonie?.playbackSource}
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {Text("SAMPLE PCM SOURCE").font(.caption.bold());Spacer();Button("Importer / remplacer…") {importVisible.toggle()}.disabled(!unlocked)}
            if importVisible {
                TextField("Chemin WAV / AIFF, ou déposer un fichier ici",text:$importPath).textFieldStyle(.roundedBorder)
                HStack {Text("Conversion mono 16 bits / 40 460 Hz, 60 s maximum. Accord et boucle réinitialisés.").font(.caption).foregroundStyle(.secondary);Spacer();Button("Importer ce fichier") {importFile(URL(fileURLWithPath:(importPath as NSString).expandingTildeInPath))}.disabled(!unlocked || importPath.isEmpty)}
            }
            if let pcm {
                Text("\(pcm.samples.count) points · \(pcm.originalBits) bits · référence C5 : 40 460 Hz").font(.caption).foregroundStyle(.secondary)
                GeometryReader {g in
                    Canvas {ctx,size in
                        let count = pcm.samples.count, width = max(1,Int(size.width))
                        var path = Path()
                        for x in 0..<width {
                            let a = x*count/width,b = min(count,max(a+1,(x+1)*count/width))
                            guard a < b else {continue}
                            let values = pcm.samples[a..<b], lo = Double(values.min() ?? 0)/32768,hi = Double(values.max() ?? 0)/32768
                            path.move(to:CGPoint(x:Double(x),y:size.height*(1-hi)/2));path.addLine(to:CGPoint(x:Double(x),y:size.height*(1-lo)/2))
                        }
                        ctx.stroke(path,with:.color(.mint),lineWidth:1)
                        let x = Double(start)/Double(max(1,count))*size.width,w = Double(end-start)/Double(max(1,count))*size.width
                        ctx.fill(Path(CGRect(x:x,y:0,width:w,height:size.height)),with:.color(.orange.opacity(0.2)))
                        ctx.stroke(Path(CGRect(x:x,y:0,width:w,height:size.height)),with:.color(.orange),lineWidth:1)
                    }.background(.primary.opacity(0.04)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:0).onChanged {value in
                        let n = pcm.samples.count
                        let a = max(0,min(n-1,Int(value.startLocation.x/max(1,g.size.width)*Double(n))))
                        let b = max(0,min(n,Int(value.location.x/max(1,g.size.width)*Double(n))))
                        start = min(a,b);end = max(start+1,max(a,b))
                    })
                }.frame(height:125).accessibilityLabel("Forme d’onde PCM, glisser pour sélectionner la boucle")
                HStack {Stepper("Début \(start)",value:$start,in:0...max(0,end-1));Stepper("Fin \(end)",value:$end,in:min(pcm.samples.count,start+1)...pcm.samples.count)}.font(.caption)
                HStack {
                    Button("Écouter sélection") {s.previewPCM(pcm,range:start..<end,loop:false)}
                    Button("Écouter boucle") {s.previewPCM(pcm,range:start..<end,loop:true)}
                    Button("Arrêter") {s.stopSamplePreview()}
                    Spacer()
                    Button("Définir la boucle") {applyLoop(pcm)}.disabled(!unlocked)
                }.controlSize(.small)
                Text("Glisse sur la forme d’onde pour définir les limites, puis applique la boucle. La préécoute PCM n’inclut ni accord ni DSP.").font(.caption).foregroundStyle(.secondary)
            } else {Text(problem ?? "Emplacement vide : importe un WAV ou AIFF.").font(.caption).foregroundStyle(.secondary)}
        }.dropDestination(for:URL.self) {urls,_ in guard unlocked,let url = urls.first else {return false};importFile(url);return true}
        .task(id:LoadKey(index:index,source:s.module.symphonie?.playbackSource)) {load()}
        .onDisappear {s.stopSamplePreview()}
    }
    private func importFile(_ url: URL) {
        do {try s.importSymPCM(url:url,index:index);importVisible = false} catch {s.error = error.localizedDescription}
    }
    private struct LoadKey: Equatable {let index: Int;let source: Data?}
    private func load() {
        pcm = nil;problem = nil;loadedSource = s.module.symphonie?.playbackSource
        do {
            guard let doc = s.symArchive else {return};pcm = try doc.pcm(index)
            start = 0;end = pcm?.samples.count ?? 0
            if let ins = try? doc.instrument(index),ins.loop.enabled,let pcm {
                start = min(pcm.samples.count-1,Int(Double(ins.loop.start)/6553600*Double(pcm.samples.count)))
                end = min(pcm.samples.count,max(start+1,start+Int(Double(ins.loop.length)/6553600*Double(pcm.samples.count))))
            }
        } catch {problem = error.localizedDescription}
    }
    private func applyLoop(_ pcm: SymPCM) {
        guard let source = loadedSource,let ins = try? s.symArchive?.instrument(index),!pcm.samples.isEmpty else {return}
        var settings = ins.settings
        settings.loop = SymMODLoop(enabled:true,start:Int((Double(start)*6553600/Double(pcm.samples.count)).rounded()),length:Int((Double(end-start)*6553600/Double(pcm.samples.count)).rounded(.down)))
        s.editSymInstrument(index,edit:settings,expectedSource:source)
    }
}
