import Foundation

public struct SymPCM: Equatable,Sendable {
    public static let referenceRate = 40460
    public var samples: [Int16]
    public let originalBits: Int
    public init(samples: [Int16],originalBits: Int = 16) {self.samples = samples;self.originalBits = originalBits}
    public func wav(range: Range<Int>? = nil) throws -> Data {
        let r = range ?? 0..<samples.count
        guard !r.isEmpty, r.lowerBound >= 0, r.upperBound <= samples.count, samples.count <= 2_500_000 else {throw ModuleError.invalid("Sélection PCM invalide ou sample supérieur à 60 secondes.")}
        var out = Data()
        func text(_ s: String) {out.append(contentsOf:s.utf8)}
        func le(_ n: Int,_ size: Int) {for i in 0..<size {out.append(UInt8((n>>(8*i))&255))}}
        text("RIFF");le(36+r.count*2,4);text("WAVEfmt ");le(16,4);le(1,2);le(1,2);le(Self.referenceRate,4);le(Self.referenceRate*2,4);le(2,2);le(16,2);text("data");le(r.count*2,4)
        for sample in samples[r] {let v = UInt16(bitPattern:sample);out.append(UInt8(v&255));out.append(UInt8(v>>8))};return out
    }
    static func decode(_ data: Data) throws -> Self {
        let data = Data(data)
        guard data.count <= 16*1024*1024 else {throw ModuleError.invalid("Sample trop volumineux.")}
        if data.starts(with:Data("RIFF".utf8)) {
            guard data.count >= 12, data.subdata(in:8..<12) == Data("WAVE".utf8) else {throw ModuleError.invalid("WAV invalide.")}
            func le(_ p: Int,_ n: Int) -> Int {(0..<n).reduce(0) {$0 | Int(data[p+$1])<<($1*8)}}
            var cursor = 12, bits = 0, format = 0, channels = 0, pcm: Data?
            while cursor+8 <= data.count {
                let id = data.subdata(in:cursor..<cursor+4), length = le(cursor+4,4);cursor += 8
                if length > data.count-cursor {
                    // Historical SymMODs may append padding that is not a valid RIFF chunk.
                    // Only tolerate it after a complete PCM data chunk; never truncate audio.
                    if pcm != nil && id != Data("data".utf8) && id != Data("fmt ".utf8) {break}
                    throw ModuleError.invalid("Bloc WAV tronqué.")
                }
                if id == Data("fmt ".utf8) {
                    guard length >= 16 else {throw ModuleError.invalid("Format WAV tronqué.")}
                    format = le(cursor,2);channels = le(cursor+2,2);bits = le(cursor+14,2)
                }
                if id == Data("data".utf8) {guard pcm == nil else {throw ModuleError.invalid("WAV à données multiples non éditable.")};pcm = data.subdata(in:cursor..<cursor+length)}
                cursor += length+(length&1)
            }
            guard format == 1, channels == 1, [8,16].contains(bits), let pcm, !pcm.isEmpty, pcm.count%(bits/8) == 0 else {throw ModuleError.invalid("PCM source éditable : WAV mono 8/16 bits uniquement. Convertis un fichier externe avec Importer.")}
            let values: [Int16]
            if bits == 8 {values = pcm.map {(Int16($0)-128)*256}}
            else {values = stride(from:0,to:pcm.count,by:2).map {Int16(bitPattern:UInt16(pcm[$0])|UInt16(pcm[$0+1])<<8)}}
            guard values.count <= 2_500_000 else {throw ModuleError.invalid("Sample supérieur à la limite d’édition de 60 secondes.")}
            return Self(samples:values,originalBits:bits)
        }
        if data.starts(with:Data("FORM".utf8)) || data.starts(with:Data("MAESTRO".utf8)) {throw ModuleError.invalid("Ce conteneur source est conservé, sans édition PCM. Importe un WAV/AIFF externe pour le remplacer dans une banque mono compatible.")}
        if data.starts(with:Data("16BT".utf8)) {
            guard data.count%2 == 0, data.count/2 <= 2_500_000 else {throw ModuleError.invalid("PCM 16BT invalide.")}
            var values = stride(from:0,to:data.count,by:2).map {Int16(bitPattern:UInt16(data[$0])<<8|UInt16(data[$0+1]))}
            for i in 0..<min(2,values.count) {values[i] = 0};return Self(samples:values)
        }
        guard !data.isEmpty, data.count <= 2_500_000 else {throw ModuleError.invalid("Sample brut vide ou trop long.")}
        return Self(samples:data.map {Int16(Int8(bitPattern:$0))*256},originalBits:8)
    }
}
extension SymMODDocument {
    /// One source sample chunk per mono instrument. Stereo/external layouts are deliberately not guessed.
    private func monoSampleSlots(_ storage: SymMODStorage) throws -> [Int] {
        guard !storage.chunks.contains(where:{$0.id == -7}), (0..<instrumentCount).allSatisfy({(try? instrument($0).channel) == 0}) else {throw ModuleError.invalid("Édition PCM réservée aux banques internes mono ; paires stéréo et références externes sont protégées.")}
        let slots = storage.chunks.indices.filter {[-11,-12,-17,-18].contains(storage.chunks[$0].id)}
        guard slots.count == instrumentCount else {throw ModuleError.invalid("Correspondance samples/instruments ambiguë : remplacement désactivé.")}
        // A stereo WAV can consume two native slots even without the stereo flags.
        for i in slots where storage.chunks[i].id != -12 {
            let payload = try samplePayload(storage.chunks[i])
            if payload.starts(with:Data("RIFF".utf8)) {
                // Require the known mono PCM layout to prove the slot correspondence.
                _ = try SymPCM.decode(payload)
            } else if payload.starts(with:Data("FORM".utf8)) || payload.starts(with:Data("MAESTRO".utf8)) {
                throw ModuleError.invalid("Un conteneur spécialisé rend la correspondance audio ambiguë.")
            }
        }
        return slots
    }
    private func samplePayload(_ chunk: SymChunk) throws -> Data {
        if chunk.id == -11 {return chunk.payload}
        var data = try Self.unpack(chunk.payload)
        if chunk.id == -17 {
            var last: UInt8 = 0
            for i in data.indices {last = last &+ data[i];data[i] = last}
        } else if chunk.id == -18 {
            for block in stride(from:0,to:data.count/4096*4096,by:4096) {
                let original = data.subdata(in:block..<block+4096);var last: UInt8 = 0
                for i in 0..<2048 {last = last &+ original[i];data[block+i*2+1] = last}
                for i in 0..<2048 {last = last &+ original[i+2048];data[block+i*2] = last}
            }
        }
        return data
    }
    public func pcm(_ index: Int) throws -> SymPCM? {
        _ = try instrument(index)
        let storage = try SymMODStorage(source), slots = try monoSampleSlots(storage), chunk = storage.chunks[slots[index]]
        if chunk.id == -12 {return nil}
        return try SymPCM.decode(samplePayload(chunk))
    }
    public func replacingPCM(_ index: Int,pcm: SymPCM,name: String,resetTuningAndLoop: Bool = true) throws -> Data {
        let original = try instrument(index), store = try SymMODStorage(source), slots = try monoSampleSlots(store)
        guard index <= 255, !original.isVirtual, original.channel == 0, original.type == 0 || original.type == 4 else {throw ModuleError.invalid("Seuls les emplacements mono ordinaires ou vides sont remplaçables.")}
        let wav = try pcm.wav()
        var record = original.bytes
        let encoded = (name.data(using:.isoLatin1,allowLossyConversion:true) ?? Data("Sample".utf8)).prefix(127)
        record.replaceSubrange(0..<128,with:encoded+Data(repeating:0,count:128-encoded.count))
        if record[0] == 0 {record[0] = 83}
        if original.name.isEmpty {record[134] = 100}
        if resetTuningAndLoop {
            for p in [128,129,130,137,138,139,150,151,152,153] {record[p] = 0}
            record[140] |= 16
        }
        var bank = instrumentData;bank.replaceSubrange(index*256..<(index+1)*256,with:record)
        return try store.replacing([try store.index(-14):SymMODStorage.block(-14,bank),slots[index]:SymMODStorage.block(-11,wav)])
    }
}
extension SymphonieDecoder {
    public static func replacingPCM(in module: Module,index: Int,pcm: SymPCM,name: String,resetTuningAndLoop: Bool = true) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        return try SymMODComposer.updating(module,source:SymMODDocument(sym.playbackSource).replacingPCM(index,pcm:pcm,name:name,resetTuningAndLoop:resetTuningAndLoop))
    }
}
