import Foundation

struct SymChunk {
    let id: Int32
    let raw: Data
    let payload: Data
}
struct SymMODStorage {
    let chunks: [SymChunk]
    init(_ source: Data) throws {
        guard try SymMODDocument(source).canEdit else {throw ModuleError.invalid("Structure source inconnue : écriture désactivée.")}
        var items: [SymChunk] = [], cursor = 8
        let scalars: Set<Int32> = [-1,-2,-3,-4,-5,-6,-7,10,11,12]
        while cursor < source.count {
            let start = cursor, id = Int32(bitPattern:SymMODDocument.u32(source,cursor)); cursor += 4
            if id == -12 {items.append(SymChunk(id:id,raw:source.subdata(in:start..<cursor),payload:Data()));continue}
            let length = Int(SymMODDocument.u32(source,cursor));cursor += 4
            if scalars.contains(id) {items.append(SymChunk(id:id,raw:source.subdata(in:start..<cursor),payload:source.subdata(in:cursor-4..<cursor)));continue}
            let payload = source.subdata(in:cursor..<cursor+length);cursor += length
            items.append(SymChunk(id:id,raw:source.subdata(in:start..<cursor),payload:payload))
        }
        chunks = items
    }
    func index(_ id: Int32) throws -> Int {
        guard let i = chunks.firstIndex(where:{$0.id == id}) else {throw ModuleError.invalid("Bloc SymMOD requis absent : \(id).")};return i
    }
    func replacing(_ replacements: [Int:Data],appending: Data = Data()) throws -> Data {
        var out = Data("SymM".utf8)+Self.u32(1)
        for (i,chunk) in chunks.enumerated() {out.append(replacements[i] ?? chunk.raw)}
        out.append(appending)
        guard out.count <= 64*1024*1024 else {throw ModuleError.invalid("Le module dépasse 64 Mio.")}
        _ = try SymMODDocument(out);return out
    }
    static func u32(_ n: Int) -> Data {var value = UInt32(truncatingIfNeeded:n).bigEndian;return withUnsafeBytes(of:&value) {Data($0)}}
    static func block(_ id: Int32,_ data: Data) -> Data {u32(Int(id))+u32(data.count)+data}
    static func word(_ n: Int,_ data: inout Data,_ offset: Int) {let v = UInt16(truncatingIfNeeded:n);data[offset] = UInt8(v>>8);data[offset+1] = UInt8(v&255)}
}

public enum SymMODComposer {
    public static func create(title: String,channels: Int = 16,rows: Int = 64,instruments: Int = 16,bpm: Int = 125) throws -> Module {
        guard (1...32).contains(channels), [16,32,64,128].contains(rows), (1...64).contains(instruments), (32...255).contains(bpm) else {throw ModuleError.invalid("Nouveau SymMOD : 1…32 pistes, 16/32/64/128 lignes, 1…64 instruments et 32…255 BPM.")}
        var data = Data("SymM".utf8)+SymMODStorage.u32(1)
        for (id,value) in [(-1,channels),(-2,rows),(-4,instruments),(-5,4),(-6,Int((Double(bpm)/1.24).rounded()))] {data.append(SymMODStorage.u32(id));data.append(SymMODStorage.u32(value))}
        data.append(SymMODStorage.block(-14,Data(repeating:0,count:instruments*256)))
        data.append(SymMODStorage.block(-10,position(pattern:0,length:rows)))
        var seq = Data(repeating:0,count:32);SymMODStorage.word(1,&seq,2);SymMODStorage.word(1,&seq,4);SymMODStorage.word(-1,&seq,22)
        data.append(SymMODStorage.block(-15,seq))
        var events = Data();for _ in 0..<rows*channels {events.append(SymMODEvent().bytes)}
        data.append(SymMODStorage.block(-13,events))
        for _ in 0..<instruments {data.append(SymMODStorage.u32(-12))}
        var module = try SymphonieDecoder.decode(data,title:title.isEmpty ? "Sans titre" : title)
        module.mix = MixConfiguration(channels:channels);return module
    }
    private static func position(pattern: Int,length: Int) -> Data {
        var p = Data(repeating:0,count:32)
        for (o,v) in [(4,1),(8,pattern),(12,length),(14,6)] {SymMODStorage.word(v,&p,o)};return p
    }
    public static func canExpand(_ doc: SymMODDocument) -> Bool {
        doc.canEdit && doc.sequences.count == 2 && doc.sequences[0].info == 0 && doc.sequences[0].start == 0 && doc.sequences[0].length == doc.positions.count && doc.sequences[1].info == -1 && !doc.positions.isEmpty
    }
    public static func append(in module: Module,pattern: Int? = nil,duplicate: Bool = false) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        let doc = try SymMODDocument(sym.playbackSource), store = try SymMODStorage(sym.playbackSource)
        guard canExpand(doc), doc.positions.count < 512, doc.patternCount < 512 else {throw ModuleError.invalid("L’ajout requiert un arrangement compact : une séquence couvrant toutes les positions, suivie du marqueur de fin. Limite : 512 positions/patterns.")}
        if let pattern {guard (0..<doc.patternCount).contains(pattern) else {throw ModuleError.invalid("Pattern source inexistant.")}}
        var events = doc.events, newPattern = pattern ?? doc.patternCount
        if pattern == nil || duplicate {
            newPattern = doc.patternCount
            if let pattern {
                let size = doc.rows*doc.channels*4
                let copy = doc.events.subdata(in:pattern*size..<(pattern+1)*size)
                for i in stride(from:0,to:copy.count,by:4) {
                    let e = SymMODEvent(command:copy[i],pitch:Int8(bitPattern:copy[i+1]),parameter:copy[i+2],instrument:copy[i+3])
                    guard e.isEditableEvent else {throw ModuleError.invalid("Le pattern contient une commande protégée : duplication refusée.")}
                }
                events.append(copy)
            } else {for _ in 0..<doc.rows*doc.channels {events.append(SymMODEvent().bytes)}}
        }
        guard events.count <= 16*1024*1024 else {throw ModuleError.invalid("Table de patterns trop volumineuse.")}
        var positions = doc.positionData;positions.append(position(pattern:newPattern,length:doc.rows))
        var seq = doc.sequenceData;SymMODStorage.word(doc.positions.count+1,&seq,2)
        let out = try store.replacing([try store.index(-13):SymMODStorage.block(-13,events),try store.index(-10):SymMODStorage.block(-10,positions),try store.index(-15):SymMODStorage.block(-15,seq)])
        return try updating(module,source:out)
    }
    public static func removePosition(in module: Module,index: Int) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        let doc = try SymMODDocument(sym.playbackSource), store = try SymMODStorage(sym.playbackSource)
        guard canExpand(doc), doc.positions.count > 1, doc.positions.indices.contains(index) else {throw ModuleError.invalid("Suppression réservée aux arrangements compacts ; une position doit rester.")}
        var positions = doc.positionData;positions.removeSubrange(index*32..<(index+1)*32)
        var seq = doc.sequenceData;SymMODStorage.word(doc.positions.count-1,&seq,2)
        return try updating(module,source:store.replacing([try store.index(-10):SymMODStorage.block(-10,positions),try store.index(-15):SymMODStorage.block(-15,seq)]))
    }
    static func updating(_ module: Module,source: Data) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Source absente.")}
        var changed = module;changed.symphonie?.editedSource = source == sym.source ? nil : source
        return try SymphonieDecoder.refreshed(changed)
    }
}
