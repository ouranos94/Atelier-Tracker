import AVFoundation
import TrackerCore

@MainActor extension Studio {
    func auditionSymInstrument(_ index: Int,pitch: Int = 12) {
        guard isSymphonie, !playing, !rendering, !consolePreparing else {return}
        stopSamplePreview(); symAuditionJob?.cancel()
        let generation = UUID(), expected = module.symphonie?.playbackSource, snapshot = module
        symAuditionGeneration = generation; symAudition = nil; symAuditionIndex = index
        let work = Task.detached(priority:.userInitiated) {try SymphonieDecoder.audition(snapshot,instrument:index,pitch:pitch)}
        symAuditionJob = Task {
            do {
                let result = try await withTaskCancellationHandler(operation:{try await work.value},onCancel:{work.cancel()})
                guard !Task.isCancelled, symAuditionGeneration == generation, module.symphonie?.playbackSource == expected else {return}
                symAudition = result
                let player = try AVAudioPlayer(data:result.wav); player.prepareToPlay(); player.play()
                previewPlayer = player; samplePreviewing = true
                status = "Préécoute instrument source \(index) · \(SymMODEvent(pitch:Int8(pitch)).pitchLabel)"
                try await Task.sleep(nanoseconds:UInt64(result.duration*1_000_000_000))
                if symAuditionGeneration == generation {previewPlayer = nil; samplePreviewing = false; symAuditionJob = nil}
            } catch is CancellationError {} catch {
                if symAuditionGeneration == generation {self.error = error.localizedDescription}
            }
        }
    }
    func cancelSymAudition() {
        symAuditionGeneration = UUID(); symAuditionJob?.cancel(); symAuditionJob = nil; stopSamplePreview()
    }
}
