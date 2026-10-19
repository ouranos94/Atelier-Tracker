import Foundation

public enum MixExporter {
    /// Floating point files retain headroom. All stems share frame zero and length.
    public static func write(cache: StemCache,mix: MixConfiguration,muted: Set<Int> = [],solo: Set<Int> = [],separate: Bool,to destination: URL,progress: @Sendable (Double) -> Void = {_ in}) throws {
        try mix.validate(channels:cache.channels)
        let fm = FileManager.default
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".atelier-export-"+UUID().uuidString,isDirectory:separate)
        defer {try? fm.removeItem(at:stage)}
        guard !fm.fileExists(atPath:destination.path) else {throw ModuleError.invalid("Choisis un nouveau nom : ce fichier ou dossier existe déjà.")}
        if separate {try fm.createDirectory(at:stage,withIntermediateDirectories:false)}
        let count = separate ? cache.channels : 1
        for index in 0..<count {
            try Task.checkCancellation()
            let url = separate ? stage.appendingPathComponent(String(format:"Piste-%02d.wav",index+1)) : stage
            let dsp = try ConsoleDSP(cache:cache,clampOutput:false)
            var silence = muted
            if separate {silence.formUnion(Set(0..<cache.channels).subtracting([index]))}
            try dsp.apply(mix,muted:silence,solo:solo); dsp.playing = true
            let bytes = cache.frameCount*8
            guard bytes <= Int(UInt32.max)-36 else {throw ModuleError.invalid("Export trop long pour un fichier WAV standard.")}
            var header = Data("RIFF".utf8)
            func u32(_ x: Int) {var v = UInt32(x).littleEndian; withUnsafeBytes(of:&v) {header.append(contentsOf:$0)}}
            func u16(_ x: Int) {var v = UInt16(x).littleEndian; withUnsafeBytes(of:&v) {header.append(contentsOf:$0)}}
            u32(bytes+36); header.append(Data("WAVEfmt ".utf8)); u32(16); u16(3); u16(2); u32(44100); u32(352800); u16(8); u16(32); header.append(Data("data".utf8)); u32(bytes)
            guard fm.createFile(atPath:url.path,contents:header) else {throw ModuleError.invalid("Impossible de créer le WAV.")}
            let file = try FileHandle(forWritingTo:url)
            do {
                try file.seekToEnd()
                var left = [Float](repeating:0,count:8192), right = left, stereo = [Float](repeating:0,count:16384)
                var frame = 0, lastPercent = -1
                while frame < cache.frameCount {
                    try Task.checkCancellation()
                    let n = min(8192,cache.frameCount-frame)
                    left.withUnsafeMutableBufferPointer {l in right.withUnsafeMutableBufferPointer {r in dsp.render(count:n,left:l.baseAddress!,right:r.baseAddress!)}}
                    for i in 0..<n {stereo[i*2] = left[i]; stereo[i*2+1] = right[i]}
                    try stereo.withUnsafeBytes {try file.write(contentsOf:Data($0.prefix(n*8)))}
                    frame += n
                    let fraction = (Double(index)+Double(frame)/Double(cache.frameCount))/Double(count)
                    let percent = Int(fraction*100)
                    if percent != lastPercent {progress(fraction); lastPercent = percent}
                }
                try file.close()
            } catch {try? file.close(); throw error}
        }
        if separate {
            let description = "Atelier Tracker — WAV stéréo float32, 44 100 Hz\nDépart commun : 0 ; durée : \(cache.frameCount) frames.\nVolumes, balance et niveau général appliqués ; pistes muettes : \(muted.sorted()); solos : \(solo.sorted()).\nDSP rendus indépendamment par piste. Les effets partagés/non linéaires SymMOD peuvent différer du mix original. Fin commune au rendu du morceau, aucune queue supplémentaire. Pas de limitation des crêtes : réduire le niveau si nécessaire.\n"
            try description.write(to:stage.appendingPathComponent("Lisez-moi.txt"),atomically:true,encoding:.utf8)
            try JSONEncoder().encode(mix).write(to:stage.appendingPathComponent("Mixage.json"))
        }
        try Task.checkCancellation()
        try fm.moveItem(at:stage,to:destination)
    }
}
