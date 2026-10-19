import SwiftUI
import AVFoundation
import TrackerCore

@MainActor extension Studio {
    var canExpandSym: Bool {symArchive.map(SymMODComposer.canExpand) == true && !playing && !rendering && !consolePreparing}
    func symOccurrences(_ pattern: Int) -> Int {module.symphonie?.orderSource?.compactMap {$0}.filter {$0.pattern == pattern}.count ?? 0}
    @discardableResult func commitSymModule(_ changed: Module,title: String) throws -> Bool {
        guard isSymphonie, !playing, !rendering, !consolePreparing else {throw ModuleError.invalid("Arrête la lecture avant de modifier le morceau.")}
        try validate(changed);guard changed != module else {return false}
        endEditGesture();let previous = editorSnapshot;stop(clearCache:true)
        undoStack.append(previous);if undoStack.count > 80 {undoStack.removeFirst()};redoStack.removeAll()
        module = changed;order = min(order,module.orders.count-1);row = min(row,rows-1);sample = min(sample,module.samples.count-1)
        block = nil;clock.duration = changed.symphonie?.duration ?? 0
        hasChanges = true;scheduleRecovery();status = title;return true
    }
    func createSymSong(title: String,channels: Int,rows: Int,instruments: Int,bpm: Int) {
        do {
            let fresh = try SymMODComposer.create(title:title,channels:channels,rows:rows,instruments:instruments,bpm:bpm)
            if newSymPresented && hasChanges {
                newSymPresented = false
                Task {try? await Task.sleep(nanoseconds:350_000_000);guard confirmDiscard() else {return};finishSymCreation(fresh)}
            } else {guard confirmDiscard() else {return};finishSymCreation(fresh)}
        } catch {self.error = error.localizedDescription}
    }
    private func finishSymCreation(_ fresh: Module) {
        replaceModule(with:fresh);fileURL = nil;undoStack = [];redoStack = [];hasChanges = true
        newSymPresented = false;symScoreSource = true;status = "Nouveau SymMOD · \(fresh.channelCount) pistes";scheduleRecovery()
    }
    func appendSymPosition(duplicate: Bool = false,reuse: Bool = false) {
        guard canExpandSym else {return}
        do {
            let p = duplicate || reuse ? selectedSymEntry?.pattern : nil
            let fresh = try SymMODComposer.append(in:module,pattern:p,duplicate:duplicate)
            if try commitSymModule(fresh,title:reuse ? "Pattern partagé ajouté à l’arrangement" : "Pattern ajouté à l’arrangement") {order = module.orders.count-1;row = 0}
        } catch {self.error = error.localizedDescription}
    }
    func removeSymPosition() {
        guard canExpandSym, let entry = selectedSymEntry else {return}
        do {_ = try commitSymModule(SymMODComposer.removePosition(in:module,index:entry.position),title:"Position supprimée · patterns conservés")}
        catch {self.error = error.localizedDescription}
    }
    func importSymPCM(url: URL,index: Int) throws {
        guard !playing, !rendering, !consolePreparing else {throw ModuleError.invalid("Arrête la lecture avant l’import du sample.")}
        let pcm = try AudioImport.pcm(url)
        _ = try commitSymModule(SymphonieDecoder.replacingPCM(in:module,index:index,pcm:pcm,name:url.deletingPathExtension().lastPathComponent),title:"Sample source \(index) importé · mono 16 bits · 40 460 Hz")
        stopSamplePreview()
    }
    func previewPCM(_ pcm: SymPCM,range: Range<Int>,loop: Bool) {
        do {
            stopSamplePreview();let player = try AVAudioPlayer(data:pcm.wav(range:range));player.numberOfLoops = loop ? -1 : 0
            guard player.play() else {throw ModuleError.invalid("Préécoute indisponible.")};previewPlayer = player;samplePreviewing = true
        } catch {self.error = error.localizedDescription}
    }
}

enum AudioImport {
    static func pcm(_ url: URL) throws -> SymPCM {
        let file = try AVAudioFile(forReading:url)
        let format = file.processingFormat
        guard format.sampleRate.isFinite, format.sampleRate > 0, file.length > 0, file.length <= Int64(format.sampleRate*60),file.length <= 12_000_000,format.channelCount <= 8,
              let input = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(file.length)),
              let target = AVAudioFormat(commonFormat:.pcmFormatFloat32,sampleRate:40460,channels:1,interleaved:false),
              let converter = AVAudioConverter(from:format,to:target) else {throw ModuleError.invalid("Audio requis : 60 secondes maximum, jusqu’à 8 canaux et 12 millions de trames.")}
        try file.read(into:input)
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength)*40460/format.sampleRate)+256)
        guard let output = AVAudioPCMBuffer(pcmFormat:target,frameCapacity:capacity) else {throw ModuleError.invalid("Conversion audio indisponible.")}
        var supplied = false, failure: NSError?
        let result = converter.convert(to:output,error:&failure) {_,status in
            if supplied {status.pointee = .endOfStream;return nil};supplied = true;status.pointee = .haveData;return input
        }
        guard result != .error, failure == nil,output.frameLength > 0, let values = output.floatChannelData?[0] else {throw failure ?? ModuleError.invalid("Conversion audio impossible.") as NSError}
        let samples = (0..<Int(output.frameLength)).map {i -> Int16 in let v = values[i];return v.isFinite ? Int16(max(-32768,min(32767,(Double(v)*32767).rounded()))) : 0}
        return SymPCM(samples:samples,originalBits:16)
    }
}

struct NewSymSongView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var title = "Sans titre"
    @State private var channels = 16
    @State private var rows = 64
    @State private var instruments = 16
    @State private var bpm = 125
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Composer un SymMOD").font(.title2.bold())
            TextField("Titre",text:$title).textFieldStyle(.roundedBorder)
            Stepper("\(channels) pistes",value:$channels,in:1...32)
            Picker("Lignes par pattern",selection:$rows) {ForEach([16,32,64,128],id:\.self) {Text("\($0)").tag($0)}}
            Stepper("\(instruments) emplacements de samples",value:$instruments,in:1...64)
            Stepper("Tempo demandé : \(bpm) BPM",value:$bpm,in:32...255)
            Text("Le tempo est arrondi à la précision du format Symphonie. Un pattern vide est créé ; ajoute des positions depuis l’arrangement.").font(.caption).foregroundStyle(.secondary)
            HStack {Button("Annuler") {dismiss()};Spacer();Button("Créer le morceau") {s.createSymSong(title:title,channels:channels,rows:rows,instruments:instruments,bpm:bpm)}.buttonStyle(.borderedProminent)}
        }.padding(26).frame(width:440).symEditorSurface().symMODErrorAlert(s)
    }
}
