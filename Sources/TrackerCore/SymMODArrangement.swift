import Foundation

extension SymMODDocument {
    /// The native reader stops at info=-1 and skips info=1. Only ordinary active sequences are editable.
    public var activeSequenceIndices: [Int] {
        var result: [Int] = []
        for i in sequences.indices {
            if sequences[i].info == -1 {break}
            if sequences[i].info == 0, validSequence(sequences[i]) {result.append(i)}
        }
        return result
    }
    public func canEditPosition(_ index: Int) -> Bool {
        canEdit && positions.indices.contains(index) && validPosition(positions[index])
    }
    public func canEditSequence(_ index: Int) -> Bool {
        canEdit && activeSequenceIndices.contains(index)
    }
    private func validPosition(_ p: SymMODPosition) -> Bool {
        (0..<min(patternCount,65536)).contains(p.pattern) && (0..<rows).contains(p.start) &&
        (1...rows-p.start).contains(p.length) && (1...31).contains(p.speed) &&
        (-24...24).contains(p.transpose) && (0...16).contains(p.repeats)
    }
    private func validSequence(_ s: SymMODSequence) -> Bool {
        validSequenceRange(s) && (-24...24).contains(s.transpose)
    }
    private func validSequenceRange(_ s: SymMODSequence) -> Bool {
        (0...65535).contains(s.start) && positions.indices.contains(s.start) && (1...65535).contains(s.length) && s.length <= positions.count-s.start
    }
    public func replacingPosition(_ index: Int,with edit: SymMODPosition) throws -> Data {
        guard canEditPosition(index), validPosition(edit), let span = positionRange else {
            throw ModuleError.invalid("Position protégée ou invalide : pattern existant, lignes dans ce pattern, vitesse 1…31, transposition −24…24 et répétitions 0…16 requis.")
        }
        guard edit != positions[index] else {return source}
        var updated = positions; updated[index] = edit
        try validateArrangement(positions:updated,sequences:sequences)
        var record = positionData.subdata(in:index*32..<(index+1)*32)
        for (offset,value) in [(4,edit.repeats),(8,edit.pattern),(10,edit.start),(12,edit.length),(14,edit.speed),(16,edit.transpose)] {Self.write16(value,to:&record,at:offset)}
        return try replacingArrangementRecord(record,index:index,size:32,data:positionData,span:span,packed:positionsPacked,id:246)
    }
    public func replacingSequence(_ index: Int,with edit: SymMODSequence) throws -> Data {
        guard canEditSequence(index), validSequence(edit), edit.info == sequences[index].info, edit.loops == sequences[index].loops, let span = sequenceRange else {
            throw ModuleError.invalid("Séquence protégée ou invalide : plage de positions existantes et transposition −24…24 requises. Marqueurs et boucles de séquence sont conservés.")
        }
        guard edit != sequences[index] else {return source}
        var updated = sequences; updated[index] = edit
        // Do not introduce malformed or crossing-pattern positions into playback.
        guard (edit.start..<edit.start+edit.length).allSatisfy({validPosition(positions[$0])}) else {throw ModuleError.invalid("La plage contient une position non prise en charge par cet éditeur.")}
        try validateArrangement(positions:positions,sequences:updated)
        var record = sequenceData.subdata(in:index*16..<(index+1)*16)
        for (offset,value) in [(0,edit.start),(2,edit.length),(8,edit.transpose)] {Self.write16(value,to:&record,at:offset)}
        return try replacingArrangementRecord(record,index:index,size:16,data:sequenceData,span:span,packed:sequencesPacked,id:241)
    }
    private func validateArrangement(positions: [SymMODPosition],sequences: [SymMODSequence]) throws {
        var orders = 0, lines = 0
        for s in sequences {
            if s.info == -1 {break}
            if s.info == 1 || !validSequenceRange(s) {continue}
            for i in s.start..<s.start+s.length {
                let p = positions[i], count = max(1,p.repeats)
                // All source values are 16-bit. Bound expansion before calling the native reader.
                orders += count; lines += count*p.length
                guard orders <= 4096, lines <= 1_000_000, lines <= 4_000_000/channels else {throw ModuleError.invalid("Arrangement trop volumineux : limite d’édition de 4 096 positions jouées, 1 000 000 de lignes ou 4 000 000 de cellules jouées.")}
            }
        }
        guard orders > 0 else {throw ModuleError.invalid("Le morceau doit conserver au moins une position jouée.")}
    }
    private static func write16(_ value: Int,to data: inout Data,at offset: Int) {
        let bits = UInt16(truncatingIfNeeded:value)
        data[offset] = UInt8(bits>>8); data[offset+1] = UInt8(bits&255)
    }
    private func replacingArrangementRecord(_ record: Data,index: Int,size: Int,data: Data,span: Range<Int>,packed: Bool,id: UInt8) throws -> Data {
        var output = source
        if !packed {output.replaceSubrange(span.lowerBound+8+index*size..<span.lowerBound+8+(index+1)*size,with:record)}
        else {
            var payload = data; payload.replaceSubrange(index*size..<(index+1)*size,with:record)
            var block = Data([255,255,255,id]); var length = UInt32(payload.count).bigEndian
            withUnsafeBytes(of:&length) {block.append(contentsOf:$0)}; block.append(payload)
            output.replaceSubrange(span,with:block)
        }
        guard output.count <= 64*1024*1024 else {throw ModuleError.invalid("Le fichier modifié dépasse 64 Mio.")}
        return output
    }
}
extension SymphonieDecoder {
    public static func replacingPosition(in module: Module,index: Int,edit: SymMODPosition) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        return try refreshedArrangement(module,bytes:SymMODDocument(sym.playbackSource).replacingPosition(index,with:edit))
    }
    public static func replacingSequence(in module: Module,index: Int,edit: SymMODSequence) throws -> Module {
        guard let sym = module.symphonie else {throw ModuleError.invalid("Un SymMOD est requis.")}
        return try refreshedArrangement(module,bytes:SymMODDocument(sym.playbackSource).replacingSequence(index,with:edit))
    }
    private static func refreshedArrangement(_ module: Module,bytes: Data) throws -> Module {
        guard let sym = module.symphonie, bytes != sym.playbackSource else {return module}
        var changed = module; changed.symphonie?.editedSource = bytes == sym.source ? nil : bytes
        return try refreshed(changed)
    }
}
