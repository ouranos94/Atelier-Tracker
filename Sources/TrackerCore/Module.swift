import Foundation

public struct Note: Codable, Equatable, Sendable {
    public var period = 0, sample = 0, effect = 0, parameter = 0
    public var displayNote: String?, displayEffect: String?
    public init(period: Int = 0, sample: Int = 0, effect: Int = 0, parameter: Int = 0) {
        self.period = period; self.sample = sample; self.effect = effect; self.parameter = parameter
    }
    public static let periods = [856,808,762,720,678,640,604,570,538,508,480,453,428,404,381,360,339,320,302,285,269,254,240,226,214,202,190,180,170,160,151,143,135,127,120,113]
    public static let names = ["C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"]
    public var label: String {
        if let displayNote { return displayNote }
        guard period > 0, let i = Self.periods.indices.min(by: { abs(Self.periods[$0]-period) < abs(Self.periods[$1]-period) }) else { return "···" }
        return Self.names[i % 12] + String(1 + i / 12)
    }
}
public struct Sample: Codable, Equatable, Sendable {
    public var name = "", data: [Int8] = [], volume = 64, fineTune = 0, loopStart = 0, loopLength = 0
    public init() {}
}
public struct Module: Codable, Equatable, Sendable {
    public var title = "Sans titre"
    public var samples = Array(repeating: Sample(), count: 31)
    public var patterns = [Array(repeating: Note(), count: 256)]
    public var orders = [0]
    public var bpm = 125, speed = 6
    public var symphonie: SymphonieInfo?
    public var mix: MixConfiguration?
    public var channelCount: Int { symphonie?.channels ?? 4 }
    public func rowCount(pattern: Int) -> Int { patterns[pattern].count / channelCount }
    public init() {}
    public static func demo() -> Module {
        var m = Module(); m.title = "Neon tides"
        for s in 0..<4 {
            var sample = Sample(); sample.name = ["Velvet bass", "Glass keys", "Soft kick", "Dust hat"][s]
            let count = s < 2 ? 128 : 6000
            var seed: UInt32 = 42
            sample.data = (0..<count).map { i in
                let t = Double(i) / 16574
                let x: Double
                if s == 0 { x = sin(2 * .pi * Double(i) / 128) * 0.72 + sin(4 * .pi * Double(i) / 128) * 0.15 }
                else if s == 1 { x = (2 * Double(i) / 128 - 1) * 0.5 }
                else if s == 2 { x = sin(2 * .pi * (45 * t + 6 * (1-exp(-35*t)))) * exp(-t*20) }
                else { seed = seed &* 1664525 &+ 1013904223; x = (Double(seed) / Double(UInt32.max) * 2 - 1) * exp(-t*65) * 0.6 }
                return Int8(max(-127, min(127, x * 110)))
            }
            if s < 2 { sample.loopLength = count }
            sample.volume = [48, 26, 64, 35][s]; m.samples[s] = sample
        }
        for row in 0..<64 {
            if row % 4 == 0 { m.patterns[0][row*4] = Note(period: Note.periods[[12,12,19,15][row/16]], sample: 1) }
            if row % 4 == 2 { m.patterns[0][row*4+1] = Note(period: Note.periods[[24,27,31,34][(row/4)%4]], sample: 2, effect: 0xA, parameter: 3) }
            if row % 8 == 0 { m.patterns[0][row*4+2] = Note(period: 428, sample: 3) }
            if row % 4 == 2 { m.patterns[0][row*4+3] = Note(period: 214, sample: 4) }
        }
        return m
    }
}
public enum ModuleError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil }
}
public enum MODCodec {
    public static func decode(_ data: Data) throws -> Module {
        let b = [UInt8](data)
        guard b.count >= 1084 else { throw ModuleError.invalid("Fichier MOD incomplet.") }
        func word(_ p: Int) -> Int { Int(b[p]) << 8 | Int(b[p+1]) }
        func text(_ p: Int, _ n: Int) -> String { String(bytes: b[p..<p+n].prefix(while: { $0 != 0 }), encoding: .isoLatin1) ?? "" }
        guard ["M.K.","M!K!","4CHN","FLT4"].contains(text(1080, 4)) else { throw ModuleError.invalid("Seuls les MOD 4 pistes à 31 samples sont pris en charge.") }
        let length = Int(b[950]); guard (1...128).contains(length) else { throw ModuleError.invalid("Séquence MOD invalide.") }
        var m = Module(); m.title = text(0,20); m.orders = b[952..<952+length].map(Int.init)
        guard let highest = b[952..<1080].max(), highest < 128 else { throw ModuleError.invalid("Index de pattern invalide.") }
        let count = Int(highest)+1; var cursor = 1084 + count*1024
        guard b.count >= cursor else { throw ModuleError.invalid("Patterns tronqués.") }
        m.patterns = (0..<count).map { p in (0..<256).map { i in
            let o = 1084+p*1024+i*4
            return Note(period: Int(b[o]&15)<<8 | Int(b[o+1]), sample: Int(b[o]&0xF0) | Int(b[o+2]>>4), effect: Int(b[o+2]&15), parameter: Int(b[o+3]))
        } }
        guard m.patterns.allSatisfy({ $0.allSatisfy({ $0.sample <= 31 }) }) else { throw ModuleError.invalid("Numéro de sample invalide.") }
        for i in 0..<31 {
            let o = 20+i*30, size = word(o+22)*2
            guard cursor+size <= b.count, b[o+25] <= 64 else { throw ModuleError.invalid("Sample invalide ou tronqué.") }
            m.samples[i].name = text(o,22); m.samples[i].volume = Int(b[o+25]); m.samples[i].fineTune = Int(b[o+24]&15)
            m.samples[i].loopStart = word(o+26)*2; m.samples[i].loopLength = word(o+28)*2
            m.samples[i].data = b[cursor..<cursor+size].map { Int8(bitPattern:$0) }; cursor += size
            if m.samples[i].loopLength <= 2 { m.samples[i].loopStart = 0; m.samples[i].loopLength = 0 }
            else if m.samples[i].loopStart + m.samples[i].loopLength > size { throw ModuleError.invalid("Boucle de sample hors limites.") }
        }
        for n in m.patterns[m.orders[0]].prefix(4) where n.effect == 15 && n.parameter > 0 {
            if n.parameter < 32 { m.speed = n.parameter } else { m.bpm = n.parameter }
        }
        return m
    }
    public static func encode(_ m: Module) throws -> Data {
        guard m.symphonie == nil else { throw ModuleError.invalid("Le format MOD ne peut pas conserver les pistes et effets Symphonie. Enregistre le projet .atelier ou exporte un WAV.") }
        var b = [UInt8](repeating:0, count:1084)
        func putText(_ text: String, _ offset: Int, _ length: Int) { for (i,c) in (text.data(using:.isoLatin1, allowLossyConversion:true) ?? Data()).prefix(length).enumerated() { b[offset+i] = c } }
        func putWord(_ n: Int, _ o: Int) { b[o] = UInt8((n>>8)&255); b[o+1] = UInt8(n&255) }
        putText(m.title,0,20)
        for i in 0..<31 {
            let s = m.samples[i], o = 20+i*30
            putText(s.name,o,22); putWord(s.data.count/2,o+22); b[o+24] = UInt8(s.fineTune&15); b[o+25] = UInt8(clamping:s.volume)
            putWord(s.loopStart/2,o+26); putWord(max(1,s.loopLength/2),o+28)
        }
        b[950] = UInt8(m.orders.count); b[951] = 127
        for (i,p) in m.orders.enumerated() { b[952+i] = UInt8(p) }
        putText("M.K.",1080,4)
        var patterns = m.patterns
        let first = m.orders[0]
        var settings: [Int] = []
        if m.speed != 6 { settings.append(m.speed) }
        if m.bpm != 125 { settings.append(m.bpm) }
        for i in 0..<4 where !settings.isEmpty {
            if patterns[first][i].effect == 0 && patterns[first][i].parameter == 0 {
                patterns[first][i].effect = 15; patterns[first][i].parameter = settings.removeFirst()
            }
        }
        guard settings.isEmpty else { throw ModuleError.invalid("Export MOD : libère deux effets sur la première ligne pour y stocker le tempo et la vitesse, ou conserve le format .atelier.") }
        for pattern in patterns.prefix((m.orders.max() ?? 0)+1) { for n in pattern {
            b += [UInt8((n.sample&0xF0)|((n.period>>8)&15)),UInt8(n.period&255),UInt8((n.sample<<4)&0xF0 | (n.effect&15)),UInt8(n.parameter&255)]
        } }
        for s in m.samples { b += s.data.prefix(s.data.count/2*2).map { UInt8(bitPattern:$0) } }
        return Data(b)
    }
}
