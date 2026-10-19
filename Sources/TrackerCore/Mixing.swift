import Foundation
import CAudioMixer

public struct TrackMix: Codable,Equatable,Sendable {
    public var volume = 1.0, pan = 0.0
    public init(volume: Double = 1,pan: Double = 0) {self.volume = volume; self.pan = pan}
}
public struct MixConfiguration: Codable,Equatable,Sendable {
    public var tracks: [TrackMix]
    public var master = 1.0
    public init(channels: Int) {tracks = Array(repeating:TrackMix(),count:channels)}
    public func validate(channels: Int) throws {
        guard tracks.count == channels, master.isFinite, (0...1).contains(master), tracks.allSatisfy({$0.volume.isFinite && (0...2).contains($0.volume) && $0.pan.isFinite && (-1...1).contains($0.pan)}) else {throw ModuleError.invalid("Réglages de mixage invalides.")}
    }
    public func gains(channel: Int,muted: Set<Int>,solo: Set<Int>) -> (Float,Float) {
        guard tracks.indices.contains(channel), !muted.contains(channel), solo.isEmpty || solo.contains(channel) else {return (0,0)}
        let track = tracks[channel], gain = track.volume*master
        return (Float(gain*(track.pan > 0 ? 1-track.pan : 1)),Float(gain*(track.pan < 0 ? 1+track.pan : 1)))
    }
}
public final class StemCache: @unchecked Sendable {
    public let directory: URL, frameCount: Int, channels: Int
    public let files: [URL]
    private let mappings: [NSData]
    public var duration: Double {Double(frameCount)/44100}
    public init(directory: URL,files: [URL],frameCount: Int) throws {
        guard !files.isEmpty, files.count <= 32, frameCount > 0 else {throw ModuleError.invalid("Cache de pistes invalide.")}
        self.directory = directory; self.files = files; self.frameCount = frameCount; channels = files.count
        mappings = try files.map {url in
            let data = try NSData(contentsOf:url,options:.mappedIfSafe)
            guard data.length == 44+frameCount*4 else {throw ModuleError.invalid("Une piste isolée n’a pas la durée commune.")}
            return data
        }
    }
    public func pointers() -> [UnsafePointer<Int16>?] {mappings.map {$0.bytes.advanced(by:44).assumingMemoryBound(to:Int16.self)}}
    deinit {try? FileManager.default.removeItem(at:directory)}
    public static func prepare(module: Module,timeline: PlaybackTimeline,progress: @Sendable (Double) -> Void = {_ in}) throws -> StemCache {
        guard module.channelCount <= 32 else {throw ModuleError.invalid("La console est limitée à 32 pistes dans cette version.")}
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Atelier-Stems-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var success = false
        defer {if !success {try? FileManager.default.removeItem(at:directory)}}
        let required = Int64(timeline.frameCount)*4*Int64(module.channelCount)+50*1024*1024
        if let available = try? directory.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage, available < required {
            throw ModuleError.invalid("Espace insuffisant pour préparer les pistes : environ \(required/1024/1024) Mio nécessaires.")
        }
        var source = module; source.mix = nil
        var files: [URL] = []
        for c in 0..<module.channelCount {
            try Task.checkCancellation()
            let muted = Set(0..<module.channelCount).subtracting([c])
            let result = try source.symphonie != nil ? SymphonieDecoder.render(source,muted:muted,maximumDuration:timeline.duration) : Renderer.render(source,muted:muted)
            var data = Data(result.wav.prefix(44))
            let expected = timeline.frameCount*4
            data.append(result.wav.dropFirst(44).prefix(expected))
            if data.count < expected+44 {data.append(Data(repeating:0,count:expected+44-data.count))}
            for i in 0..<4 {data[4+i] = UInt8(((expected+36)>>(8*i))&255); data[40+i] = UInt8((expected>>(8*i))&255)}
            let file = directory.appendingPathComponent(String(format:"track-%02d.wav",c+1))
            try data.write(to:file,options:.atomic); files.append(file)
            progress(Double(c+1)/Double(module.channelCount))
        }
        try Task.checkCancellation()
        let cache = try StemCache(directory:directory,files:files,frameCount:timeline.frameCount)
        success = true; return cache
    }
}
public struct MixPeaks: Sendable {
    public let tracks: [Double], left: Double, right: Double, clipped: Bool
}
/// Exactly one audio/render consumer; controls, seeking and peak reads are atomic.
public final class ConsoleDSP: @unchecked Sendable {
    public let cache: StemCache
    private let handle: OpaquePointer
    public let start: Int, end: Int
    public init(cache: StemCache,range: PlaybackRange? = nil,clampOutput: Bool = true) throws {
        self.cache = cache
        let first = max(0,Int(((range?.start ?? 0)*44100).rounded()))
        let last = min(cache.frameCount,Int(((range?.end ?? cache.duration)*44100).rounded()))
        start = first; end = last
        let pointer = cache.pointers().withUnsafeBufferPointer {atm_create($0.baseAddress,Int32(cache.channels),Int64(cache.frameCount),Int64(first),Int64(last),clampOutput ? 1 : 0)}
        guard let pointer else {throw ModuleError.invalid("Le mixeur audio n’a pas pu être créé.")}
        handle = pointer
    }
    deinit {atm_destroy(handle)}
    public var playing: Bool {get {atm_is_playing(handle) != 0} set {atm_playing(handle,newValue ? 1 : 0)}}
    public var looping: Bool {get {loop} set {loop = newValue; atm_loop(handle,newValue ? 1 : 0)}}
    private var loop = false
    public var frame: Int {get {Int(atm_position(handle))} set {atm_seek(handle,Int64(newValue))}}
    public func apply(_ mix: MixConfiguration,muted: Set<Int> = [],solo: Set<Int> = []) throws {
        try mix.validate(channels:cache.channels)
        for c in 0..<cache.channels {let (l,r) = mix.gains(channel:c,muted:muted,solo:solo); atm_gain(handle,Int32(c),l,r)}
    }
    public func render(count: Int,left: UnsafeMutablePointer<Float>,right: UnsafeMutablePointer<Float>) {atm_render(handle,Int32(count),left,right)}
    public func peaks() -> MixPeaks {
        var tracks = [Float](repeating:0,count:cache.channels), left: Float = 0, right: Float = 0, clipped: Int32 = 0
        tracks.withUnsafeMutableBufferPointer {atm_peaks(handle,$0.baseAddress,&left,&right,&clipped)}
        return MixPeaks(tracks:tracks.map(Double.init),left:Double(left),right:Double(right),clipped:clipped != 0)
    }
}
