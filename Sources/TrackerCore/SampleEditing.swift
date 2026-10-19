import Foundation

public struct SampleRegion: Codable,Equatable,Sendable {
    public var start: Int, end: Int
    public init(start: Int,end: Int) {self.start = start; self.end = end}
    public var count: Int {end-start}
    public func valid(for length: Int) -> Bool {start >= 0 && end > start && end <= length && start%2 == 0 && end%2 == 0}
}
public enum SampleOperation: String,CaseIterable,Identifiable,Sendable {
    case trim, delete, normalize, reverse, invert, fadeIn, fadeOut
    public var id: String {rawValue}
    public var title: String {
        switch self {
        case .trim: return "Garder la sélection"
        case .delete: return "Supprimer la sélection"
        case .normalize: return "Normaliser"
        case .reverse: return "Retourner"
        case .invert: return "Inverser la polarité"
        case .fadeIn: return "Fondu d’entrée"
        case .fadeOut: return "Fondu de sortie"
        }
    }
}
public enum SampleEditing {
    public static let referenceRate = 3546894.6/214
    public static func alignedRegion(start: Int,end: Int,length: Int) -> SampleRegion? {
        let limit = max(0,length)/2*2
        let a = min(limit,max(0,min(start,end)))/2*2
        let b = min(limit,max(0,max(start,end)))/2*2
        return b > a ? SampleRegion(start:a,end:b) : nil
    }
    public static func setLoop(_ sample: inout Sample,region: SampleRegion?) throws {
        guard let region else {sample.loopStart = 0; sample.loopLength = 0; return}
        guard region.valid(for:sample.data.count), region.count >= 4 else {throw ModuleError.invalid("Une boucle MOD doit contenir au moins 4 points et avoir des limites paires.")}
        sample.loopStart = region.start; sample.loopLength = region.count
    }
    public static func apply(_ operation: SampleOperation,to sample: inout Sample,region: SampleRegion) throws -> SampleRegion? {
        guard region.valid(for:sample.data.count), sample.data.count <= 131070, sample.loopStart >= 0, sample.loopStart <= sample.data.count, sample.loopLength >= 0, sample.loopLength <= sample.data.count-sample.loopStart else {throw ModuleError.invalid("Sélection de sample vide ou invalide. Les limites MOD sont alignées sur deux points.")}
        var result = sample
        let a = region.start, b = region.end
        switch operation {
        case .trim, .delete:
            let oldLoop = (sample.loopStart,max(sample.loopStart,min(sample.data.count,sample.loopStart+sample.loopLength)))
            if operation == .trim {result.data = Array(sample.data[a..<b])}
            else {result.data.removeSubrange(a..<b)}
            if sample.loopLength > 2 {
                let lo: Int, hi: Int
                if operation == .trim {lo = max(a,oldLoop.0)-a; hi = min(b,oldLoop.1)-a}
                else {
                    func map(_ value: Int) -> Int {value <= a ? value : value >= b ? value-(b-a) : a}
                    lo = map(oldLoop.0); hi = map(oldLoop.1)
                }
                if let loop = alignedRegion(start:max(0,lo),end:max(0,hi),length:result.data.count), hi > lo, loop.count >= 4 {
                    result.loopStart = loop.start; result.loopLength = loop.count
                } else {result.loopStart = 0; result.loopLength = 0}
            } else {result.loopStart = 0; result.loopLength = 0}
        case .normalize:
            let peak = sample.data[a..<b].map {abs(Int($0))}.max() ?? 0
            if peak > 0 {for i in a..<b {result.data[i] = Int8(clamping:Int((Double(sample.data[i])*127/Double(peak)).rounded()))}}
        case .reverse: result.data.replaceSubrange(a..<b,with:sample.data[a..<b].reversed())
        case .invert: for i in a..<b {result.data[i] = Int8(clamping:-Int(sample.data[i]))}
        case .fadeIn, .fadeOut:
            for i in a..<b {
                let progress = Double(i-a)/Double(max(1,b-a-1)), gain = operation == .fadeIn ? progress : 1-progress
                result.data[i] = Int8(clamping:Int((Double(sample.data[i])*gain).rounded()))
            }
        }
        sample = result
        if operation == .trim {return SampleRegion(start:0,end:result.data.count)}
        if operation == .delete {return nil}
        return region
    }
    public static func previewWAV(_ sample: Sample,region: SampleRegion,period: Int = 214,sustain: Double = 0) throws -> Data {
        guard region.valid(for:sample.data.count), (1...4095).contains(period), (0...15).contains(sample.fineTune), (0...64).contains(sample.volume), sustain.isFinite, (0...60).contains(sustain) else {throw ModuleError.invalid("Aucun sample à écouter.")}
        let rate = 44100, fineTune = sample.fineTune < 8 ? sample.fineTune : sample.fineTune-16
        let sourceRate = 3546894.6/Double(period) * pow(2,Double(fineTune)/96)
        let looping = sustain > 0 && region.start == 0 && region.end == sample.data.count && sample.loopStart >= 0 && sample.loopStart <= sample.data.count && sample.loopLength >= 4 && sample.loopLength <= sample.data.count-sample.loopStart
        let frames = max(1,max(Int(Double(region.count)*Double(rate)/sourceRate),looping ? Int(sustain*Double(rate)) : 0))
        guard frames <= rate*60 else {throw ModuleError.invalid("La préécoute dépasse une minute.")}
        var output = Data()
        func text(_ value: String) {output.append(contentsOf:value.utf8)}
        func word(_ value: Int,_ bytes: Int) {for i in 0..<bytes {output.append(UInt8((value>>(i*8))&255))}}
        text("RIFF"); word(36+frames*4,4); text("WAVEfmt "); word(16,4); word(1,2); word(2,2)
        word(rate,4); word(rate*4,4); word(4,2); word(16,2); text("data"); word(frames*4,4)
        for frame in 0..<frames {
            let raw = Int(Double(frame)*sourceRate/Double(rate))+region.start
            let position: Int
            if looping && raw >= sample.loopStart+sample.loopLength {position = sample.loopStart+(raw-sample.loopStart)%sample.loopLength}
            else {position = min(region.end-1,raw)}
            let value = Int(Double(sample.data[position])*256*Double(sample.volume)/64)
            let bits = Int(UInt16(bitPattern:Int16(clamping:value)))
            word(bits,2); word(bits,2)
        }
        return output
    }
}
