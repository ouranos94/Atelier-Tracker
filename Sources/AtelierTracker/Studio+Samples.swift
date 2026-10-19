import SwiftUI
import AVFoundation
import TrackerCore

struct SampleViewport {
    let length: Int, start: Int, end: Int
    init(length: Int,zoom: Double,offset: Double) {
        self.length = min(131070,max(0,length))
        let safeZoom = zoom.isFinite ? min(64,max(1,zoom)) : 1
        let visible = min(self.length,max(2,Int(ceil(Double(self.length)/safeZoom))))
        let fraction = offset.isFinite ? min(1,max(0,offset)) : 0
        start = Int(Double(self.length-visible)*fraction); end = start+visible
    }
    func point(at x: Double,width: Double) -> Int {
        guard width > 0, x.isFinite else {return start}
        return min(end,max(start,start+Int(min(1,max(0,x/width))*Double(end-start))))
    }
    func x(for point: Int,width: Double) -> Double {Double(point-start)/Double(max(1,end-start))*width}
}
@MainActor extension Studio {
    var canEditSamples: Bool {!isSymphonie && !playing && !rendering}
    var sampleRegion: SampleRegion? {
        if let sampleSelection, sampleSelection.valid(for:currentSample.data.count) {return sampleSelection}
        return SampleEditing.alignedRegion(start:0,end:currentSample.data.count,length:currentSample.data.count)
    }
    func resetSampleEditor() {sampleSelection = nil; sampleZoom = 1; sampleViewOffset = 0}
    func selectSampleRegion(start: Int,end: Int) {
        guard !isSymphonie else {return}
        sampleSelection = SampleEditing.alignedRegion(start:start,end:end,length:currentSample.data.count)
    }
    func editSample(_ operation: SampleOperation) {
        guard canEditSamples, let region = sampleRegion else {return}
        if (operation == .trim || operation == .delete) && sampleSelection == nil {return}
        do {
            var changed = currentSample
            let selected = try SampleEditing.apply(operation,to:&changed,region:region)
            guard changed != currentSample else {status = "Aucune donnée modifiée"; return}
            let index = sample
            endEditGesture(); edit {$0.samples[index] = changed}
            sampleSelection = selected
            if operation == .trim || operation == .delete {sampleZoom = 1; sampleViewOffset = 0}
            status = operation.title+" · sample \(index+1)"
        } catch {self.error = error.localizedDescription}
    }
    func setSampleLoop(start: Int,end: Int) {
        guard canEditSamples, let range = SampleEditing.alignedRegion(start:start,end:end,length:currentSample.data.count), range.count >= 4 else {return}
        do {
            var changed = currentSample; try SampleEditing.setLoop(&changed,region:range)
            let index = sample; edit {$0.samples[index] = changed}
            status = "Boucle sample · \(range.start)–\(range.end) points"
        } catch {self.error = error.localizedDescription}
    }
    func loopSampleSelection() {
        guard canEditSamples, let range = sampleRegion, range.count >= 4 else {return}
        endEditGesture(); setSampleLoop(start:range.start,end:range.end)
    }
    func disableSampleLoop() {
        guard canEditSamples else {return}
        let index = sample; endEditGesture(); edit {$0.samples[index].loopStart = 0; $0.samples[index].loopLength = 0}
    }
    func stopSamplePreview() {
        symAuditionGeneration = UUID(); symAuditionJob?.cancel(); symAuditionJob = nil
        samplePreviewGeneration = UUID(); samplePreviewJob?.cancel(); samplePreviewJob = nil
        previewPlayer?.stop(); previewPlayer = nil; samplePreviewing = false
    }
    func previewSample(period: Int = 214,loop: Bool = false,useSelection: Bool = true,noteAudition: Bool = false) {
        guard canEditSamples else {return}
        let current = currentSample
        let range: SampleRegion?
        if loop {range = current.loopLength > 2 ? SampleRegion(start:current.loopStart,end:current.loopStart+current.loopLength) : nil}
        else {range = useSelection ? sampleRegion : SampleEditing.alignedRegion(start:0,end:current.data.count,length:current.data.count)}
        guard let range else {return}
        do {
            stopSamplePreview()
            let wav = try SampleEditing.previewWAV(current,region:range,period:period,sustain:noteAudition ? 0.25 : 0)
            let next = try AVAudioPlayer(data:wav); next.numberOfLoops = loop ? -1 : 0
            next.prepareToPlay(); guard next.play() else {throw ModuleError.invalid("La préécoute audio n’a pas démarré.")}
            previewPlayer = next; samplePreviewing = true
            if !loop {
                let generation = samplePreviewGeneration, duration = next.duration
                samplePreviewJob = Task { [weak self] in
                    try? await Task.sleep(nanoseconds:UInt64((duration+0.05)*1_000_000_000))
                    guard !Task.isCancelled, let self, self.samplePreviewGeneration == generation else {return}
                    self.samplePreviewing = false; self.previewPlayer = nil; self.samplePreviewJob = nil
                }
            }
        } catch {self.error = error.localizedDescription}
    }
}
