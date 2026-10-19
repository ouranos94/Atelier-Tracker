import Foundation

/// Source layout, independent of the patterns synthesized by the playback decoder.
public struct SymMODEvent: Codable,Equatable,Sendable {
    public var command: UInt8, pitch: Int8, parameter: UInt8, instrument: UInt8
    public init(command: UInt8 = 0,pitch: Int8 = -1,parameter: UInt8 = 0,instrument: UInt8 = 0) {
        self.command = command; self.pitch = pitch; self.parameter = parameter; self.instrument = instrument
    }
    public var isEditableNote: Bool {command == 0 && (-1...84).contains(Int(pitch)) && parameter <= 100}
    public var bytes: Data {Data([command,UInt8(bitPattern:pitch),parameter,instrument])}
    public var pitchLabel: String {if command != 0 {return String(format:"FX%02X",command)}; return pitch < 0 ? "—" : Note.names[Int(pitch)%12]+String(Int(pitch)/12+2)}
}
public struct SymMODPosition: Equatable,Sendable {
    public var pattern: Int, start: Int, length: Int, speed: Int, transpose: Int, repeats: Int
}
public struct SymMODSequence: Equatable,Sendable {
    public var start: Int, length: Int, loops: Int, transpose: Int
    public let info: Int
}
public struct SymMODDocument: Sendable {
    public let source: Data
    public let channels: Int, rows: Int, instrumentCount: Int
    public let events: Data
    public let positions: [SymMODPosition], sequences: [SymMODSequence]
    public let hasUnknownTail: Bool
    let instrumentData: Data
    let instrumentRange: Range<Int>?
    let instrumentPacked: Bool
    let positionData: Data, sequenceData: Data
    let positionRange: Range<Int>?, sequenceRange: Range<Int>?
    let positionsPacked: Bool, sequencesPacked: Bool
    private let eventRange: Range<Int>
    private let packed: Bool
    public var patternCount: Int {events.count/(channels*rows*4)}
    public var canEdit: Bool {!hasUnknownTail}
    public var encoded: Data {source}

    public init(_ source: Data) throws {
        let source = Data(source)
        guard source.count >= 16, source.count <= 64*1024*1024, source.starts(with:Data("SymM".utf8)), Self.u32(source,4) == 1,
              Self.u32(source,8) == UInt32.max, (1...256).contains(Int(Self.u32(source,12))) else {throw ModuleError.invalid("Édition SymMOD : en-tête version 1 attendu.")}
        self.source = source; channels = Int(Self.u32(source,12))
        var cursor = 8, trackRows = 0, instruments = 0, eventSize = 4
        var eventData: Data?, range: Range<Int>?, isPacked = false, unknown = false
        var positionData: Data?, sequenceData: Data?
        var positionSpan: Range<Int>?, sequenceSpan: Range<Int>?, positionPack = false, sequencePack = false
        var instrumentBytes: Data?, instrumentSpan: Range<Int>?, packedInstruments = false
        let scalars: Set<Int32> = [-1,-2,-3,-4,-5,-6,-7,10,11,12]
        let binary: Set<Int32> = [-10,-11,-13,-14,-15,-16,-17,-18,-19,-20,-21]
        var seenScalars = Set<Int32>()
        while cursor < source.count {
            guard source.count-cursor >= 4 else {unknown = true; break}
            let start = cursor, id = Int32(bitPattern:Self.u32(source,cursor)); cursor += 4
            if id == -12 {continue}
            guard scalars.contains(id) || binary.contains(id) else {unknown = true; break}
            guard source.count-cursor >= 4 else {throw ModuleError.invalid("Bloc SymMOD tronqué.")}
            let value = Int(Self.u32(source,cursor)); cursor += 4
            if scalars.contains(id) {
                guard seenScalars.insert(id).inserted else {throw ModuleError.invalid("Valeur SymMOD dupliquée : édition refusée.")}
                if id == -2 {trackRows = value}
                if id == -5 {eventSize = value & 65535}
                continue
            }
            guard value <= source.count-cursor else {throw ModuleError.invalid("Longueur de bloc SymMOD hors du fichier.")}
            let payload = source.subdata(in:cursor..<cursor+value)
            switch id {
            case -13:
                guard eventData == nil else {throw ModuleError.invalid("Plusieurs blocs d’événements : édition refusée.")}
                eventData = try Self.unpack(payload); range = start..<cursor+value
                isPacked = payload.starts(with:Self.packMagic)
            case -14:
                guard instrumentBytes == nil else {throw ModuleError.invalid("Banques d’instruments multiples : édition refusée.")}
                let data = try Self.unpack(payload)
                guard data.count%256 == 0 else {throw ModuleError.invalid("Banque d’instruments SymMOD tronquée.")}
                instruments = data.count/256
                instrumentBytes = data; instrumentSpan = start..<cursor+value; packedInstruments = payload.starts(with:Self.packMagic)
            case -10:
                guard positionData == nil else {throw ModuleError.invalid("Séquences de positions multiples : édition refusée.")}
                positionData = try Self.unpack(payload)
                positionSpan = start..<cursor+value; positionPack = payload.starts(with:Self.packMagic)
            case -15:
                guard sequenceData == nil else {throw ModuleError.invalid("Tables de séquences multiples : édition refusée.")}
                sequenceData = try Self.unpack(payload)
                sequenceSpan = start..<cursor+value; sequencePack = payload.starts(with:Self.packMagic)
            default: break // Samples, DSP-related data and information remain opaque and unchanged.
            }
            cursor += value
        }
        guard (1...1024).contains(trackRows), eventSize == 4, let eventData, let range, !eventData.isEmpty,
              eventData.count%(channels*trackRows*4) == 0 else {throw ModuleError.invalid("Dimensions des patterns SymMOD incompatibles avec l’édition.")}
        rows = trackRows; events = eventData; eventRange = range; packed = isPacked; instrumentCount = instruments; hasUnknownTail = unknown
        instrumentData = instrumentBytes ?? Data(); instrumentRange = instrumentSpan; instrumentPacked = packedInstruments
        let pd = positionData ?? Data(), sd = sequenceData ?? Data()
        self.positionData = pd; self.sequenceData = sd
        positionRange = positionSpan; sequenceRange = sequenceSpan; positionsPacked = positionPack; sequencesPacked = sequencePack
        guard pd.count%32 == 0, sd.count%16 == 0 else {throw ModuleError.invalid("Table de positions ou de séquences tronquée.")}
        positions = stride(from:0,to:pd.count,by:32).map {o in
            SymMODPosition(pattern:Self.u16(pd,o+8),start:Self.u16(pd,o+10),length:Self.u16(pd,o+12),speed:Self.u16(pd,o+14),transpose:Int(Int16(bitPattern:UInt16(Self.u16(pd,o+16)))),repeats:Self.u16(pd,o+4))
        }
        sequences = stride(from:0,to:sd.count,by:16).map {o in
            SymMODSequence(start:Self.u16(sd,o),length:Self.u16(sd,o+2),loops:Self.u16(sd,o+4),transpose:Int(Int16(bitPattern:UInt16(Self.u16(sd,o+8)))),info:Int(Int16(bitPattern:UInt16(Self.u16(sd,o+6)))))
        }
    }
    public func event(pattern: Int,row: Int,channel: Int) throws -> SymMODEvent {
        let offset = try offset(pattern:pattern,row:row,channel:channel)
        return SymMODEvent(command:events[offset],pitch:Int8(bitPattern:events[offset+1]),parameter:events[offset+2],instrument:events[offset+3])
    }
    private func offset(pattern: Int,row: Int,channel: Int) throws -> Int {
        guard (0..<patternCount).contains(pattern), (0..<rows).contains(row), (0..<channels).contains(channel) else {throw ModuleError.invalid("Cellule source SymMOD hors limites.")}
        return ((pattern*rows+row)*channels+channel)*4
    }
    /// Only a normal KeyOn event can be edited here; specialized events keep all four bytes.
    public func replacingNote(pattern: Int,row: Int,channel: Int,with event: SymMODEvent) throws -> Data {
        guard canEdit else {throw ModuleError.invalid("Blocs inconnus présents : l’édition de ce fichier est désactivée pour préserver sa structure.")}
        let previous = try self.event(pattern:pattern,row:row,channel:channel)
        guard previous.isEditableNote, event.isEditableNote, Int(event.instrument) < instrumentCount else {throw ModuleError.invalid("Seuls les événements de note 00, hauteur −1…84 et volume 0…100 sont éditables ; instrument source valide requis.")}
        if previous == event {return source}
        let offset = try offset(pattern:pattern,row:row,channel:channel)
        var result = source
        if !packed {result.replaceSubrange(eventRange.lowerBound+8+offset..<eventRange.lowerBound+12+offset,with:event.bytes)}
        else {
            var payload = events; payload.replaceSubrange(offset..<offset+4,with:event.bytes)
            var block = Data([255,255,255,243]); var length = UInt32(payload.count).bigEndian
            withUnsafeBytes(of:&length) {block.append(contentsOf:$0)}; block.append(payload)
            result.replaceSubrange(eventRange,with:block)
        }
        guard result.count <= 64*1024*1024 else {throw ModuleError.invalid("Le fichier SymMOD modifié dépasse 64 Mio.")}
        return result
    }
    func replacingEventPayload(_ payload: Data) throws -> Data {
        var result = source
        if !packed {result.replaceSubrange(eventRange.lowerBound+8..<eventRange.upperBound,with:payload)}
        else {
            var block = Data([255,255,255,243]); var length = UInt32(payload.count).bigEndian
            withUnsafeBytes(of:&length) {block.append(contentsOf:$0)}; block.append(payload)
            result.replaceSubrange(eventRange,with:block)
        }
        guard result.count <= 64*1024*1024 else {throw ModuleError.invalid("Le fichier modifié dépasse 64 Mio.")}
        return result
    }
    private static let packMagic = Data([80,65,67,75,255,255])
    static func u32(_ d: Data,_ p: Int) -> UInt32 {(0..<4).reduce(0) {($0<<8)|UInt32(d[d.startIndex+p+$1])}}
    static func u16(_ d: Data,_ p: Int) -> Int {Int(d[d.startIndex+p])<<8|Int(d[d.startIndex+p+1])}
    static func unpack(_ input: Data) throws -> Data {
        guard input.starts(with:packMagic) else {return input}
        guard input.count >= 10 else {throw ModuleError.invalid("En-tête PACK tronqué.")}
        let size = Int(u32(input,6))
        guard size <= 16*1024*1024, size <= (input.count-10)*170 else {throw ModuleError.invalid("Bloc PACK trop grand ou incohérent.")}
        var output = Data(); output.reserveCapacity(size); var cursor = 10
        while cursor < input.count && output.count < size {
            let type = input[cursor]; cursor += 1
            if type == 255 {break}
            var count = 0, word = Data()
            switch type {
            case 0,1,3:
                guard cursor < input.count else {throw ModuleError.invalid("Commande PACK tronquée.")}
                count = Int(input[cursor]); cursor += 1
                if type == 1 {count *= 4}
            case 2: count = 8
            default: throw ModuleError.invalid("Commande PACK inconnue.")
            }
            guard count <= size-output.count else {throw ModuleError.invalid("Débordement du bloc PACK.")}
            if type == 0 {
                guard count <= input.count-cursor else {throw ModuleError.invalid("Copie PACK tronquée.")}
                output.append(input.subdata(in:cursor..<cursor+count)); cursor += count
            } else if type == 3 {output.append(Data(repeating:0,count:count))}
            else {
                guard input.count-cursor >= 4 else {throw ModuleError.invalid("Mot PACK tronqué.")}
                word = input.subdata(in:cursor..<cursor+4); cursor += 4
                for _ in 0..<count/4 {output.append(word)}
            }
        }
        guard output.count == size else {throw ModuleError.invalid("Bloc PACK incomplet.")}
        return output
    }
}
