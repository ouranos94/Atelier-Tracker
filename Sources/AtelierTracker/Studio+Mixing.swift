import SwiftUI
import TrackerCore

@MainActor extension Studio {
    var mix: MixConfiguration {module.mix ?? MixConfiguration(channels:module.channelCount)}
    func trackMix(_ channel: Int) -> TrackMix {let values = mix.tracks; return values.indices.contains(channel) ? values[channel] : TrackMix()}
    var effectiveMuted: Set<Int> {
        guard consoleActive else {return []}
        return Set((0..<module.channelCount).filter {muted.contains($0) || (!solos.isEmpty && !solos.contains($0)) || mix.tracks[$0].volume == 0})
    }
    func cancelConsolePreparation() {
        consoleGeneration = UUID(); consoleJob?.cancel(); consoleJob = nil
        consolePreparing = false; consoleProgress = 0
    }
    func resetConsole(clearCache: Bool) {
        cancelConsolePreparation(); masterMeters.reset()
        if clearCache {consoleCache = nil; consoleActive = false}
    }
    func prepareConsole() {
        guard !consolePreparing, phase != .exporting else {return}
        if consoleCache != nil {setConsoleActive(true); return}
        guard let timeline = preparedAudio else {status = "Prépare d’abord l’audio du morceau avec Lecture, puis ouvre la console."; prepareTransport(); return}
        let snapshot = module, token = UUID(); consoleGeneration = token
        consolePreparing = true; consoleProgress = 0
        consoleJob = Task { [weak self] in
            do {
                let studio = self
                let worker = Task.detached(priority:.userInitiated) {
                    try StemCache.prepare(module:snapshot,timeline:timeline) {value in
                        Task { @MainActor [studio] in guard let owner = studio, owner.consoleGeneration == token else {return}; owner.consoleProgress = value}
                    }
                }
                let cache = try await withTaskCancellationHandler {try await worker.value} onCancel: {worker.cancel()}
                try Task.checkCancellation()
                guard let self, self.consoleGeneration == token else {return}
                self.consoleCache = cache; self.consolePreparing = false; self.consoleProgress = 1; self.consoleJob = nil
                self.setConsoleActive(true)
            } catch is CancellationError {} catch {
                guard let self, self.consoleGeneration == token else {return}
                self.consolePreparing = false; self.error = error.localizedDescription
            }
        }
    }
    func setConsoleActive(_ active: Bool) {
        guard phase != .exporting, !active || consoleCache != nil else {return}
        let wasPlaying = playing, hadPlayer = player != nil
        if wasPlaying {syncPlaybackPosition()}
        let position = clock.elapsed
        consoleActive = active
        if hadPlayer, let timeline = preparedAudio {
            do {try installPlayback(.range(activeRange ?? timeline.fullRange,position),autoPlay:wasPlaying,timeline:timeline)} catch {self.error = error.localizedDescription}
        }
        applyLiveMix()
        status = active ? "Console · DSP rendus par piste isolée" : "Écoute originale · volume général uniquement"
    }
    func toggleSolo(_ channel: Int) {
        guard consoleActive, (0..<module.channelCount).contains(channel) else {return}
        if solos.contains(channel) {solos.remove(channel)} else {solos.insert(channel)}
        applyLiveMix()
    }
    func editMix(_ change: (inout MixConfiguration) -> Void) {
        guard phase != .exporting else {return}
        var changed = mix; change(&changed)
        guard changed != mix else {return}
        do {try changed.validate(channels:module.channelCount)} catch {self.error = error.localizedDescription; return}
        if let gestureSnapshot {if !gestureChanged {undoStack.append(gestureSnapshot); gestureChanged = true}}
        else {undoStack.append(editorSnapshot)}
        if undoStack.count > 80 {undoStack.removeFirst()}; redoStack.removeAll()
        module.mix = changed; hasChanges = true; applyLiveMix(); scheduleRecovery()
    }
    func setTrackVolume(_ channel: Int,_ volume: Double) {
        guard consoleActive, mix.tracks.indices.contains(channel), volume.isFinite else {return}
        editMix {$0.tracks[channel].volume = min(2,max(0,volume))}
    }
    func setTrackPan(_ channel: Int,_ pan: Double) {
        guard consoleActive, mix.tracks.indices.contains(channel), pan.isFinite else {return}
        editMix {$0.tracks[channel].pan = min(1,max(-1,pan))}
    }
    func applyLiveMix() {
        if let player = player as? ConsolePlayer {try? player.dsp.apply(mix,muted:muted,solo:solos)}
        else {player?.volume = Float(mix.master)}
    }
    func differsOnlyInMix(from other: Module) -> Bool {
        var a = module, b = other; a.mix = nil; b.mix = nil; return a == b
    }
    func updateMasterFromOriginal(at time: Double) {
        guard let timeline = preparedAudio else {return}
        let end = min(timeline.frameCount,max(0,Int(time*44100))), start = max(0,end-2205)
        let gain = mix.master
        let peaks: (Double,Double) = timeline.result.wav.withUnsafeBytes {bytes in
            let samples = bytes.baseAddress!.advanced(by:44).assumingMemoryBound(to:Int16.self)
            var l = 0.0, r = 0.0
            for i in start..<end {l = max(l,abs(Double(samples[i*2]))/32768*gain); r = max(r,abs(Double(samples[i*2+1]))/32768*gain)}
            return (l,r)
        }
        masterMeters.update(left:peaks.0,right:peaks.1,clipped:peaks.0 >= 1 || peaks.1 >= 1)
    }
}
