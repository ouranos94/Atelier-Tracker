import Foundation

public enum ModuleValidation {
    public static func validate(_ m: Module) throws {
        if let mix = m.mix {try mix.validate(channels:m.channelCount)}
        if let sym = m.symphonie {
            if let edited = sym.editedSource {guard edited.count >= 16, edited.count <= 64*1024*1024, edited.starts(with:Data("SymM".utf8)), SymMODDocument.u32(edited,4) == 1, Int(SymMODDocument.u32(edited,12)) == sym.channels else {throw ModuleError.invalid("Source SymMOD modifiée invalide.")}}
            guard sym.source.starts(with:Data("SymM".utf8)), (1...256).contains(sym.channels), !m.orders.isEmpty, !m.samples.isEmpty, m.orders.allSatisfy({ m.patterns.indices.contains($0) }), m.patterns.allSatisfy({ !$0.isEmpty && $0.count % sym.channels == 0 }) else { throw ModuleError.invalid("Projet Symphonie invalide.") }
            return
        }
        guard m.samples.count == 31, (1...128).contains(m.orders.count), (1...128).contains(m.patterns.count), m.orders.allSatisfy({m.patterns.indices.contains($0)}), m.patterns.allSatisfy({$0.count == 256 && $0.allSatisfy({(0...4095).contains($0.period) && (0...31).contains($0.sample) && (0...15).contains($0.effect) && (0...255).contains($0.parameter)})}), (32...255).contains(m.bpm), (1...31).contains(m.speed), m.samples.allSatisfy({$0.data.count <= 131070 && (0...64).contains($0.volume) && (0...15).contains($0.fineTune) && $0.loopStart >= 0 && $0.loopLength >= 0 && $0.loopStart <= $0.data.count && $0.loopLength <= $0.data.count-$0.loopStart}) else { throw ModuleError.invalid("Le projet contient des données invalides.") }
    }
}
