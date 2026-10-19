import SwiftUI
import AppKit

struct PatternEditorFocus: FocusedValueKey {typealias Value = Studio}
extension FocusedValues {
    var patternEditor: Studio? {get {self[PatternEditorFocus.self]} set {self[PatternEditorFocus.self] = newValue}}
}
struct PatternEditingCommands: Commands {
    @ObservedObject var studio: Studio
    @FocusedValue(\.patternEditor) private var editor
    func route(_ selector: String,_ action: (Studio) -> Void) {
        if NSApp.keyWindow?.firstResponder is NSTextView || NSApp.keyWindow?.firstResponder is NSTextField {
            NSApp.sendAction(Selector(selector),to:nil,from:nil)
        } else if let editor {action(editor)} else {NSApp.sendAction(Selector(selector),to:nil,from:nil)}
    }
    var body: some Commands {
        CommandGroup(replacing:.pasteboard) {
            Button("Couper") {route("cut:",{$0.cutBlock()})}.keyboardShortcut("x").disabled(editor != nil && editor?.canCompose != true)
            Button("Copier") {route("copy:",{$0.copyBlock()})}.keyboardShortcut("c").disabled(editor != nil && editor?.canCompose != true)
            Button("Coller") {route("paste:",{$0.pasteBlock()})}.keyboardShortcut("v").disabled(editor != nil && editor?.canCompose != true)
            Button("Tout sélectionner") {route("selectAll:",{$0.selectPattern()})}.keyboardShortcut("a")
        }
        CommandMenu("Composition") {
            Group {
            Button("Sélectionner le pattern") {studio.selectPattern()}
            Divider()
            Button("Copier le bloc") {studio.copyBlock()}
            Button("Couper le bloc") {studio.cutBlock()}
            Button("Coller en remplaçant") {studio.pasteBlock()}
            Button("Coller en mélangeant") {studio.pasteBlock(mix:true)}
            Button("Effacer la sélection") {studio.clearSelection()}
            Button("Dupliquer sous la sélection") {studio.duplicateBlock()}.keyboardShortcut("d")
            Divider()
            Button("Monter d’un demi-ton") {studio.transpose(1)}.keyboardShortcut(.upArrow,modifiers:[.command,.option])
            Button("Descendre d’un demi-ton") {studio.transpose(-1)}.keyboardShortcut(.downArrow,modifiers:[.command,.option])
            Button("Monter d’une octave") {studio.transpose(12)}
            Button("Descendre d’une octave") {studio.transpose(-12)}
            Menu("Transposer le pattern entier") {
                Button("+1 demi-ton") {studio.transpose(1,wholePattern:true)}
                Button("−1 demi-ton") {studio.transpose(-1,wholePattern:true)}
            }
            Menu("Déplacer le bloc") {
                Button("Une ligne vers le haut") {studio.moveBlock(rows:-1)}
                Button("Une ligne vers le bas") {studio.moveBlock(rows:1)}
                Button("Une piste à gauche") {studio.moveBlock(rows:0,channels:-1)}
                Button("Une piste à droite") {studio.moveBlock(rows:0,channels:1)}
            }
            Divider()
            Toggle("Lignes : toutes les pistes",isOn:$studio.rowsAllTracks)
            Button("Insérer les lignes sélectionnées") {studio.shiftLines(insert:true)}.disabled(studio.isSymphonie)
            Button("Supprimer les lignes sélectionnées") {studio.shiftLines(insert:false)}.disabled(studio.isSymphonie)
            }.disabled(!studio.canCompose)
        }
    }
}

struct CompositionToolsView: View {
    @EnvironmentObject var s: Studio
    @State private var showingTools = false
    @AppStorage("keyboard.layout") private var layout = MusicalKeyboard.qwerty.rawValue
    var keyboard: MusicalKeyboard {MusicalKeyboard(rawValue:layout) ?? .qwerty}
    var body: some View {
        HStack(spacing:14) {
            Text(String(format:"%02X–%02X · pistes %d–%d",s.selection.rowRange.lowerBound,s.selection.rowRange.upperBound,s.selection.channels.lowerBound+1,s.selection.channels.upperBound+1))
                .font(.system(size:10,design:.monospaced)).lineLimit(1)
            Spacer(minLength:0)
            Button {s.copyBlock()} label:{Image(systemName:"doc.on.doc")}.help("Copier · ⌘C dans la partition")
            Button {s.cutBlock()} label:{Image(systemName:"scissors")}.help("Couper · ⌘X dans la partition")
            Button {s.pasteBlock()} label:{Image(systemName:"doc.on.clipboard")}.help("Coller en remplaçant · ⌘V dans la partition")
            Button("−1") {s.transpose(-1)}.help("Transposer la sélection d’un demi-ton vers le bas")
            Button("+1") {s.transpose(1)}.help("Transposer la sélection d’un demi-ton vers le haut")
            Button {showingTools.toggle()} label:{Label("Composer",systemImage:"pianokeys")}
                .popover(isPresented:$showingTools) {tools}
        }.font(.system(size:11)).buttonStyle(.plain).padding(.horizontal,18).frame(height:34).disabled(!s.canCompose)
    }
    var tools: some View {
        VStack(alignment:.leading,spacing:14) {
            Text(s.isSymphonie ? "Composer dans la source SymMOD" : "Outils de composition MOD").font(.headline)
            Text("Majuscule + clic ou Majuscule + flèches : étendre le bloc. ⌘A dans la partition : tout sélectionner.").font(.caption)
            HStack {
                Stepper("Fin : ligne \(String(format:"%02X",s.selection.focusRow))",value:Binding(get:{s.selection.focusRow},set:{s.extendSelection(toRow:$0,channel:s.selection.focusChannel)}),in:0...s.rows-1)
                Stepper("piste \(s.selection.focusChannel+1)",value:Binding(get:{s.selection.focusChannel},set:{s.extendSelection(toRow:s.selection.focusRow,channel:$0)}),in:0...s.module.channelCount-1)
            }.font(.caption)
            HStack {Button("Pattern entier") {s.selectPattern()}; Button("Mélanger le collage") {s.pasteBlock(mix:true)}; Button("Dupliquer en dessous") {s.duplicateBlock()}}
            Text(s.isSymphonie ? "Un collage remplace les événements entiers ; mélanger ignore les cellules vides. Les commandes protégées bloquent l’opération entière. Banque identique requise : recopie le bloc après une édition d’instrument." : "Remplacer colle tous les champs, y compris les vides. Mélanger ne colle que les champs non vides. Les instruments restent des numéros de samples du morceau destinataire. Un bloc qui dépasse est refusé.").font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("Déplacer")
                Button {s.moveBlock(rows:-1)} label:{Image(systemName:"arrow.up")}.help("Une ligne vers le haut")
                Button {s.moveBlock(rows:1)} label:{Image(systemName:"arrow.down")}.help("Une ligne vers le bas")
                Button {s.moveBlock(rows:0,channels:-1)} label:{Image(systemName:"arrow.left")}.help("Une piste à gauche")
                Button {s.moveBlock(rows:0,channels:1)} label:{Image(systemName:"arrow.right")}.help("Une piste à droite")
                Spacer()
                Button("−12") {s.transpose(-12)}; Button("+12") {s.transpose(12)}
            }
            if !s.isSymphonie {Toggle("Insertion / suppression sur les quatre pistes",isOn:$s.rowsAllTracks)
            HStack {Button("Insérer les lignes") {s.shiftLines(insert:true)}; Button("Supprimer les lignes") {s.shiftLines(insert:false)}}
            Text("Le nombre de lignes du bloc est utilisé. Sinon, seules ses pistes sont décalées. Le pattern garde 64 lignes : l’insertion retire les dernières, la suppression ajoute des lignes vides à la fin.").font(.caption).foregroundStyle(.secondary)}
            Divider()
            HStack {
                Stepper("Octave \(s.octave)",value:$s.octave,in:(s.isSymphonie ? 2 : 1)...(s.isSymphonie ? 9 : 3))
                Stepper("Avance \(s.advance)",value:$s.advance,in:0...16)
            }
            if s.isSymphonie {Stepper("Instrument source clavier : \(s.sample)",value:$s.sample,in:0...max(0,min(255,(s.symArchive?.instrumentCount ?? 1)-1)))}
            Picker("Clavier musical",selection:$layout) {ForEach(MusicalKeyboard.allCases) {Text($0.title).tag($0.rawValue)}}
            Text("Octave courante : "+keyboard.lower.joined(separator:"  ")+"\nOctave supérieure : "+keyboard.upper.joined(separator:"  ")).font(.system(size:11,design:.monospaced))
            Text("Correspondance : do, do♯, ré, ré♯, mi, fa, fa♯, sol, sol♯, la, la♯, si. Les touches sont les caractères de votre disposition active. MOD : trois octaves. SymMOD : hauteurs source 0…84 avant transposition.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width:490)
    }
}
