import Foundation

/// All transport positions refer to the same rendered PCM, including the state of samples and DSPs.
public struct PlaybackRange: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public var duration: Double { end-start }
    public init(start: Double, end: Double) { self.start = start; self.end = end }
    public func contains(_ time: Double) -> Bool { time >= start && time < end }
}

public struct PlaybackTimeline: Sendable {
    public let result: RenderResult
    public let frameCount: Int
    public var duration: Double { Double(frameCount)/44100 }
    public var fullRange: PlaybackRange { PlaybackRange(start:0,end:duration) }
    public init(_ result: RenderResult) throws {
        guard result.wav.count >= 44, result.wav.prefix(4) == Data("RIFF".utf8), (result.wav.count-44)%4 == 0 else {
            throw ModuleError.invalid("Le rendu audio ne contient pas de PCM stéréo valide.")
        }
        self.result = result; frameCount = (result.wav.count-44)/4
        guard frameCount > 0 else { throw ModuleError.invalid("Le morceau ne contient aucune durée audio lisible.") }
    }
    public func markerIndex(at time: Double) -> Int? {
        let markers = result.markers
        guard !markers.isEmpty else {return nil}
        var low = 0, high = markers.count
        while low < high {
            let mid = (low+high)/2
            if markers[mid].time <= time {low = mid+1} else {high = mid}
        }
        return max(0,low-1)
    }
    public func position(at time: Double) -> RowMarker? { markerIndex(at:time).map {result.markers[$0]} }
    public func time(order: Int,row: Int) -> Double? { result.markers.first(where:{$0.order == order && $0.row == row})?.time }
    public func range(order: Int) -> PlaybackRange? {
        guard let index = result.markers.firstIndex(where:{$0.order == order}) else {return nil}
        let end = result.markers.dropFirst(index+1).first(where:{$0.order != order})?.time ?? duration
        return boundedRange(start:result.markers[index].time,end:end)
    }
    public func boundedRange(start: Double,end: Double) -> PlaybackRange? {
        guard start.isFinite, end.isFinite else {return nil}
        let first = max(0,min(frameCount,Int((max(0,min(duration,start))*44100).rounded())))
        let last = max(0,min(frameCount,Int((max(0,min(duration,end))*44100).rounded())))
        guard last-first >= 882 else {return nil} // 20 ms minimum, with sample-aligned boundaries.
        return PlaybackRange(start:Double(first)/44100,end:Double(last)/44100)
    }
    public func wav(in range: PlaybackRange, smoothLoop: Bool = false) throws -> Data {
        guard let range = boundedRange(start:range.start,end:range.end) else {throw ModuleError.invalid("La plage de lecture est trop courte ou invalide.")}
        let start = Int((range.start*44100).rounded()), end = min(frameCount,Int((range.end*44100).rounded()))
        var output = Data(result.wav.prefix(44))
        output.append(result.wav[(44+start*4)..<(44+end*4)])
        func write(_ value: Int,at offset: Int) { for i in 0..<4 {output[offset+i] = UInt8((value>>(i*8))&255)} }
        write(output.count-8,at:4); write(output.count-44,at:40)
        if smoothLoop {
            // A 2 ms de-click at each edge; preserve length, timing and the rendered DSP state.
            let ramp = min(88,(end-start)/2)
            for i in 0..<ramp {
                let gain = Double(i)/Double(ramp)
                for frame in [i,end-start-1-i] { for channel in 0..<2 {
                    let offset = 44+frame*4+channel*2
                    let sample = Int16(bitPattern:UInt16(output[offset]) | UInt16(output[offset+1])<<8)
                    let value = UInt16(bitPattern:Int16(Double(sample)*gain))
                    output[offset] = UInt8(value&255); output[offset+1] = UInt8(value>>8)
                } }
            }
        }
        return output
    }
}
