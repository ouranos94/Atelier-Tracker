import AVFoundation
import TrackerCore

@MainActor protocol TransportPlayer: AnyObject {
    var currentTime: TimeInterval {get set}
    var duration: TimeInterval {get}
    var numberOfLoops: Int {get set}
    var isPlaying: Bool {get}
    var volume: Float {get set}
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func pause()
    func stop()
}
extension AVAudioPlayer: TransportPlayer {}
@MainActor final class ConsolePlayer: TransportPlayer {
    let dsp: ConsoleDSP
    private let engine = AVAudioEngine()
    private let source: AVAudioSourceNode
    var volume: Float = 1
    var currentTime: TimeInterval {
        get {Double(dsp.frame-dsp.start)/44100}
        set {dsp.frame = dsp.start+Int((max(0,min(duration,newValue))*44100).rounded())}
    }
    var duration: TimeInterval {Double(dsp.end-dsp.start)/44100}
    var numberOfLoops = 0 {didSet {dsp.looping = numberOfLoops != 0}}
    var isPlaying: Bool {dsp.playing}
    init(cache: StemCache,range: PlaybackRange,mix: MixConfiguration,muted: Set<Int>,solo: Set<Int>) throws {
        let dsp = try ConsoleDSP(cache:cache,range:range); self.dsp = dsp
        try dsp.apply(mix,muted:muted,solo:solo)
        let format = AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
        source = AVAudioSourceNode(format:format) {_,_,frames,list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count >= 2, let left = buffers[0].mData, let right = buffers[1].mData else {return -50}
            dsp.render(count:Int(frames),left:left.assumingMemoryBound(to:Float.self),right:right.assumingMemoryBound(to:Float.self))
            return noErr
        }
        engine.attach(source); engine.connect(source,to:engine.mainMixerNode,format:format)
    }
    func prepareToPlay() -> Bool {engine.prepare(); return true}
    func play() -> Bool {
        do {if !engine.isRunning {try engine.start()}; dsp.playing = true; return true} catch {return false}
    }
    func pause() {dsp.playing = false}
    func stop() {dsp.playing = false; engine.stop()}
    deinit {engine.stop()}
}
@MainActor final class MasterMeterState: ObservableObject {
    @Published var left = 0.0
    @Published var right = 0.0
    @Published var clipped = false
    func update(left: Double,right: Double,clipped: Bool) {self.left = left; self.right = right; self.clipped = self.clipped || clipped}
    func reset() {left = 0; right = 0; clipped = false}
}
