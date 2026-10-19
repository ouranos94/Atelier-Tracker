import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import TrackerCore

@MainActor final class TrackMeterState: ObservableObject {
    @Published var levels: [Double]
    @Published var holds: [Double]
    init(channelCount: Int = 4) {
        let silence = [Double](repeating:0,count:channelCount)
        levels = silence; holds = silence
    }
    func level(for channel: Int) -> Double { levels.indices.contains(channel) ? levels[channel] : 0 }
    func peak(for channel: Int) -> Double { holds.indices.contains(channel) ? holds[channel] : 0 }
}

@MainActor final class Studio: ObservableObject {
    @Published var module = Module.demo() {
        didSet {
            if module.symphonie?.playbackSource != oldValue.symphonie?.playbackSource {
                symArchive = module.symphonie.flatMap {try? SymMODDocument($0.playbackSource)}
                symAuditionGeneration = UUID(); symAuditionJob?.cancel(); symAuditionJob = nil
                symAudition = nil;invalidateMIDIVoice()
            }
        }
    }
    var symArchive: SymMODDocument?
    @Published var symAudition: SymMODAudition?
    @Published var symAuditionIndex: Int?
    var symAuditionJob: Task<Void,Never>?
    var symAuditionGeneration = UUID()
    let midiInput = MIDIInput()
    var midiLivePlayer: MIDILivePlayer?
    @Published var midiEnabled = false
    @Published var midiSource: UInt32 = 0
    @Published var midiChannel = 0
    @Published var midiQuantization = 1
    @Published var midiStepEntry = false
    @Published var midiLastEvent = "Aucun événement MIDI reçu"
    @Published var midiTake: MIDITake?
    var midiActiveNote: Int?
    @Published var newSymPresented = false
    @Published var libraryPresented = false
    @Published var midiPresented = false
    @Published var pianoVisible = false
    @Published var followPlayback = true
    @Published var order = 0
    @Published var row = 0
    @Published var channel = 0
    @Published var channelPage = 0
    @Published var sample = 0 {didSet {if oldValue != sample {stopSamplePreview(); symAudition = nil; resetSampleEditor()}}}
    @Published var sampleSelection: SampleRegion?
    @Published var sampleZoom = 1.0
    @Published var sampleViewOffset = 0.0
    @Published var sampleEditorOpen = false
    @Published var samplePreviewing = false
    var samplePreviewJob: Task<Void,Never>?
    var samplePreviewGeneration = UUID()
    @Published var octave = 2
    @Published var advance = 1
    @Published var muted: Set<Int> = []
    @Published var symArrangementPresented = false
    @Published var symInstrumentPresented = false
    @Published var symExportPresented = false
    @Published var symEditorPresented = false
    @Published var consolePresented = false
    @Published var exportPresented = false
    @Published var exportProgress = 0.0
    @Published var exportName = ""
    @Published var exportDirectory = FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask).first!.path
    @Published var solos: Set<Int> = []
    @Published var consoleActive = false
    @Published var consolePreparing = false
    @Published var consoleProgress = 0.0
    var consoleCache: StemCache?
    var consoleGeneration = UUID()
    var consoleJob: Task<Void,Never>?
    let masterMeters = MasterMeterState()
    @Published var phase: TransportPhase = .stopped
    var playing: Bool { phase == .playing }
    var paused: Bool { phase == .paused }
    var rendering: Bool { phase == .preparing || phase == .exporting }
    @Published var playbackOrder = 0
    @Published var playbackRow = 0
    @Published var loopMode: LoopMode = .off
    @Published var selectionA: Double?
    @Published var selectionB: Double?
    let clock = TransportClock()
    var preparedAudio: PlaybackTimeline?
    var preparedID: UUID?
    var activeRange: PlaybackRange?
    var loopOrder = 0
    var pendingPlayback: PlaybackRequest?
    var pendingAutoPlay = false
    var automaticallyPrepare = false
    var resumeAfterScrub = false
    var playbackWarnings: [String] = []
    @Published var symScoreSource = UserDefaults.standard.object(forKey:"sym.score.source") as? Bool ?? true {didSet {UserDefaults.standard.set(symScoreSource,forKey:"sym.score.source")}}
    @Published var recording = true
    @Published var status = "Prêt à composer"
    @Published var error: String?
    @Published var recoveryCandidate: RecoveryRecord?
    @Published var recoveryStatus = "Récupération non activée"
    var recoveryStore: RecoveryStore?
    var recoveryReady = false
    var recoveryGeneration = UUID()
    var recoveryJob: Task<Void,Never>?
    var recoveryResetJob: Task<Void,Never>?
    @Published var hasChanges = false
    @Published var fileURL: URL?
    @Published private(set) var meters = TrackMeterState()
    var playbackGeneration = UUID()
    var meterLevels: [Double] { get { meters.levels } set { meters.levels = newValue } }
    var meterHolds: [Double] { get { meters.holds } set { meters.holds = newValue } }
    var renderMeters: [MeterFrame] = []
    var meterCursor = 0, meterPlaybackTime = 0.0
    var peakHoldUntil = [Double](repeating:0,count:4)
    var player: (any TransportPlayer)?
    var previewPlayer: AVAudioPlayer?, timer: Timer?, job: Task<Void,Never>?
    var renderMarkers: [RowMarker] = []
    var undoStack: [EditorSnapshot] = [], redoStack: [EditorSnapshot] = []
    @Published var block: PatternSelection?
    @Published var blockOrder = 0
    @Published var rowsAllTracks = true
    var gestureSnapshot: EditorSnapshot?
    var gestureChanged = false
    var auxiliarySheetPresented: Bool {newSymPresented || libraryPresented || midiPresented}
    var symSourceSheetPresented: Bool {symEditorPresented || symInstrumentPresented || symArrangementPresented || symExportPresented}
    var isSymphonie: Bool { module.symphonie != nil }
    var isOverview: Bool { isSymphonie && channelPage == -1 }
    var visibleChannels: Range<Int> {
        if isOverview { return 0..<module.channelCount }
        if isSymphonie && channelPage == -2 {let selected = min(max(0,channel),module.channelCount-1); return selected..<selected+1}
        let start = min(max(0,channelPage)*4,max(0,module.channelCount-1))
        return start..<min(module.channelCount,start+4)
    }
    var scoreOrder: Int { followPlayback && (playing || paused) ? playbackOrder : order }
    var scoreRow: Int { followPlayback && (playing || paused) ? playbackRow : row }
    var scorePattern: Int { module.orders[min(max(0,scoreOrder),module.orders.count-1)] }
    var scoreRows: Int { module.rowCount(pattern:scorePattern) }
    var rows: Int { module.rowCount(pattern:pattern) }
    var pattern: Int { module.orders[min(max(0,order),module.orders.count-1)] }
    var note: Note { note(at:row,channel:channel) }
    func note(at row: Int, channel: Int) -> Note {
        guard row >= 0, row < rows, channel >= 0, channel < module.channelCount else { return Note() }
        return module.patterns[pattern][row*module.channelCount+channel]
    }
    func scoreNote(at row: Int,channel: Int) -> Note {
        guard row >= 0, row < scoreRows, channel >= 0, channel < module.channelCount else {return Note()}
        return module.patterns[scorePattern][row*module.channelCount+channel]
    }
    var currentSample: Sample { module.samples[min(max(0,sample),module.samples.count-1)] }
    func edit(_ change: (inout Module) -> Void) {
        guard !isSymphonie else { return }
        var changed = module; change(&changed)
        guard changed != module else { return }
        stop(clearCache:true)
        if let gestureSnapshot {
            if !gestureChanged {undoStack.append(gestureSnapshot); gestureChanged = true}
        } else {undoStack.append(editorSnapshot)}
        if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
        module = changed; hasChanges = true; scheduleRecovery()
    }
    func undo() {
        endEditGesture(); guard let previous = undoStack.popLast() else {return}
        let current = editorSnapshot; if !differsOnlyInMix(from:previous.module) {stop(clearCache:true)}; redoStack.append(current); restore(previous); applyLiveMix(); hasChanges = true; scheduleRecovery()
    }
    func redo() {
        endEditGesture(); guard let next = redoStack.popLast() else {return}
        let current = editorSnapshot; if !differsOnlyInMix(from:next.module) {stop(clearCache:true)}; undoStack.append(current); restore(next); applyLiveMix(); hasChanges = true; scheduleRecovery()
    }
    func setNote(_ n: Note) { let p = pattern, index = row*4+channel; edit { $0.patterns[p][index] = n } }
    func enter(_ index: Int) {
        if isSymphonie {enterSymNote(index); return}
        let i = (octave-1)*12+index
        guard (0..<36).contains(i) else {status = "Note hors des trois octaves MOD"; return}
        var n = note; n.period = Note.periods[i]; n.sample = sample+1
        if recording { setNote(n); selectCell(order:order,row:(row+advance)%64,channel:channel) }
        preview(period:n.period)
    }
    func preview(period: Int = 428) {previewSample(period:period,useSelection:false,noteAudition:true)}
    func replaceModule(with loaded: Module) {
        midiTake = nil;invalidateMIDIVoice()
        symEditorPresented = false; symExportPresented = false; symInstrumentPresented = false; symArrangementPresented = false
        endEditGesture(); block = nil; blockOrder = 0; resetSampleEditor(); clearRecoveryForNewSession()
        stop(clearCache:true)
        order = 0; row = 0; channel = 0; sample = 0; muted = []; solos = []
        channelPage = loaded.symphonie == nil ? 0 : -1
        octave = loaded.symphonie == nil ? min(3,max(1,octave)) : min(9,max(2,octave))
        module = loaded
        // SwiftUI can retain the outgoing 16-track view while mounting the 4-track view.
        // Give each song its own meter object; never shrink an object still observed by it.
        meters = TrackMeterState(channelCount:loaded.channelCount)
        resetMeters()
        clock.duration = loaded.symphonie?.duration ?? 0
    }
    func resetMeters(at time: Double = 0) {
        meterLevels = [Double](repeating:0,count:module.channelCount); meterHolds = meterLevels
        peakHoldUntil = meterLevels; meterCursor = 0; meterPlaybackTime = time
        var low = 0, high = renderMeters.count
        while low < high {
            let mid = (low+high)/2
            if renderMeters[mid].time < max(0,time-0.025) { low = mid+1 } else { high = mid }
        }
        meterCursor = low
    }
    func updateMeters(at time: Double) {
        guard !renderMeters.isEmpty else { return }
        if time < meterPlaybackTime { resetMeters(at:time) }
        let elapsed = max(0,time-meterPlaybackTime)
        // Include skipped windows so a short transient between UI refreshes stays visible.
        var incoming = [Double](repeating:0,count:module.channelCount)
        while meterCursor < renderMeters.count && renderMeters[meterCursor].time <= time {
            for c in 0..<min(module.channelCount,renderMeters[meterCursor].peaks.count) {
                incoming[c] = max(incoming[c],renderMeters[meterCursor].peaks[c])
            }
            meterCursor += 1
        }
        applyMeterPeaks(incoming,at:time,elapsed:elapsed)
    }
    func applyMeterPeaks(_ incoming: [Double],at time: Double,elapsed: Double = 0.025) {
        var levels = meterLevels, holds = meterHolds
        for c in 0..<module.channelCount {
            let amplitude = incoming[c]
            let level = amplitude > 0 ? max(0,min(1,(20*log10(amplitude)+48)/48)) : 0
            levels[c] = max(level,levels[c]-elapsed*0.75)
            if levels[c] >= holds[c] {
                holds[c] = levels[c]; peakHoldUntil[c] = time+0.65
            } else if time > peakHoldUntil[c] {
                holds[c] = max(levels[c],holds[c]-elapsed*0.5)
            }
        }
        meterLevels = levels; meterHolds = holds
        meterPlaybackTime = time
    }
    func confirmDiscard() -> Bool {
        guard hasChanges else { return true }
        let alert = NSAlert(); alert.messageText = "Conserver tes modifications ?"; alert.informativeText = "Enregistre le morceau avant de le remplacer."; alert.addButton(withTitle:"Enregistrer"); alert.addButton(withTitle:"Annuler"); alert.addButton(withTitle:"Remplacer")
        switch alert.runModal() { case .alertFirstButtonReturn: return save(); case .alertSecondButtonReturn: return false; default: return true }
    }
    func newModule(demo: Bool = false) {
        guard confirmDiscard() else { return }; replaceModule(with:demo ? .demo() : Module()); fileURL = nil; hasChanges = false; undoStack = []; redoStack = []; status = demo ? "Démo chargée" : "Nouveau morceau"; if automaticallyPrepare { prepareTransport() }
    }
    func open() {
        let panel = NSOpenPanel()
        panel.title = "Ouvrir un morceau"
        panel.message = "Projet Atelier, MOD 4 pistes ou Symphonie / Symphonie Pro (.SymMOD)."
        panel.allowedContentTypes = [.init(filenameExtension:"mod")!, .init(filenameExtension:"symmod")!, .init(filenameExtension:"atelier")!]
        panel.allowsOtherFileTypes = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url:url)
    }
    func open(url: URL) {
        do {
            let data = try Data(contentsOf:url)
            let kind = ImportKind.identify(url:url,prefix:data.prefix(1084))
            guard kind != .audio else { throw ModuleError.invalid("Ce fichier n’est pas un morceau MOD ou SymMOD reconnu. Pour importer un WAV ou un AIFF comme instrument, utilise « Importer un sample ».") }
            var loaded: Module
            if kind == .symphonie { loaded = try SymphonieDecoder.decode(data,title:url.deletingPathExtension().lastPathComponent) }
            else if kind == .project {
                loaded = try JSONDecoder().decode(Module.self,from:data)
                if loaded.symphonie != nil {loaded = try SymphonieDecoder.refreshed(loaded)}
            } else { loaded = try MODCodec.decode(data) }
            try validate(loaded)
            guard confirmDiscard() else { return }
            replaceModule(with:loaded)
            fileURL = kind == .project ? url : nil
            hasChanges = false; undoStack = []; redoStack = []
            status = "\(url.lastPathComponent) ouvert" + (isSymphonie ? " · Symphonie · \(module.channelCount) pistes · lecture" : "")
            if automaticallyPrepare { prepareTransport() }
        } catch { self.error = "Impossible d’ouvrir « \(url.lastPathComponent) » : \(error.localizedDescription)" }
    }
    func validate(_ m: Module) throws {try ModuleValidation.validate(m)}
    @discardableResult func save(as saveAs: Bool = false, mod: Bool = false) -> Bool {
        if mod && isSymphonie { error = "Un SymMOD ne peut pas être exporté sans perte en MOD 4 pistes. Utilise le projet Atelier ou l’export WAV."; return false }
        var url: URL? = saveAs || mod ? nil : fileURL
        if url == nil { let panel = NSSavePanel(); if mod {panel.message = "Le MOD conserve les notes et samples. Les volumes, balances et niveau général de la console sont conservés uniquement dans le projet Atelier et les exports audio."}; panel.allowedContentTypes = [.init(filenameExtension:mod ? "mod" : "atelier")!]; panel.nameFieldStringValue = module.title + (mod ? ".mod" : ".atelier"); guard panel.runModal() == .OK else { return false }; url = panel.url }
        guard let url else { return false }
        do {
            let data: Data
            if url.pathExtension.lowercased() == "mod" { data = try MODCodec.encode(module) } else { data = try JSONEncoder().encode(module) }
            try data.write(to:url,options:.atomic)
            if !mod { fileURL = url; hasChanges = false; clearRecoveryForNewSession() }; status = "Enregistré : \(url.lastPathComponent)"; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func importSample() {
        let panel = NSOpenPanel()
        panel.title = "Importer un sample ou ouvrir un MOD"
        panel.message = isSymphonie ? "Audio : conversion mono 16 bits, 40 460 Hz, 60 secondes maximum. L’accord et la boucle sont réinitialisés pour le nouvel instrument. MOD / SymMOD : ouvre le morceau complet." : "Audio : conversion mono 8 bits, 16 574 Hz, 131 070 points maximum (≈ 7,91 s). Le surplus est retiré du sample importé ; le fichier source reste intact. MOD / SymMOD : ouvre le morceau complet."
        panel.allowedContentTypes = [.wav,.aiff,.audio,.init(filenameExtension:"mod")!,.init(filenameExtension:"symmod")!]
        panel.allowsOtherFileTypes = true; panel.allowsMultipleSelection = false
        panel.begin {[weak self] response in
            guard response == .OK,let url = panel.url else {return}
            Task {@MainActor in self?.importSample(url:url)}
        }
    }
    func importSample(url: URL) {
        do {
            let handle = try FileHandle(forReadingFrom:url)
            defer { try? handle.close() }
            let prefix = try handle.read(upToCount:1084) ?? Data()
            if ImportKind.identify(url:url,prefix:prefix) != .audio {
                open(url:url)
                return
            }
            if isSymphonie {try importSymPCM(url:url,index:sample); return}
            let file = try AVAudioFile(forReading:url)
            guard file.length > 0, file.length <= Int64(file.processingFormat.sampleRate*60), let buffer = AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length)) else { throw ModuleError.invalid("Choisis un sample de moins de 60 secondes.") }
            try file.read(into:buffer)
            guard let channels = buffer.floatChannelData else { throw ModuleError.invalid("Format audio non pris en charge.") }
            let frames = Int(buffer.frameLength), ratio = file.processingFormat.sampleRate/16574
            let length = min(131070,Int(Double(frames)/ratio))/2*2
            guard length >= 2 else {throw ModuleError.invalid("Le fichier est trop court après conversion : un sample MOD exige au moins deux points.")}
            var s = Sample(); s.name = String(url.deletingPathExtension().lastPathComponent.prefix(22))
            s.data = (0..<length).map { i in let p = min(frames-1,Int(Double(i)*ratio)); var v: Float = 0; for c in 0..<Int(buffer.format.channelCount) { v += channels[c][p] }; return Int8(max(-127,min(127,v/Float(buffer.format.channelCount)*127))) }
            let selected = sample; endEditGesture(); edit { $0.samples[selected] = s }; resetSampleEditor(); status = "Sample importé · mono 8 bits · 16 574 Hz"
        } catch {
            self.error = "Impossible d’importer « \(url.lastPathComponent) » comme sample. Choisis un fichier audio WAV ou AIFF. Pour un morceau MOD, utilise « Ouvrir un morceau » (⌘O).\n\nDétail : \(error.localizedDescription)"
        }
    }
    func exportWAV() {guard phase != .exporting, !consolePreparing else {return}; exportName = module.title; exportPresented = true}
    func addOrder(duplicate: Bool) {
        if isSymphonie {appendSymPosition(duplicate:duplicate); return}
        guard module.orders.count < 128, module.patterns.count < 128 else { return }
        let copy = module.patterns[pattern], index = order+1
        edit { m in m.orders.insert(m.patterns.count,at:index); m.patterns.append(duplicate ? copy : Array(repeating:Note(),count:256)) }; order = index
    }
    func removeOrder() { if isSymphonie {removeSymPosition(); return}; guard module.orders.count > 1 else { return }; let index = order; edit { $0.orders.remove(at:index) }; order = min(index,module.orders.count-1) }
}
