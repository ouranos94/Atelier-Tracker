import Foundation

/// Loop coordinates are fixed point percentages: one unit is 1/65536 percent.
public struct SymMODLoop: Equatable,Sendable {
    public var enabled: Bool
    public var start: Int, length: Int
    public init(enabled: Bool,start: Int,length: Int) {self.enabled = enabled; self.start = start; self.length = length}
}
public struct SymMODInstrumentEdit: Equatable,Sendable {
    public var volume: Int, finetune: Int, transpose: Int
    public var ignorePositionTranspose: Bool
    /// Nil preserves the original loop encoding, including the legacy rounding system.
    public var loop: SymMODLoop?
    public init(volume: Int,finetune: Int,transpose: Int,ignorePositionTranspose: Bool,loop: SymMODLoop? = nil) {
        self.volume = volume; self.finetune = finetune; self.transpose = transpose; self.ignorePositionTranspose = ignorePositionTranspose; self.loop = loop
    }
}
public struct SymMODInstrument: Sendable {
    public let bytes: Data
    public var name: String {String(data:bytes.prefix(128).prefix(while:{$0 != 0}),encoding:.isoLatin1) ?? ""}
    public var type: Int {Int(Int8(bitPattern:bytes[128]))}
    public var channel: Int {Int(bytes[132])}
    public var volume: Int {Int(bytes[134])}
    public var finetune: Int {Int(Int8(bitPattern:bytes[138]))}
    public var transpose: Int {Int(Int8(bitPattern:bytes[139]))}
    public var isVirtual: Bool {bytes.starts(with:Data("ViRT".utf8))}
    public var fineLoops: Bool {bytes[140]&16 != 0}
    public var ignorePositionTranspose: Bool {bytes[142]&1 != 0}
    public var bypassDSP: Bool {bytes[142]&2 != 0}
    public var canEdit: Bool {!isVirtual && bytes[0] != 0 && channel == 0 && (type == 0 || type == 4) && volume <= 199}
    public var loop: SymMODLoop {
        SymMODLoop(enabled:type == 4,start:(Int(bytes[129])<<16)+(fineLoops ? SymMODDocument.u16(bytes,150) : 0),length:(Int(bytes[130])<<16)+(fineLoops ? SymMODDocument.u16(bytes,152) : 0))
    }
    public var kindDescription: String {
        if name.isEmpty {return "Emplacement vide"}
        if isVirtual {return "Virtuel / transwave"}
        if channel == 1 {return "Stéréo · gauche"}; if channel == 2 {return "Stéréo · droite"}
        if channel != 0 {return "Canal spécialisé \(channel)"}
        if type == 8 {return "Mono · sustain"}
        return type == 4 ? "Mono · boucle continue" : type == 0 ? "Mono · ordinaire" : "Type spécialisé \(type)"
    }
    public var settings: SymMODInstrumentEdit {SymMODInstrumentEdit(volume:volume,finetune:finetune,transpose:transpose,ignorePositionTranspose:ignorePositionTranspose)}
}
extension SymMODDocument {
    public func instrument(_ index: Int) throws -> SymMODInstrument {
        guard (0..<instrumentCount).contains(index) else {throw ModuleError.invalid("Instrument source hors limites.")}
        return SymMODInstrument(bytes:instrumentData.subdata(in:index*256..<(index+1)*256))
    }
    public func replacingInstrument(_ index: Int,with edit: SymMODInstrumentEdit) throws -> Data {
        guard canEdit, let span = instrumentRange else {throw ModuleError.invalid("Structure inconnue : édition des instruments désactivée.")}
        let original = try instrument(index)
        guard original.canEdit else {throw ModuleError.invalid("Cet instrument est protégé : seuls les instruments mono ordinaires et en boucle sont éditables.")}
        guard (0...199).contains(edit.volume), (-128...127).contains(edit.finetune), (-128...127).contains(edit.transpose) else {throw ModuleError.invalid("Volume 0…199 et accordage signé −128…127 requis.")}
        var record = original.bytes
        record[134] = UInt8(edit.volume); record[138] = UInt8(bitPattern:Int8(edit.finetune)); record[139] = UInt8(bitPattern:Int8(edit.transpose))
        record[142] = (record[142]&254) | (edit.ignorePositionTranspose ? 1 : 0)
        if let loop = edit.loop, loop != original.loop {
            if loop.enabled {
                let maximum = 100*65536
                guard (0...maximum).contains(loop.start), (1...maximum).contains(loop.length), loop.length <= maximum-loop.start else {throw ModuleError.invalid("La boucle doit avoir une longueur positive et finir au plus à 100 % du sample.")}
                record[128] = 4; record[140] |= 16
                record[129] = UInt8(loop.start>>16); record[130] = UInt8(loop.length>>16)
                record[150] = UInt8((loop.start>>8)&255); record[151] = UInt8(loop.start&255)
                record[152] = UInt8((loop.length>>8)&255); record[153] = UInt8(loop.length&255)
            } else {record[128] = 0} // Keep dormant loop values intact.
        }
        guard record != original.bytes else {return source}
        var output = source
        if !instrumentPacked {output.replaceSubrange(span.lowerBound+8+index*256..<span.lowerBound+8+(index+1)*256,with:record)}
        else {
            var payload = instrumentData; payload.replaceSubrange(index*256..<(index+1)*256,with:record)
            var block = Data([255,255,255,242]); var length = UInt32(payload.count).bigEndian
            withUnsafeBytes(of:&length) {block.append(contentsOf:$0)}; block.append(payload)
            output.replaceSubrange(span,with:block)
        }
        guard output.count <= 64*1024*1024 else {throw ModuleError.invalid("Le fichier modifié dépasse 64 Mio.")}
        return output
    }
}
extension SymphonieDecoder {
    public static func replacingInstrument(in module: Module,index: Int,edit: SymMODInstrumentEdit) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        let bytes = try SymMODDocument(sym.playbackSource).replacingInstrument(index,with:edit)
        guard bytes != sym.playbackSource else {return module}
        var changed = module; changed.symphonie?.editedSource = bytes == sym.source ? nil : bytes
        return try refreshed(changed)
    }
}
