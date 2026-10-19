import SwiftUI
import TrackerCore

@main struct AtelierApp: App {
    @AppStorage("appearance") private var appearance = ThemeMode.dark.rawValue
    @AppStorage("score.zoom") private var scoreZoom = 1.0
    @AppStorage("score.font") private var scoreFont = 13.0
    @AppStorage("score.arrangementVisible") private var arrangementVisible = true
    @AppStorage("score.inspectorVisible") private var inspectorVisible = true
    @AppStorage("score.overviewPanels") private var overviewPanels = false
    @StateObject private var studio = Studio()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            StudioView().environmentObject(studio).preferredColorScheme((ThemeMode(rawValue:appearance) ?? .dark).colorScheme)
                .frame(minWidth:1120,minHeight:720)
                .onOpenURL { studio.open(url:$0) }
                .onAppear { delegate.studio = studio; Task {await studio.enableRecovery(); studio.enableTransportPreparation()}; NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps:true) }
        }
        .windowStyle(.hiddenTitleBar).defaultSize(width:1380,height:900)
        .commands {
            PatternEditingCommands(studio:studio)
            CommandGroup(replacing:.newItem) {
                Button("Nouveau morceau") { studio.newModule() }.keyboardShortcut("n")
                Button("Nouveau SymMOD…") {studio.newSymPresented = true}
                Button("Bibliothèque de samples…") {studio.libraryPresented = true}
                Button("Clavier MIDI…") {studio.midiPresented = true}
                Button("Ouvrir…") { studio.open() }.keyboardShortcut("o")
                Button("Enregistrer") { studio.save() }.keyboardShortcut("s").disabled(studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Enregistrer sous…") { studio.save(as:true) }.keyboardShortcut("s",modifiers:[.command,.shift]).disabled(studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Divider()
                Button("Exporter MOD…") { studio.save(mod:true) }
                Button("Éditer l’arrangement SymMOD…") {studio.symArrangementPresented = true}.disabled(!studio.isSymphonie || studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Éditer les instruments SymMOD…") {studio.symInstrumentPresented = true}.disabled(!studio.isSymphonie || studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Éditer les patterns SymMOD…") {studio.symEditorPresented = true}.disabled(!studio.isSymphonie || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Exporter SymMOD…") {studio.exportSymMOD()}.disabled(!studio.isSymphonie || studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Exporter WAV…") { studio.exportWAV() }.keyboardShortcut("e").disabled(studio.symEditorPresented || studio.symInstrumentPresented || studio.symArrangementPresented)
                Button("Charger la démo") { studio.newModule(demo:true) }
            }
            CommandGroup(replacing:.undoRedo) {
                Button("Annuler") { studio.undo() }.keyboardShortcut("z").disabled(studio.undoStack.isEmpty)
                Button("Rétablir") { studio.redo() }.keyboardShortcut("z",modifiers:[.command,.shift]).disabled(studio.redoStack.isEmpty)
            }
            CommandMenu("Apparence") {
                Picker("Thème",selection:$appearance) {
                    ForEach(ThemeMode.allCases) { theme in Text(theme.title).tag(theme.rawValue) }
                }
            }
            CommandMenu("Partition") {
                Button("Élargir les pistes") {scoreZoom = min(2.5,scoreZoom+0.1)}.keyboardShortcut("=")
                Button("Réduire les pistes") {scoreZoom = max(1,scoreZoom-0.1)}.keyboardShortcut("-")
                Button("Agrandir les notes") {scoreFont = min(20,scoreFont+1)}.keyboardShortcut("=",modifiers:[.command,.shift])
                Button("Réduire les notes") {scoreFont = max(10,scoreFont-1)}.keyboardShortcut("-",modifiers:[.command,.shift])
                Divider()
                Toggle("Arrangement et instruments",isOn:$arrangementVisible)
                Toggle("Inspecteur",isOn:$inspectorVisible)
                Toggle("Panneaux en vue générale",isOn:$overviewPanels)
                Divider()
                Button("Toutes les pistes") {if studio.isSymphonie {studio.channelPage = -1}}.disabled(!studio.isSymphonie)
                Button("Piste sélectionnée") {if studio.isSymphonie {studio.channelPage = -2}}.disabled(!studio.isSymphonie)
            }
            CommandMenu("Lecture") {
                Button("Lecture / Pause") { studio.play() }.keyboardShortcut(.space,modifiers:[])
                Button("Arrêt / Annuler") { studio.stop() }.keyboardShortcut(.escape,modifiers:[])
                Button("Depuis la sélection") { studio.playFromSelection() }.keyboardShortcut(.return,modifiers:[.shift])
                Button("Boucle du pattern") { studio.setLoop(studio.loopMode == .pattern ? .off : .pattern) }.keyboardShortcut("l")
                Button("Repère A") { studio.markA() }.keyboardShortcut("i",modifiers:[.option])
                Button("Repère B") { studio.markB() }.keyboardShortcut("o",modifiers:[.option])
                Button("Lire le pattern") { studio.play(patternOnly:true) }.keyboardShortcut(.return,modifiers:[])
                Button("Écouter le sample") { studio.preview() }
            }
        }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var studio: Studio?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard studio?.confirmDiscard() != false else {return .terminateCancel}
        Task {await studio?.clearRecovery(); sender.reply(toApplicationShouldTerminate:true)}
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
