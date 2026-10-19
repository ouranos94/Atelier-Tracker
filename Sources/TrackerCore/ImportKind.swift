import Foundation

/// Route tracker songs before handing ordinary audio to AVFoundation.
public enum ImportKind: Equatable {
    case module, symphonie, project, audio
    public static func identify(url: URL, prefix: Data) -> ImportKind {
        if prefix.starts(with:Data("SymM".utf8)) || url.pathExtension.lowercased() == "symmod" { return .symphonie }
        let filename = url.lastPathComponent.lowercased()
        if url.pathExtension.lowercased() == "atelier" { return .project }
        if url.pathExtension.lowercased() == "mod" || filename.hasPrefix("mod.") { return .module }
        if prefix.count >= 1084 {
            let signature = String(bytes:prefix.dropFirst(1080).prefix(4),encoding:.ascii) ?? ""
            if ["M.K.","M!K!","4CHN","FLT4"].contains(signature) { return .module }
        }
        return .audio
    }
}
