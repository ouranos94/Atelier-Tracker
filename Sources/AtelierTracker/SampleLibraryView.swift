import SwiftUI
import AppKit
import TrackerCore

struct SampleLibraryView: View {
    @EnvironmentObject var s: Studio
    @Environment(\.dismiss) var dismiss
    @State private var entries: [LibrarySample] = []
    @State private var query = ""
    @State private var importVisible = false
    @State private var importPath = ""
    @State private var favorites = false
    @State private var selected: String?
    @State private var rename = ""
    private var store: SampleLibraryStore {SampleLibraryStore(directory:FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AtelierTracker/SampleLibrary",isDirectory:true))}
    private var visible: [LibrarySample] {entries.filter {(!favorites || $0.favorite) && $0.matches(query)}.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}}
    private var entry: LibrarySample? {entries.first {$0.id == selected}}
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("Bibliothèque de samples").font(.title2.bold());Spacer();Button("Ajouter…") {importVisible.toggle()};Button("Fermer") {dismiss()}}
            if importVisible {HStack {TextField("Chemin WAV / AIFF, ou déposer les fichiers dans la bibliothèque",text:$importPath).textFieldStyle(.roundedBorder);Button("Ajouter ce fichier") {add([URL(fileURLWithPath:(importPath as NSString).expandingTildeInPath)])}.disabled(importPath.isEmpty)}}
            HStack {TextField("Rechercher un sample",text:$query).textFieldStyle(.roundedBorder);Toggle("Favoris",isOn:$favorites)}
            List(selection:$selected) {
                ForEach(visible) {entry in
                    HStack {Button {favorite(entry)} label:{Image(systemName:entry.favorite ? "star.fill" : "star")}.buttonStyle(.borderless).help("Favori");Text(entry.name);Spacer();Text(String(format:"%.2f s",Double(entry.frames)/40460)).foregroundStyle(.secondary)}.tag(entry.id)
                }
            }.overlay {if visible.isEmpty {Text("Ajoute des WAV ou AIFF, ou dépose-les ici.").foregroundStyle(.secondary)}}
            if let entry {
                HStack {TextField("Nom",text:$rename).textFieldStyle(.roundedBorder);Button("Renommer") {renameEntry(entry)};Button("Écouter") {audition(entry)};Button("Arrêter") {s.stopSamplePreview()}}
                HStack {Text("Instrument cible : \(s.sample+(s.isSymphonie ? 0 : 1)) · \(s.isSymphonie ? "SymMOD mono 16 bits" : "MOD mono 8 bits")").font(.caption);Spacer();Button("Utiliser ce sample") {s.importSample(url:store.url(entry))}.buttonStyle(.borderedProminent).disabled(s.playing || s.rendering || s.consolePreparing)}
            }
            Text("Copies locales en mono 16 bits / 40 460 Hz, jusqu’à 60 s. Les fichiers d’origine restent intacts. L’utilisation dans un MOD applique ses limites 8 bits / 7,91 s.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width:740,height:530).symEditorSurface().symMODErrorAlert(s)
        .onAppear {reload()}.onDisappear {s.stopSamplePreview()}
        .onChange(of:selected) {_,_ in rename = entry?.name ?? "";s.stopSamplePreview()}
        .dropDestination(for:URL.self) {urls,_ in add(urls);return !urls.isEmpty}
    }
    private func reload() {do {entries = try store.load()} catch {s.error = error.localizedDescription}}

    private func add(_ urls: [URL]) {for url in urls {do {entries = try store.adding(AudioImport.pcm(url),name:url.deletingPathExtension().lastPathComponent)} catch {s.error = "\(url.lastPathComponent) : \(error.localizedDescription)";break}}}
    private func favorite(_ entry: LibrarySample) {var next = entries;guard let i = next.firstIndex(where:{$0.id == entry.id}) else {return};next[i].favorite.toggle();persist(next)}
    private func renameEntry(_ entry: LibrarySample) {let name = rename.trimmingCharacters(in:.whitespacesAndNewlines);guard !name.isEmpty,let i = entries.firstIndex(where:{$0.id == entry.id}) else {return};var next = entries;next[i].name = String(name.prefix(200));persist(next)}
    private func persist(_ next: [LibrarySample]) {do {try store.save(next);entries = next} catch {s.error = error.localizedDescription}}
    private func audition(_ entry: LibrarySample) {do {let pcm = try AudioImport.pcm(store.url(entry));s.previewPCM(pcm,range:0..<pcm.samples.count,loop:false)} catch {s.error = error.localizedDescription}}
}
