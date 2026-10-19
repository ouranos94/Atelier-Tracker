import SwiftUI
import AVFoundation
import TrackerCore

enum TransportPhase: String {
    case stopped, preparing, playing, paused, exporting
    var title: String {
        switch self {
        case .stopped: return "Arrêt"
        case .preparing: return "Préparation…"
        case .playing: return "Lecture"
        case .paused: return "Pause"
        case .exporting: return "Export…"
        }
    }
}
enum LoopMode: String, CaseIterable, Identifiable {
    case off, pattern, selection
    var id: String { rawValue }
    var title: String { switch self {case .off: return "Sans boucle"; case .pattern: return "Pattern"; case .selection: return "Sélection A–B"} }
}
enum PlaybackRequest {
    case range(PlaybackRange,Double), prepareOnly, time(Double), selection(order: Int,row: Int), pattern(Int)
}
@MainActor final class TransportClock: ObservableObject {
    @Published var elapsed = 0.0
    @Published var duration = 0.0
    static func label(_ time: Double) -> String {
        let tenths = Int(max(0,time.isFinite ? time : 0)*10)
        return String(format:"%02d:%02d.%d",tenths/600,(tenths/10)%60,tenths%10)
    }
}

@MainActor extension Studio {
    func enableTransportPreparation() {
        automaticallyPrepare = true
        if preparedAudio == nil && !rendering { prepareTransport() }
    }
    func prepareTransport() { requestPlayback(.prepareOnly,autoPlay:false) }
    func stop(clearCache: Bool = false) {
        if midiTake?.active != nil {finishMIDINote()}
        invalidateMIDIVoice()
        playbackGeneration = UUID()
        pendingPlayback = nil; pendingAutoPlay = false
        job?.cancel(); job = nil
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        resetConsole(clearCache:clearCache)
        stopSamplePreview()
        renderMarkers = []; renderMeters = []
        phase = .stopped; resetMeters()
        clock.elapsed = 0; playbackOrder = 0; playbackRow = 0
        activeRange = nil; resumeAfterScrub = false
        if clearCache {
            preparedAudio = nil; preparedID = nil; clock.duration = 0
            loopMode = .off; selectionA = nil; selectionB = nil; playbackWarnings = []
        }
        status = "Arrêt"
    }
    func play(patternOnly: Bool = false) {
        guard phase != .exporting else {return}
        if patternOnly {
            loopMode = .off
            requestPlayback(.pattern(order),autoPlay:true)
        } else if playing { pause() }
        else if paused { resume() }
        else { requestPlayback(.time(clock.duration > 0 && clock.elapsed >= clock.duration ? 0 : clock.elapsed),autoPlay:true) }
    }
    func pause() {
        guard playing, let player else {return}
        syncPlaybackPosition()
        player.pause(); timer?.invalidate(); timer = nil
        masterMeters.reset()
        phase = .paused; status = "Pause · \(TransportClock.label(clock.elapsed))"
        resetMeters(at:clock.elapsed)
    }
    func resume() {
        guard paused else {play(); return}
        guard let player else {requestPlayback(.time(clock.elapsed),autoPlay:true); return}
        if let range = activeRange, clock.elapsed >= range.end-1.0/44100 {
            player.currentTime = 0; clock.elapsed = range.start
        }
        stopSamplePreview()
        guard player.play() else {error = "La reprise audio a échoué."; return}
        phase = .playing; status = playbackStatus; startTransportTimer()
    }
    var playbackStatus: String {
        let state = loopMode == .off ? "Lecture" : "Lecture · boucle \(loopMode.title)"
        return playbackWarnings.isEmpty ? state : state+" · "+playbackWarnings.joined(separator:" · ")
    }
    func playFromSelection() {
        loopMode = .off
        requestPlayback(.selection(order:order,row:row),autoPlay:true)
    }
    func selectCell(order selectedOrder: Int,row selectedRow: Int,channel selectedChannel: Int,extending: Bool = false) {
        guard module.orders.indices.contains(selectedOrder), !rendering else {return}
        let anchor = selection
        let previousOrder = order
        order = selectedOrder
        row = max(0,min(module.rowCount(pattern:module.orders[selectedOrder])-1,selectedRow))
        channel = max(0,min(module.channelCount-1,selectedChannel))
        if extending && previousOrder == selectedOrder {block = PatternSelection(row:anchor.anchorRow,channel:anchor.anchorChannel,toRow:row,toChannel:channel)}
        else {block = nil}
        blockOrder = selectedOrder
    }
    func toggleMute(_ channel: Int) {
        guard consoleActive, (0..<module.channelCount).contains(channel) else {return}
        if muted.contains(channel) {muted.remove(channel)} else {muted.insert(channel)}
        applyLiveMix()
    }
    func requestPlayback(_ request: PlaybackRequest,autoPlay: Bool) {
        guard phase != .exporting else {return}
        if autoPlay {stopSamplePreview()}
        if let preparedAudio {
            do {try installPlayback(request,autoPlay:autoPlay,timeline:preparedAudio)}
            catch {self.error = error.localizedDescription}
            return
        }
        pendingPlayback = request; pendingAutoPlay = autoPlay
        if phase == .preparing {return}
        let snapshot = module, silence = Set<Int>()
        let generation = playbackGeneration
        phase = .preparing; status = "Préparation audio…"
        job = Task { [self] in
            do {
                let worker = Task.detached(priority:.userInitiated) {try PlaybackTimeline(Renderer.render(snapshot,muted:silence))}
                let timeline = try await withTaskCancellationHandler {try await worker.value} onCancel: {worker.cancel()}
                try Task.checkCancellation()
                guard generation == playbackGeneration else {return}
                preparedAudio = timeline; preparedID = UUID()
                clock.duration = timeline.duration; playbackWarnings = timeline.result.warnings
                let next = pendingPlayback ?? .prepareOnly, shouldPlay = pendingAutoPlay
                pendingPlayback = nil
                phase = .stopped
                try installPlayback(next,autoPlay:shouldPlay,timeline:timeline)
                job = nil
            } catch is CancellationError { }
            catch {
                guard generation == playbackGeneration else {return}
                phase = .stopped; self.error = error.localizedDescription; status = "Préparation interrompue"
            }
        }
    }
    func installPlayback(_ request: PlaybackRequest,autoPlay: Bool,timeline: PlaybackTimeline) throws {
        var time: Double
        var onePattern: PlaybackRange?
        switch request {
        case .prepareOnly:
            phase = .stopped; status = playbackWarnings.isEmpty ? "Prêt" : playbackWarnings.joined(separator:" · ")
            return
        case .range(let range,let position): onePattern = range; time = position
        case .time(let position): time = position
        case .selection(let order,let row):
            guard let position = timeline.time(order:order,row:row) else {throw ModuleError.invalid("Cette ligne n’est pas atteinte par la séquence du morceau.")}
            time = position
        case .pattern(let order):
            guard let range = timeline.range(order:order) else {throw ModuleError.invalid("Cette position n’est pas atteinte par la séquence du morceau.")}
            onePattern = range; time = range.start
        }
        var range = onePattern ?? timeline.fullRange
        if loopMode == .pattern {
            guard let patternRange = timeline.range(order:loopOrder) else {throw ModuleError.invalid("Le pattern choisi n’est pas présent dans la lecture.")}
            range = patternRange
        } else if loopMode == .selection {
            guard let a = selectionA, let b = selectionB, let selection = timeline.boundedRange(start:a,end:b) else {
                loopMode = .off; throw ModuleError.invalid("Définis A puis B, avec une durée d’au moins 20 ms.")
            }
            range = selection
        }
        time = max(range.start,min(range.end,time.isFinite ? time : range.start))
        let repeats = loopMode != .off
        player?.stop(); timer?.invalidate(); timer = nil
        let next: any TransportPlayer
        if consoleActive, let consoleCache {next = try ConsolePlayer(cache:consoleCache,range:range,mix:mix,muted:muted,solo:solos)}
        else {
            let data = range == timeline.fullRange && !repeats ? timeline.result.wav : try timeline.wav(in:range,smoothLoop:repeats)
            let original = try AVAudioPlayer(data:data); original.volume = Float(mix.master); next = original
        }
        next.numberOfLoops = repeats ? -1 : 0
        next.currentTime = max(0,time-range.start)
        next.prepareToPlay(); player = next; activeRange = range
        renderMarkers = timeline.result.markers; renderMeters = timeline.result.meters
        clock.elapsed = time
        resetMeters(at:time); syncMarker(at:time)
        if autoPlay && time < range.end {
            guard next.play() else {throw ModuleError.invalid("La sortie audio n’a pas démarré.")}
            phase = .playing; status = playbackStatus; startTransportTimer()
        } else {phase = .paused; status = "Pause · \(TransportClock.label(time))"}
    }
    func startTransportTimer() {
        timer?.invalidate()
        let generation = playbackGeneration
        timer = Timer.scheduledTimer(withTimeInterval:0.025,repeats:true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackGeneration == generation else {return}
                self.syncPlayback()
            }
        }
    }
    func syncPlaybackPosition() {
        guard let player, let range = activeRange else {return}
        let time = min(range.end,range.start+player.currentTime)
        clock.elapsed = time
        if let console = player as? ConsolePlayer {
            let peaks = console.dsp.peaks(); applyMeterPeaks(peaks.tracks,at:time)
            masterMeters.update(left:peaks.left,right:peaks.right,clipped:peaks.clipped)
        } else {updateMeters(at:time); updateMasterFromOriginal(at:time)}
        syncMarker(at:time)
    }
    func syncMarker(at time: Double) {
        if let marker = preparedAudio?.position(at:time) {
            if playbackOrder != marker.order {playbackOrder = marker.order}
            if playbackRow != marker.row {playbackRow = marker.row}
        }
    }
    func syncPlayback() {
        guard playing, let player else {return}
        if !player.isPlaying {
            timer?.invalidate(); timer = nil
            clock.elapsed = activeRange?.end ?? clock.duration
            syncMarker(at:clock.elapsed)
            phase = .stopped; resetMeters(at:clock.elapsed); masterMeters.reset(); status = "Lecture terminée"
            return
        }
        syncPlaybackPosition()
    }
    func seek(to requestedTime: Double) {
        guard requestedTime.isFinite, phase != .exporting else {return}
        let time = max(0,min(clock.duration,requestedTime))
        if let range = activeRange, !range.contains(time), loopMode != .off {loopMode = .off}
        if let player, let range = activeRange, range.contains(time) {
            player.currentTime = time-range.start
            clock.elapsed = time; resetMeters(at:time); syncMarker(at:time)
            if paused {status = "Pause · \(TransportClock.label(time))"}
        } else {requestPlayback(.time(time),autoPlay:playing)}
    }
    func beginScrub() {resumeAfterScrub = playing; if playing {pause()}}
    func endScrub() {let resume = resumeAfterScrub; resumeAfterScrub = false; if resume && paused {self.resume()}}
    func setLoop(_ mode: LoopMode) {
        guard phase != .exporting else {return}
        if mode == .selection && (selectionA == nil || selectionB == nil) {status = "Place les repères A et B avant d’activer la boucle."; return}
        loopMode = mode
        if mode == .pattern {loopOrder = playing || paused ? playbackOrder : order}
        requestPlayback(.time(clock.elapsed),autoPlay:playing)
    }
    func markA() {
        selectionA = clock.elapsed
        if let b = selectionB, b <= clock.elapsed {selectionB = nil}
        if loopMode == .selection {setLoop(.off)}
        status = "Repère A · \(TransportClock.label(clock.elapsed))"
    }
    func markB() {
        let a = selectionA ?? 0
        guard clock.elapsed-a >= 0.02 else {status = "Place B au moins 20 ms après A."; return}
        selectionA = a; selectionB = clock.elapsed
        if loopMode == .selection {setLoop(.selection)}
        status = "Repère B · \(TransportClock.label(clock.elapsed))"
    }
}
