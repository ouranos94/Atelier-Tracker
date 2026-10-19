import SwiftUI
import TrackerCore

struct RecoveryRecord: Codable,Sendable,Identifiable {
    var id = UUID()
    var version = 1
    var date = Date()
    var module: Module
    var filePath: String?
    var order: Int, row: Int, channel: Int, sample: Int
    var blockOrder: Int
    var block: PatternSelection?
    var sampleSelection: SampleRegion?
    var sampleZoom: Double, sampleViewOffset: Double
}
actor RecoveryStore {
    let directory: URL
    init(directory: URL) {self.directory = directory}
    static var defaultDirectory: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Atelier Tracker/Recovery",isDirectory:true)
    }
    private var current: URL {directory.appendingPathComponent("current.json")}
    private var previous: URL {directory.appendingPathComponent("previous.json")}
    private func validData(at url: URL) -> (RecoveryRecord,Data)? {
        guard let size = try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize, size <= 64*1024*1024,
              let data = try? Data(contentsOf:url), let record = try? JSONDecoder().decode(RecoveryRecord.self,from:data),
              record.version == 1, (try? ModuleValidation.validate(record.module)) != nil else {return nil}
        return (record,data)
    }
    func candidates() -> [RecoveryRecord] {[current,previous].compactMap {validData(at:$0)?.0}}
    func save(_ record: RecoveryRecord) throws {
        try Task.checkCancellation()
        try ModuleValidation.validate(record.module)
        let data = try JSONEncoder().encode(record)
        guard data.count <= 64*1024*1024 else {throw ModuleError.invalid("La session dépasse la taille de récupération autorisée.")}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        if let (_,old) = validData(at:current) {try old.write(to:previous,options:.atomic)}
        try Task.checkCancellation()
        try data.write(to:current,options:.atomic)
    }
    func clear() throws {
        for url in [current,previous] where FileManager.default.fileExists(atPath:url.path) {try FileManager.default.removeItem(at:url)}
    }
}
@MainActor extension Studio {
    func enableRecovery(directory: URL = RecoveryStore.defaultDirectory) async {
        guard recoveryStore == nil else {return}
        let store = RecoveryStore(directory:directory); recoveryStore = store
        let candidates = await store.candidates()
        for record in candidates {
            if (try? validate(record.module)) != nil {recoveryCandidate = record; break}
        }
        recoveryReady = true
        recoveryStatus = "Récupération automatique active"
        if hasChanges && recoveryCandidate == nil {scheduleRecovery()}
    }
    var recoveryRecord: RecoveryRecord {
        RecoveryRecord(module:module,filePath:fileURL?.path,order:order,row:row,channel:channel,sample:sample,blockOrder:blockOrder,block:block,sampleSelection:sampleSelection,sampleZoom:sampleZoom,sampleViewOffset:sampleViewOffset)
    }
    func scheduleRecovery() {
        guard let store = recoveryStore, recoveryReady, hasChanges, recoveryCandidate == nil else {return}
        recoveryJob?.cancel(); let token = UUID(); recoveryGeneration = token
        recoveryJob = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds:500_000_000)
                guard let self, self.recoveryGeneration == token else {return}
                await self.recoveryResetJob?.value
                try Task.checkCancellation()
                guard self.recoveryGeneration == token else {return}
                let record = self.recoveryRecord
                try await store.save(record)
                guard !Task.isCancelled, self.recoveryGeneration == token else {return}
                self.recoveryStatus = "Récupération enregistrée à "+record.date.formatted(date:.omitted,time:.shortened)
            } catch is CancellationError {} catch {
                guard let self, self.recoveryGeneration == token else {return}
                self.recoveryStatus = "Échec de récupération : "+error.localizedDescription
            }
        }
    }
    func clearRecovery() async {
        recoveryJob?.cancel(); recoveryJob = nil; recoveryGeneration = UUID()
        await recoveryResetJob?.value
        guard let recoveryStore else {return}
        do {try await recoveryStore.clear(); recoveryStatus = "Récupération automatique active"}
        catch {recoveryStatus = "Impossible d’effacer la récupération : "+error.localizedDescription}
    }
    func clearRecoveryForNewSession() {
        recoveryJob?.cancel(); recoveryGeneration = UUID()
        guard recoveryReady, recoveryCandidate == nil else {return}
        let store = recoveryStore
        let previousReset = recoveryResetJob
        // Enqueue clearing now, before any future save for the new document.
        recoveryResetJob = Task {await previousReset?.value; if let store {try? await store.clear()}}
    }
    func restoreRecovery() {
        guard let record = recoveryCandidate, confirmDiscard() else {return}
        do {
            try validate(record.module)
            recoveryJob?.cancel(); recoveryGeneration = UUID()
            replaceModule(with:record.module)
            fileURL = record.filePath.map {URL(fileURLWithPath:$0)}
            order = min(max(0,record.order),module.orders.count-1)
            row = min(max(0,record.row),rows-1); channel = min(max(0,record.channel),module.channelCount-1)
            sample = min(max(0,record.sample),module.samples.count-1)
            blockOrder = order
            block = record.blockOrder == order && record.block?.isValid == true ? record.block : nil
            sampleSelection = record.sampleSelection?.valid(for:currentSample.data.count) == true ? record.sampleSelection : nil
            sampleZoom = record.sampleZoom.isFinite ? min(64,max(1,record.sampleZoom)) : 1
            sampleViewOffset = record.sampleViewOffset.isFinite ? min(1,max(0,record.sampleViewOffset)) : 0
            undoStack = []; redoStack = []; hasChanges = true; recoveryCandidate = nil
            scheduleRecovery(); status = "Session récupérée · enregistre le projet pour la conserver"
            if automaticallyPrepare {prepareTransport()}
        } catch {self.error = error.localizedDescription}
    }
    func ignoreRecovery() {
        recoveryCandidate = nil
        Task {await clearRecovery(); if hasChanges {scheduleRecovery()}}
    }
}
struct RecoveryOfferView: View {
    @EnvironmentObject var s: Studio
    let record: RecoveryRecord
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Label("Récupérer une session",systemImage:"clock.arrow.circlepath").font(.title2)
            Text(record.module.title).font(.headline)
            Text(record.date.formatted(date:.abbreviated,time:.standard)).foregroundStyle(.secondary)
            Text("Une copie de travail est disponible. Restaurer retrouve les notes, les samples et les sélections, sans modifier le fichier enregistré. L’historique d’annulation n’est pas récupéré.")
            HStack {
                Button("Ignorer cette récupération") {s.ignoreRecovery()}
                Spacer()
                Button("Restaurer") {s.restoreRecovery()}.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width:520).interactiveDismissDisabled()
    }
}
