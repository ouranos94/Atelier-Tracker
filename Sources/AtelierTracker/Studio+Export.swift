import SwiftUI
import UniformTypeIdentifiers
import TrackerCore

@MainActor extension Studio {
    func chooseMixExport(separate: Bool) {
        guard phase != .exporting, !consolePreparing else {return}
        guard !separate || consoleCache != nil else {error = "Prépare les pistes dans la console avant leur export."; return}
        let name = exportName.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains(":"), !name.contains("\0") else {error = "Choisis un nom d’export sans barre oblique ni deux-points."; return}
        let path = (exportDirectory as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath:path,isDirectory:&isDirectory), isDirectory.boolValue, FileManager.default.isWritableFile(atPath:path) else {error = "Choisis un dossier de destination existant et accessible en écriture."; return}
        let filename = separate ? name+" — pistes" : (name.lowercased().hasSuffix(".wav") ? name : name+".wav")
        let url = URL(fileURLWithPath:path,isDirectory:true).appendingPathComponent(filename,isDirectory:separate)
        guard !FileManager.default.fileExists(atPath:url.path) else {error = "Ce nom existe déjà dans le dossier de destination. Choisis un autre nom."; return}
        exportPresented = false
        let generation = playbackGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.playbackGeneration == generation else {return}
            self.startMixExport(to:url,separate:separate)
        }
    }
    func startMixExport(to url: URL,separate: Bool) {
        let snapshot = module, config = mix, silence = muted, solo = solos
        let cache = (consoleActive || separate) ? consoleCache : nil
        let original = preparedAudio
        stop(); phase = .exporting; exportProgress = 0; status = "Export WAV…"
        let generation = playbackGeneration
        job = Task { [weak self] in
            do {
                let studio = self
                let worker = Task.detached(priority:.userInitiated) {
                    let source: StemCache
                    var settings: MixConfiguration
                    if let cache {source = cache; settings = config}
                    else {
                        let timeline = try original ?? PlaybackTimeline(Renderer.render(snapshot))
                        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Atelier-Export-"+UUID().uuidString)
                        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
                        do {
                            let file = dir.appendingPathComponent("original.wav"); try timeline.result.wav.write(to:file)
                            source = try StemCache(directory:dir,files:[file],frameCount:timeline.frameCount)
                        } catch {try? FileManager.default.removeItem(at:dir); throw error}
                        settings = MixConfiguration(channels:1); settings.master = config.master
                    }
                    try Task.checkCancellation()
                    try MixExporter.write(cache:source,mix:settings,muted:cache == nil ? [] : silence,solo:cache == nil ? [] : solo,separate:separate,to:url) {value in
                        Task { @MainActor [studio] in guard let owner = studio, owner.playbackGeneration == generation else {return}; owner.exportProgress = value}
                    }
                }
                try await withTaskCancellationHandler {try await worker.value} onCancel: {worker.cancel()}
                try Task.checkCancellation()
                guard let self, self.playbackGeneration == generation else {return}
                self.phase = .stopped; self.exportProgress = 1; self.status = separate ? "Pistes séparées exportées" : "Mixage WAV exporté"; self.job = nil
            } catch is CancellationError {} catch {
                guard let self, self.playbackGeneration == generation else {return}
                self.phase = .stopped; self.error = error.localizedDescription; self.job = nil
            }
        }
    }
}
