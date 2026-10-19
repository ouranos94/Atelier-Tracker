import Foundation
import CryptoKit

public struct LibrarySample: Codable,Identifiable,Equatable,Sendable {
    public let id: String
    public var name: String
    public var favorite: Bool
    public let frames: Int
    public var filename: String {id+".wav"}
    public func matches(_ query: String) -> Bool {query.isEmpty || name.range(of:query,options:[.caseInsensitive,.diacriticInsensitive]) != nil}
}
public struct SampleLibraryStore {
    public let directory: URL
    public init(directory: URL) {self.directory = directory}
    private var manifest: URL {directory.appendingPathComponent("library.json")}
    public func load() throws -> [LibrarySample] {
        guard FileManager.default.fileExists(atPath:manifest.path) else {return []}
        let entries = try JSONDecoder().decode([LibrarySample].self,from:Data(contentsOf:manifest))
        guard entries.count <= 10000,Set(entries.map(\.id)).count == entries.count,entries.allSatisfy({$0.id.count == 64 && $0.id.allSatisfy {"0123456789abcdef".contains($0)} && $0.frames > 0 && $0.frames <= 2_500_000}) else {throw ModuleError.invalid("Catalogue de samples invalide.")}
        return entries
    }
    public func save(_ entries: [LibrarySample]) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try JSONEncoder().encode(entries).write(to:manifest,options:.atomic)
    }
    public func adding(_ pcm: SymPCM,name: String) throws -> [LibrarySample] {
        var entries = try load();let wav = try pcm.wav(),id = SHA256.hash(data:wav).map {String(format:"%02x",$0)}.joined()
        if entries.contains(where:{$0.id == id}) {return entries}
        guard entries.count < 10000 else {throw ModuleError.invalid("Bibliothèque limitée à 10 000 samples.")}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let destination = directory.appendingPathComponent(id+".wav")
        try wav.write(to:destination,options:.atomic)
        entries.append(LibrarySample(id:id,name:name,favorite:false,frames:pcm.samples.count))
        try save(entries);return entries
    }
    public func url(_ entry: LibrarySample) -> URL {directory.appendingPathComponent(entry.filename)}
}
