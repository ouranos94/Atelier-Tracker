import Foundation
public struct RowMarker: Sendable { public let time: Double, order: Int, row: Int }
/// Linear per-voice peaks measured from actual sample output in 20 ms windows.
public struct MeterFrame: Sendable {
    public let time: Double
    public let peaks: [Double]
}
public struct RenderResult: Sendable { public let meters: [MeterFrame]; public let wav: Data; public let markers: [RowMarker]; public let duration: Double; public let warnings: [String] }
public enum Renderer {
    struct Voice { var sample = -1, position = 0.0, period = 428.0, volume = 0.0 }
    public static func render(_ module: Module, muted: Set<Int> = [], onlyOrder: Int? = nil) throws -> RenderResult {
        if module.symphonie != nil { return try SymphonieDecoder.render(module,muted:muted,onlyOrder:onlyOrder) }
        let rate = 44100.0
        var voices = Array(repeating: Voice(), count:4), pcm = Data(), markers: [RowMarker] = []
        var meters: [MeterFrame] = []
        let meterWindow = 882 // 20 ms at 44.1 kHz, independent of tracker ticks and tempo.
        var peaks = [Double](repeating:0,count:4), meterStart = 0
        var bpm = module.bpm, speed = module.speed, frame = 0, order = onlyOrder ?? 0, row = 0
        var visited = Set<Int>(), warnings = Set<String>()
        let maxFrames = Int(rate*300)
        while order < module.orders.count && frame < maxFrames {
            try Task.checkCancellation()
            let key = order*64+row
            if visited.contains(key) { warnings.insert("Boucle de séquence : rendu arrêté au premier retour."); break }
            visited.insert(key)
            let pattern = module.patterns[module.orders[order]], notes = Array(pattern[row*4..<row*4+4])
            markers.append(RowMarker(time:Double(frame)/rate, order:order, row:row))
            var nextOrder: Int?, nextRow: Int?
            for c in 0..<4 {
                let n = notes[c]
                if n.sample > 0 && n.sample <= 31 { voices[c].sample = n.sample-1; voices[c].volume = Double(module.samples[n.sample-1].volume)/64 }
                if n.period > 0 { voices[c].period = Double(n.period); voices[c].position = 0 }
                switch n.effect {
                case 0,1,2,0xA: break
                case 0x9: if n.period > 0 { voices[c].position = Double(n.parameter*256) }
                case 0xB: nextOrder = n.parameter
                case 0xC: voices[c].volume = Double(min(64,n.parameter))/64
                case 0xD: nextRow = min(63,(n.parameter>>4)*10+(n.parameter&15))
                case 0xF: if n.parameter > 0 { if n.parameter < 32 { speed = n.parameter } else { bpm = n.parameter } }
                default: warnings.insert(String(format:"Effet %X non interprété",n.effect))
                }
            }
            let tickFrames = max(1,Int(rate*2.5/Double(bpm)))
            for tick in 0..<speed {
                for c in 0..<4 where tick > 0 {
                    let n = notes[c]
                    if n.effect == 1 { voices[c].period = max(113,voices[c].period-Double(n.parameter)) }
                    if n.effect == 2 { voices[c].period = min(856,voices[c].period+Double(n.parameter)) }
                    if n.effect == 0xA { voices[c].volume = min(1,max(0,voices[c].volume+Double((n.parameter>>4)-(n.parameter&15))/64)) }
                }
                var steps = [Double](repeating:0,count:4)
                for c in 0..<4 where voices[c].sample >= 0 {
                    let s = module.samples[voices[c].sample], ft = s.fineTune < 8 ? s.fineTune : s.fineTune-16
                    let n = notes[c]
                    var pitch = 1.0
                    if n.effect == 0 && n.parameter != 0 { pitch = pow(2,Double(tick%3 == 1 ? n.parameter>>4 : tick%3 == 2 ? n.parameter&15 : 0)/12) }
                    steps[c] = 3546895 / voices[c].period / rate * pow(2,Double(ft)/96) * pitch
                }
                for _ in 0..<tickFrames {
                    if frame >= maxFrames { break }
                    var left = 0.0, right = 0.0
                    for c in 0..<4 where voices[c].sample >= 0 {
                        let s = module.samples[voices[c].sample]
                        let loopEnd = min(s.data.count,s.loopStart+s.loopLength)
                        if s.loopLength > 2 && loopEnd > s.loopStart && voices[c].position >= Double(loopEnd) {
                            voices[c].position = Double(s.loopStart) + (voices[c].position-Double(s.loopStart)).truncatingRemainder(dividingBy:Double(loopEnd-s.loopStart))
                        }
                        let index = Int(voices[c].position)
                        if index < s.data.count && !muted.contains(c) {
                            let value = Double(s.data[index])/128 * voices[c].volume * 0.32
                            peaks[c] = max(peaks[c],abs(value)/0.32)
                            let pan = c == 0 || c == 3
                            left += value * (pan ? 0.85 : 0.35); right += value * (pan ? 0.35 : 0.85)
                        }
                        voices[c].position += steps[c]
                    }
                    for value in [left,right] {
                        let v = UInt16(bitPattern:Int16(max(-32767,min(32767,value*32767))))
                        pcm.append(UInt8(v&255)); pcm.append(UInt8(v>>8))
                    }
                    frame += 1
                    if frame - meterStart == meterWindow {
                        meters.append(MeterFrame(time:Double(meterStart)/rate,peaks:peaks))
                        peaks = [Double](repeating:0,count:4); meterStart = frame
                    }
                }
            }
            if let target = nextOrder { order = target; row = nextRow ?? 0 }
            else if let targetRow = nextRow { order += 1; row = targetRow }
            else { row += 1; if row == 64 { row = 0; order += 1 } }
            if let onlyOrder, order != onlyOrder { break }
        }
        if frame >= maxFrames { warnings.insert("Rendu limité à 5 minutes.") }
        if frame > meterStart { meters.append(MeterFrame(time:Double(meterStart)/rate,peaks:peaks)) }
        var wav = Data()
        func ascii(_ s: String) { wav.append(contentsOf:s.utf8) }
        func le(_ value: Int, _ bytes: Int) { for i in 0..<bytes { wav.append(UInt8((value>>(8*i))&255)) } }
        ascii("RIFF"); le(36+pcm.count,4); ascii("WAVEfmt "); le(16,4); le(1,2); le(2,2); le(Int(rate),4); le(Int(rate)*4,4); le(4,2); le(16,2); ascii("data"); le(pcm.count,4); wav.append(pcm)
        return RenderResult(meters:meters, wav:wav, markers:markers, duration:Double(frame)/rate, warnings:warnings.sorted())
    }
}
