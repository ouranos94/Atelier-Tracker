import Foundation

public struct SymMODOrderSource: Codable,Equatable,Sendable {
    public let sequence: Int, position: Int, pattern: Int, start: Int, length: Int, transpose: Int
}
public struct SymMODCell: Equatable,Sendable {
    public let pattern: Int, row: Int, channel: Int
}
extension SymMODDocument {
    /// Mirrors the pinned native reader's order expansion, and verifies its shape and deduplication.
    /// No guessed mapping is returned when a skip, length or pattern identity disagrees.
    public func orderMapping(orders: [Int],patternRows: [Int]) -> [SymMODOrderSource?]? {
        guard canEdit else {return nil}
        var result: [SymMODOrderSource?] = [], keys: [String:Int] = [:], reverse: [Int:String] = [:]
        for (s,q) in sequences.enumerated() {
            if q.info == -1 {break}
            if q.info == 1 {continue}
            guard q.info == 0 else {return nil}
            guard positions.indices.contains(q.start), q.length > 0, q.length <= positions.count-q.start else {continue}
            if !result.isEmpty {result.append(nil)}
            for i in q.start..<q.start+q.length {
                let p = positions[i]
                guard p.pattern < patternCount, p.start < rows, p.length > 0, p.length <= 1024,
                      p.pattern*rows+p.start+p.length <= patternCount*rows else {return nil}
                let entry = SymMODOrderSource(sequence:s,position:i,pattern:p.pattern,start:p.start,length:p.length,transpose:p.transpose+q.transpose)
                let key = "\(p.pattern):\(p.start):\(p.length):\(p.speed):\(entry.transpose)"
                for _ in 0..<max(1,p.repeats) {
                    guard result.count < orders.count else {return nil}
                    let native = orders[result.count]
                    guard patternRows.indices.contains(native), patternRows[native] == p.length,
                          keys[key] == nil || keys[key] == native, reverse[native] == nil || reverse[native] == key else {return nil}
                    keys[key] = native; reverse[native] = key; result.append(entry)
                }
            }
        }
        guard result.count == orders.count else {return nil}
        return result
    }
    public func cell(in entry: SymMODOrderSource,row: Int,channel: Int) throws -> SymMODCell {
        guard (0..<patternCount).contains(entry.pattern), (0..<rows).contains(entry.start), (1...1024).contains(entry.length), row >= 0, row < entry.length, (0..<channels).contains(channel) else {throw ModuleError.invalid("Cellule traduite hors limites.")}
        let linear = entry.pattern*rows+entry.start+row
        guard linear >= 0, linear < patternCount*rows else {throw ModuleError.invalid("Correspondance source hors limites.")}
        return SymMODCell(pattern:linear/rows,row:linear%rows,channel:channel)
    }
}
