import Foundation
import COpenMPT

/// Original bytes stay intact: the native decoder owns the Symphonie playback semantics.
public struct SymphonieInfo: Codable, Equatable, Sendable {
    public let source: Data
    public let channels: Int
    public let duration: Double
    public let message: String
    public let warnings: [String]
    public var editedSource: Data? = nil
    public var orderSource: [SymMODOrderSource?]? = nil
    public var playbackSource: Data {editedSource ?? source}
}

private final class SymphonieHandle {
    let handle: OpaquePointer
    let base: OpaquePointer
    init(_ data: Data) throws {
        guard data.count >= 16, data.count <= 64*1024*1024, data.starts(with:Data("SymM".utf8)),
              let pointer = data.withUnsafeBytes({ at_create($0.baseAddress,$0.count) }) else {
            throw ModuleError.invalid("Fichier Symphonie invalide, incomplet ou non pris en charge.")
        }
        handle = pointer; base = at_base(pointer)!
    }
    deinit { at_destroy(handle) }
    func string(_ pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        defer { openmpt_free_string(pointer) }
        return String(cString:pointer)
    }
}

public enum SymphonieDecoder {
    public static func decode(_ data: Data, title fallback: String = "Symphonie") throws -> Module {
        let h = try SymphonieHandle(data), m = h.base
        let channels = Int(openmpt_module_get_num_channels(m))
        let patterns = Int(openmpt_module_get_num_patterns(m)), count = Int(openmpt_module_get_num_orders(m))
        let samples = Int(openmpt_module_get_num_samples(m)), duration = openmpt_module_get_duration_seconds(m)
        guard (1...256).contains(channels), (1...4096).contains(patterns), (1...65536).contains(count), (0...1024).contains(samples), duration.isFinite, duration >= 0 else {
            throw ModuleError.invalid("Dimensions du morceau Symphonie invalides.")
        }
        var module = Module()
        let title = h.string(openmpt_module_get_metadata(m,"title"))
        module.title = title.isEmpty ? fallback : title
        module.bpm = Int(openmpt_module_get_current_tempo2(m).rounded()); module.speed = Int(openmpt_module_get_current_speed(m))
        module.symphonie = SymphonieInfo(source:data,channels:channels,duration:duration,message:h.string(openmpt_module_get_metadata(m,"message_raw")),warnings:h.string(openmpt_module_get_metadata(m,"warnings")).split(separator:"\n").map(String.init))
        module.orders = (0..<count).map {Int(openmpt_module_get_order_pattern(m,Int32($0)))}
        // Keep engine order indices intact; skipped/stop entries display a harmless empty pattern.
        let emptyIndex = patterns
        module.orders = module.orders.map { (0..<patterns).contains($0) ? $0 : emptyIndex }
        module.patterns = []; var cells = 0
        for p in 0..<patterns {
            let rows = max(1,Int(openmpt_module_get_pattern_num_rows(m,Int32(p))))
            cells += rows*channels
            guard rows <= 1024, cells <= 4_000_000 else { throw ModuleError.invalid("Partition Symphonie trop volumineuse.") }
            var notes: [Note] = []; notes.reserveCapacity(rows*channels)
            for r in 0..<rows { for c in 0..<channels {
                let p = Int32(p), r = Int32(r), c = Int32(c)
                let pitch = openmpt_module_get_pattern_row_channel_command(m,p,r,c,0)
                var n = Note(period:pitch > 0 && pitch < 121 ? 1 : 0,sample:Int(openmpt_module_get_pattern_row_channel_command(m,p,r,c,1)))
                n.displayNote = h.string(openmpt_module_format_pattern_row_channel_command(m,p,r,c,0)).replacingOccurrences(of:"...",with:"···")
                let volumeEffect = h.string(openmpt_module_format_pattern_row_channel_command(m,p,r,c,2))
                let volume = h.string(openmpt_module_format_pattern_row_channel_command(m,p,r,c,4))
                let effect = h.string(openmpt_module_format_pattern_row_channel_command(m,p,r,c,3))
                let parameter = h.string(openmpt_module_format_pattern_row_channel_command(m,p,r,c,5))
                n.displayEffect = (volumeEffect+volume+" "+effect+parameter).trimmingCharacters(in:.whitespaces).replacingOccurrences(of:".",with:"·")
                notes.append(n)
            } }
            module.patterns.append(notes)
        }
        if module.orders.contains(emptyIndex) { module.patterns.append(Array(repeating:Note(),count:channels)) }
        module.samples = (0..<max(1,samples)).map {i in
            var s = Sample(); s.name = h.string(openmpt_module_get_sample_name(m,Int32(i)))
            if s.name.isEmpty && i < openmpt_module_get_num_instruments(m) { s.name = h.string(openmpt_module_get_instrument_name(m,Int32(i))) }
            return s
        }
        if let doc = try? SymMODDocument(data), doc.channels == channels {module.symphonie?.orderSource = doc.orderMapping(orders:module.orders,patternRows:module.patterns.map {$0.count/channels})}
        return module
    }

    public static func refreshed(_ stored: Module) throws -> Module {
        guard let sym = stored.symphonie else {return stored}
        var fresh = try decode(sym.playbackSource,title:stored.title)
        let info = fresh.symphonie!
        fresh.symphonie = SymphonieInfo(source:sym.source,channels:info.channels,duration:info.duration,message:info.message,warnings:info.warnings,editedSource:sym.editedSource,orderSource:info.orderSource)
        fresh.mix = stored.mix
        return fresh
    }
    public static func replacingNote(in module: Module,pattern: Int,row: Int,channel: Int,event: SymMODEvent) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        let archive = try SymMODDocument(sym.playbackSource)
        let data = try archive.replacingNote(pattern:pattern,row:row,channel:channel,with:event)
        guard data != sym.playbackSource else {return module}
        var changed = module; changed.symphonie?.editedSource = data == sym.source ? nil : data
        return try refreshed(changed)
    }

    public static func render(_ module: Module, muted: Set<Int> = [], onlyOrder: Int? = nil, maximumDuration: Double = 1800) throws -> RenderResult {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Données Symphonie absentes.")}
        let h = try SymphonieHandle(sym.playbackSource), m = h.base
        openmpt_module_set_repeat_count(m,0)
        openmpt_module_ctl_set_text(m,"play.at_end","stop")
        for channel in muted {guard at_mute(h.handle,Int32(channel),1) != 0 else {throw ModuleError.invalid("Impossible de couper la piste Symphonie.")}}
        if let onlyOrder {openmpt_module_set_position_order_row(m,Int32(onlyOrder),0)}
        let rate = 44100, block = 441 // 10 ms: position and meter sampling independent of tracker speed.
        let limit = Int(Double(rate)*min(1800,max(0,maximumDuration)))
        var frame = 0, buffer = [Int16](repeating:0,count:block*2), pcm = Data()
        var markers: [RowMarker] = [], meters: [MeterFrame] = []
        while frame < limit {
            try Task.checkCancellation()
            let order = Int(openmpt_module_get_current_order(m)), row = Int(openmpt_module_get_current_row(m))
            if let onlyOrder, order != onlyOrder {break}
            let read = buffer.withUnsafeMutableBufferPointer {openmpt_module_read_interleaved_stereo(m,Int32(rate),min(block,limit-frame),$0.baseAddress)}
            if read == 0 {break}
            if module.orders.indices.contains(order), row >= 0 && row < module.rowCount(pattern:module.orders[order]), markers.last?.order != order || markers.last?.row != row {
                markers.append(RowMarker(time:Double(frame)/Double(rate),order:order,row:row))
            }
            let levels = (0..<sym.channels).map { muted.contains($0) ? 0 : min(1,max(0,Double(openmpt_module_get_current_channel_vu_mono(m,Int32($0))))) }
            meters.append(MeterFrame(time:Double(frame)/Double(rate),peaks:levels))
            buffer.withUnsafeBytes {pcm.append($0.bindMemory(to:UInt8.self).baseAddress!,count:read*4)}
            frame += read
        }
        var wav = Data()
        func ascii(_ text: String) {wav.append(contentsOf:text.utf8)}
        func le(_ n: Int,_ count: Int) {for i in 0..<count {wav.append(UInt8((n>>(i*8))&255))}}
        ascii("RIFF"); le(36+pcm.count,4); ascii("WAVEfmt "); le(16,4); le(1,2); le(2,2); le(rate,4); le(rate*4,4); le(4,2); le(16,2); ascii("data"); le(pcm.count,4); wav.append(pcm)
        return RenderResult(meters:meters,wav:wav,markers:markers,duration:Double(frame)/Double(rate),warnings:sym.warnings + (frame >= limit ? ["Rendu Symphonie limité à \(Int(maximumDuration)) secondes."] : []))
    }
}

public struct SymMODAudition: Sendable {
    public let wav: Data
    /// Envelope peaks from the rendered preview, not the raw sample or exact sample-loop coordinates.
    public let peaks: [Float]
    public let duration: Double
}
extension SymphonieDecoder {
    public static func audition(_ module: Module,instrument: Int,pitch: Int = 12,seconds: Double = 2) throws -> SymMODAudition {
        guard let sym = module.symphonie, seconds.isFinite, (0.05...4).contains(seconds), (0...84).contains(pitch) else {throw ModuleError.invalid("Préécoute hors limites.")}
        let doc = try SymMODDocument(sym.playbackSource), ins = try doc.instrument(instrument)
        guard !ins.name.isEmpty else {throw ModuleError.invalid("Emplacement source vide.")}
        let h = try SymphonieHandle(sym.playbackSource), m = h.base
        guard instrument < Int(openmpt_module_get_num_samples(m)) else {throw ModuleError.invalid("Instrument absent du lecteur.")}
        for c in 0..<sym.channels {guard at_mute(h.handle,Int32(c),1) != 0 else {throw ModuleError.invalid("Isolation de la préécoute impossible.")}}
        openmpt_module_ctl_set_text(m,"play.at_end","continue")
        guard at_play_note(h.handle,Int32(instrument),Int32(pitch+24)) >= 0 else {throw ModuleError.invalid("Le lecteur ne peut pas préécouter cet instrument.")}
        let rate = 44100, limit = Int(seconds*Double(rate)); var pcm = Data(), buffer = [Int16](repeating:0,count:882), levels: [Float] = []
        var frame = 0
        while frame < limit {
            try Task.checkCancellation()
            let count = min(441,limit-frame)
            let read = buffer.withUnsafeMutableBufferPointer {Int(openmpt_module_read_interleaved_stereo(m,Int32(rate),count,$0.baseAddress))}
            if read == 0 {break}
            buffer.withUnsafeBufferPointer {pcm.append(UnsafeRawBufferPointer(start:$0.baseAddress,count:read*4).bindMemory(to:UInt8.self))}
            levels.append(buffer.prefix(read*2).reduce(Float(0)) {max($0,abs(Float($1))/32768)})
            frame += read
        }
        guard frame > 0 else {throw ModuleError.invalid("Préécoute sans audio rendu.")}
        var wav = Data()
        func ascii(_ s: String) {wav.append(contentsOf:s.utf8)}
        func le(_ n: Int,_ count: Int) {for i in 0..<count {wav.append(UInt8((n>>(i*8))&255))}}
        ascii("RIFF"); le(36+pcm.count,4); ascii("WAVEfmt "); le(16,4); le(1,2); le(2,2); le(rate,4); le(rate*4,4); le(4,2); le(16,2); ascii("data"); le(pcm.count,4); wav.append(pcm)
        return SymMODAudition(wav:wav,peaks:levels,duration:Double(frame)/Double(rate))
    }
}

/// One interactive voice; module access is serialized with the audio callback.
public final class SymLiveVoice: @unchecked Sendable {
    private let native: SymphonieHandle
    private let lock = NSLock()
    private var voice: Int32 = -1
    private let scratch = UnsafeMutablePointer<Float>.allocate(capacity:2048)
    private let sampleCount: Int
    public init(_ module: Module) throws {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Voix SymMOD requise.")}
        native = try SymphonieHandle(sym.playbackSource)
        sampleCount = Int(openmpt_module_get_num_samples(native.base))
        for c in 0..<sym.channels {_ = at_mute(native.handle,Int32(c),1)}
        openmpt_module_ctl_set_text(native.base,"play.at_end","continue")
        openmpt_module_set_repeat_count(native.base,-1)
        scratch.initialize(repeating:0,count:2048)
    }
    public func noteOn(instrument: Int,pitch: Int,velocity: Int) throws {
        guard (0..<sampleCount).contains(instrument),(0...84).contains(pitch),(1...127).contains(velocity) else {throw ModuleError.invalid("Note MIDI ou sample hors limites.")}
        lock.lock();defer {lock.unlock()}
        at_stop_note(native.handle,voice)
        voice = at_play_velocity(native.handle,Int32(instrument),Int32(pitch+24),Double(velocity)/127)
        guard voice >= 0 else {throw ModuleError.invalid("Voix MIDI indisponible.")}
    }
    public func noteOff() {lock.lock();at_stop_note(native.handle,voice);voice = -1;lock.unlock()}
    public func render(count: Int,left: UnsafeMutablePointer<Float>,right: UnsafeMutablePointer<Float>) {
        lock.lock();defer {lock.unlock()}
        var offset = 0
        while offset < count {
            let frames = min(1024,count-offset)
            let n = Int(openmpt_module_read_interleaved_float_stereo(native.base,44100,frames,scratch))
            for i in 0..<frames {left[offset+i] = i<n ? scratch[i*2] : 0;right[offset+i] = i<n ? scratch[i*2+1] : 0}
            offset += frames
        }
    }
    deinit {scratch.deinitialize(count:2048);scratch.deallocate()}
}
