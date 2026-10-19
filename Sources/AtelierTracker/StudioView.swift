import SwiftUI
import TrackerCore

struct StudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var palette: StudioPalette { StudioPalette(scheme:colorScheme) }
    @AppStorage("appearance") private var appearance = ThemeMode.dark.rawValue
    @AppStorage("keyboard.layout") private var keyboardLayout = MusicalKeyboard.qwerty.rawValue
    @EnvironmentObject var s: Studio
    @FocusState var gridFocused: Bool
    @AppStorage("score.overviewPanels") private var overviewPanels = false
    @AppStorage("score.arrangementVisible") private var arrangementVisible = true
    @AppStorage("score.inspectorVisible") private var inspectorVisible = true
    @AppStorage("score.leftWidth") private var leftWidth = 218.0
    @AppStorage("score.rightWidth") private var rightWidth = 222.0
    @AppStorage("score.font") private var scoreFont = 13.0
    @AppStorage("score.zoom") private var scoreZoom = 1.0
    private var symSource: Bool {s.symScoreSource}
    @State private var showDisplaySettings = false
    private var metrics: ScoreMetrics {ScoreMetrics(font:scoreFont-(s.isOverview ? 2 : 0),zoom:scoreZoom,compact:s.isOverview)}
    var body: some View {
        VStack(spacing:0) {
            header
            Rectangle().fill(palette.text.opacity(0.08)).frame(height:1)
            GeometryReader { geometry in
            HStack(spacing:0) {
                if arrangementVisible && (!s.isOverview || overviewPanels) {
                    sidebar.frame(width:ScoreMetrics.panelWidth(saved:leftWidth,available:geometry.size.width))
                    PanelResizeHandle(width:Binding(get:{ScoreMetrics.panelWidth(saved:leftWidth,available:geometry.size.width)},set:{leftWidth = $0}),label:"Largeur de l’arrangement")
                }
                VStack(spacing:0) {
                    transport
                    patternEditor
                    if !s.isOverview || overviewPanels { sampleEditor }
                }.frame(minWidth:600,maxWidth:.infinity)
                if inspectorVisible && (!s.isOverview || overviewPanels) {
                    PanelResizeHandle(width:Binding(get:{ScoreMetrics.panelWidth(saved:rightWidth,available:geometry.size.width)},set:{rightWidth = $0}),reversed:true,label:"Largeur de l’inspecteur")
                    inspector.frame(width:ScoreMetrics.panelWidth(saved:rightWidth,available:geometry.size.width))
                }
            }
            }
            if s.phase == .exporting {HStack {ProgressView(value:s.exportProgress); Text("Export \(Int(s.exportProgress*100)) %"); Button("Annuler") {s.stop()}}.padding()}
            MasterStrip(meters:s.masterMeters)
            footer
        }
        .focusedSceneValue(\.patternEditor,gridFocused && !s.auxiliarySheetPresented && !s.pianoVisible && !s.symSourceSheetPresented && !s.consolePresented && !s.exportPresented && !s.sampleEditorOpen ? s : nil)
        .onChange(of:s.auxiliarySheetPresented) {_,open in if open {gridFocused = false}}
        .onChange(of:s.symSourceSheetPresented) {_,open in if open {gridFocused = false}}
        .background(palette.background).foregroundStyle(palette.text).tint(palette.accent)
        .dropDestination(for:URL.self) { urls,_ in
            guard let url = urls.first else { return false }
            s.open(url:url); return true
        }
        .sheet(isPresented:$s.newSymPresented) {NewSymSongView().environmentObject(s)}
        .sheet(isPresented:$s.libraryPresented) {SampleLibraryView().environmentObject(s)}
        .sheet(isPresented:$s.midiPresented) {MIDISettingsView().environmentObject(s)}
        .sheet(isPresented:$s.symArrangementPresented) {SymMODArrangementView().environmentObject(s)}
        .sheet(isPresented:$s.symInstrumentPresented) {SymMODInstrumentView().environmentObject(s)}
        .sheet(isPresented:$s.symExportPresented) {SymMODExportView().environmentObject(s)}
        .sheet(isPresented:$s.symEditorPresented) {SymMODEditorView().environmentObject(s)}
        .sheet(isPresented:$s.consolePresented) {ConsoleView().environmentObject(s)}
        .sheet(isPresented:$s.exportPresented) {MixExportView().environmentObject(s)}
        .sheet(item:$s.recoveryCandidate) {record in RecoveryOfferView(record:record).environmentObject(s)}
        .alert("Atelier Tracker",isPresented:Binding(get:{s.error != nil && !s.symSourceSheetPresented && !s.auxiliarySheetPresented},set:{if !$0 {s.error = nil}})) { Button("OK") {s.error = nil} } message: {Text(s.error ?? "")}
    }
    var header: some View {
        HStack(spacing:14) {
            Image(systemName:"waveform.path").font(.system(size:23,weight:.medium)).foregroundStyle(palette.accent)
            VStack(alignment:.leading,spacing:2) {
                Text("ATELIER").font(.system(size:17,weight:.bold,design:.rounded)).tracking(3)
                Text("TRACKER STUDIO").font(.system(size:8,weight:.medium)).tracking(2.5).foregroundStyle(palette.secondary)
            }
            Spacer()
            VStack(spacing:3) {
                Text(s.module.title + (s.hasChanges ? " •" : "")).font(.system(size:14,weight:.semibold))
                Text("\(s.module.channelCount) PISTES   /   \(s.isSymphonie ? "SYMPHONIE PRO" : "SAMPLE BASED")   /   APPLE SILICON").font(.system(size:8,weight:.medium,design:.monospaced)).tracking(1).foregroundStyle(palette.secondary)
            }
            Spacer()
            Button {showDisplaySettings.toggle()} label:{Image(systemName:"slider.horizontal.3")}
                .help("Zoom, taille des notes et panneaux").accessibilityLabel("Réglages de la partition")
                .popover(isPresented:$showDisplaySettings) {displaySettings}
            Menu {
                Picker("Thème",selection:$appearance) {
                    ForEach(ThemeMode.allCases) { theme in Label(theme.title,systemImage:theme.symbol).tag(theme.rawValue) }
                }
            } label: {
                Image(systemName:(ThemeMode(rawValue:appearance) ?? .dark).symbol)
            }.menuStyle(.borderlessButton).fixedSize().help("Thème : Clair, Sombre ou Système").accessibilityLabel("Thème de l’application")
            Button {s.libraryPresented = true} label:{Image(systemName:"books.vertical")}.help("Bibliothèque de samples").accessibilityLabel("Bibliothèque de samples")
            Button {s.midiPresented = true} label:{Image(systemName:"pianokeys.inverse")}.help("Clavier MIDI").accessibilityLabel("Clavier MIDI")
            Button {s.open()} label: {Image(systemName:"folder")}.help("Ouvrir un morceau MOD, SymMOD ou un projet · ⌘O").accessibilityLabel("Ouvrir un morceau")
            Button {s.save()} label: {Image(systemName:"square.and.arrow.down")}.help("Enregistrer · ⌘S")
            if s.isSymphonie {Button {s.symEditorPresented = true} label:{Image(systemName:"pencil.and.list.clipboard")}.help("Éditer les patterns SymMOD d’origine").accessibilityLabel("Éditer les patterns SymMOD")}
            if s.isSymphonie {Button {s.symArrangementPresented = true} label:{Image(systemName:"list.bullet.rectangle")}.help("Éditer l’arrangement SymMOD source").accessibilityLabel("Arrangement SymMOD")}
            if s.isSymphonie {Button {s.symInstrumentPresented = true} label:{Image(systemName:"pianokeys")}.help("Propriétés des instruments SymMOD").accessibilityLabel("Instruments SymMOD")}
            Button {s.consolePresented = true} label: {Image(systemName:"slider.vertical.3")}.help("Console de mixage").accessibilityLabel("Console de mixage")
            Button {s.exportWAV()} label: {Label("Exporter",systemImage:"square.and.arrow.up")}.buttonStyle(.bordered).controlSize(.large)
        }.buttonStyle(.plain).padding(.horizontal,24).padding(.top,30).padding(.bottom,20)
    }
    var sidebar: some View {
        let module = s.module
        return VStack(alignment:.leading,spacing:0) {
            caption("PROJET").padding(.bottom,16)
            HStack {Image(systemName:"square.stack.3d.up").foregroundStyle(palette.accent); Text("Arrangement").font(.system(size:13,weight:.medium)); Spacer(); Text(String(format:"%02d",module.orders.count)).foregroundStyle(palette.secondary)}.padding(10).background(palette.accent.opacity(0.08),in:RoundedRectangle(cornerRadius:7))
            HStack {caption("SÉQUENCE"); Spacer(); Button {s.addOrder(duplicate:false)} label:{Image(systemName:"plus")}.help("Ajouter un pattern vide").disabled(s.isSymphonie && !s.canExpandSym)}.padding(.top,25).padding(.bottom,12)
            ScrollView {
                LazyVStack(spacing:5) {ForEach(module.orders.indices,id:\.self) { index in
                    Button {guard s.module.orders.indices.contains(index) else {return}; s.selectCell(order:index,row:0,channel:s.channel)} label: {
                        HStack {Text(String(format:"%02X",index)).foregroundStyle(index == s.order ? palette.accent : palette.secondary).frame(width:26); VStack(alignment:.leading,spacing:4) {Text(String(format:"Pattern %02X",module.orders[index])).font(.system(size:12,weight:.medium)); Text("\(module.rowCount(pattern:module.orders[index])) pas · \(module.channelCount) pistes").font(.system(size:10)).foregroundStyle(palette.secondary)}; Spacer(); if index == s.scoreOrder && (s.playing || s.paused) {Image(systemName:"speaker.wave.2.fill").font(.system(size:11)).foregroundStyle(palette.accent)}}.padding(10).background(index == s.order ? palette.text.opacity(0.06) : .clear,in:RoundedRectangle(cornerRadius:7))
                    }.buttonStyle(.plain)
                }}
            }.frame(maxHeight:190)
            HStack {if s.isSymphonie {Button("Partager") {s.appendSymPosition(reuse:true)}.disabled(!s.canExpandSym).help("Ajouter une occurrence du même pattern source")};Button("Dupliquer") {s.addOrder(duplicate:true)}.disabled(s.isSymphonie && !s.canExpandSym); Spacer(); Button {s.removeOrder()} label:{Image(systemName:"trash")}.disabled((s.isSymphonie && !s.canExpandSym) || module.orders.count == 1)}.font(.system(size:10)).padding(.top,10)
            HStack {caption("INSTRUMENTS"); Spacer(); Button {s.importSample()} label:{Image(systemName:"plus")}.help("Importer un sample")}.padding(.top,24).padding(.bottom,10)
            ScrollView {
                LazyVStack(spacing:3) {ForEach(module.samples.indices,id:\.self) { i in
                    Button {if s.module.samples.indices.contains(i) {s.sample = i}} label: {
                        HStack(spacing:9) {Text(String(format:"%02X",i+(s.isSymphonie ? 0 : 1))).font(.system(size:10,design:.monospaced)).foregroundStyle(i == s.sample ? palette.accent : palette.secondary); Image(systemName:module.samples[i].data.isEmpty && !s.isSymphonie ? "minus" : "waveform").foregroundStyle(i == s.sample ? palette.accent : palette.secondary).frame(width:14); Text(module.samples[i].name.isEmpty ? (s.isSymphonie ? "Instrument \(i+1)" : "Sample vide") : module.samples[i].name).font(.system(size:11)).lineLimit(1); Spacer()}.padding(.horizontal,9).padding(.vertical,8).background(i == s.sample ? palette.accent.opacity(0.1) : .clear,in:RoundedRectangle(cornerRadius:6))
                    }.buttonStyle(.plain)
                }}
            }
            Text("UNE IDÉE. \(module.channelCount) PISTES.").font(.system(size:8,weight:.medium)).tracking(1.3).foregroundStyle(palette.secondary).padding(.top,14)
        }.padding(16).background(palette.panel.opacity(0.55)).buttonStyle(.plain)
    }
    var transport: some View {
        VStack(spacing:12) {
            HStack(spacing:16) {
                Button {s.play()} label:{Image(systemName:s.playing ? "pause.fill" : "play.fill").font(.system(size:15)).foregroundStyle(palette.background).frame(width:42,height:38).background(palette.accent,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain).help("Lecture / pause · Espace").accessibilityLabel("Lecture / pause")
                Button {s.stop()} label:{Image(systemName:"stop.fill")}.help("Arrêt / annuler · Échap")
                Button {s.playFromSelection()} label:{Image(systemName:"play.rectangle")}.help("Depuis la cellule sélectionnée · Majuscule Entrée")
                Button {s.play(patternOnly:true)} label:{Image(systemName:"play.square")}.help("Lire le pattern une fois · Entrée")
                Rectangle().fill(palette.text.opacity(0.1)).frame(width:1,height:30)
                metric("TEMPO",value:"\(s.module.bpm)",suffix:"BPM")
                metric("VITESSE",value:"\(s.module.speed)",suffix:"TICKS")
                Spacer()
                if s.rendering {ProgressView().controlSize(.small)}
                Text(s.phase.title).font(.system(size:11)).foregroundStyle(palette.secondary)
                Text(String(format:"%02X : %02X",s.scoreOrder,s.scoreRow)).font(.system(size:22,weight:.light,design:.monospaced)).foregroundStyle(palette.accent)
            }.buttonStyle(.plain)
            TransportTimelineView(clock:s.clock)
        }.padding(.horizontal,22).padding(.vertical,14)
    }
    var patternEditor: some View {
        VStack(spacing:0) {
            HStack {
                caption(String(format:"PATTERN %02X",s.scorePattern))
                if s.isSymphonie {Toggle("Piano",isOn:$s.pianoVisible).toggleStyle(.button).help("Piano-roll de la piste sélectionnée")}
                Toggle("Suivre",isOn:$s.followPlayback).toggleStyle(.button).help("Verrouiller le suivi de lecture ; désactiver pour parcourir la partition")
                if s.isSymphonie, let entry = s.symEntry(at:s.scoreOrder) {Text("Source \(entry.pattern) · \(s.symOccurrences(entry.pattern)) occurrence(s)").font(.caption2).foregroundStyle(.secondary)}
                Spacer()
                if s.module.channelCount > 4 {
                    Picker("Pistes",selection:$s.channelPage) {
                        if s.isSymphonie { Text("Toutes (\(s.module.channelCount))").tag(-1); Text("Piste sélectionnée").tag(-2) }
                        ForEach(0..<((s.module.channelCount+3)/4),id:\.self) { page in
                            Text("\(page*4+1)–\(min(s.module.channelCount,page*4+4))").tag(page)
                        }
                    }.frame(width:150).controlSize(.small)
                }
                if s.isSymphonie && s.channelPage == -2 {
                    Picker("Piste",selection:$s.channel) {ForEach(0..<s.module.channelCount,id:\.self) {c in Text("Piste \(c+1)").tag(c)}}.frame(width:120)
                }
                if s.isOverview {
                    Button { overviewPanels.toggle() } label: {
                        Label(overviewPanels ? "Masquer les panneaux" : "Afficher les panneaux",systemImage:"sidebar.left")
                    }.buttonStyle(.plain).font(.system(size:10)).help("Afficher l’arrangement et les instruments")
                }
                if s.isSymphonie {
                    Toggle("Source",isOn:$s.symScoreSource).toggleStyle(.switch).controlSize(.mini).help("Notes source avant transposition / représentation du lecteur")
                    Toggle("Écriture",isOn:$s.recording).toggleStyle(.switch).controlSize(.mini)
                } else {
                    Toggle("Écriture",isOn:$s.recording).toggleStyle(.switch).controlSize(.mini)
                    Text("⌨ \((MusicalKeyboard(rawValue:keyboardLayout) ?? .qwerty).title)").font(.system(size:10,design:.monospaced)).foregroundStyle(palette.secondary)
                }
            }.padding(.horizontal,20).padding(.vertical,12).background(palette.panel)
            CompositionToolsView()
            if s.pianoVisible && s.isSymphonie {PianoRollView().environmentObject(s)} else {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    VStack(spacing:0) {
                        trackHeaders
                        TrackMetersView(meters:s.meters,channels:Array(s.visibleChannels),muted:s.effectiveMuted,compact:s.isOverview)
                        fieldLegend
                        if s.isSymphonie {
                            SymphonieScoreView(module:s.module,order:s.scoreOrder,row:s.scoreRow,channels:Array(s.visibleChannels),playing:s.playing,playheadRow:s.scoreOrder == s.playbackOrder && (s.playing || s.paused) ? s.playbackRow : nil,compact:s.isOverview,fontSize:metrics.font,selectionOrder:s.order,selectionRow:s.row,selectionChannel:s.channel,sourceDocument:symSource ? s.symArchive : nil,sourceEntry:symSource ? s.symEntry(at:s.scoreOrder) : nil,block:s.blockOrder == s.scoreOrder ? s.block : nil,onSelect:{r,c in s.selectCell(order:s.scoreOrder,row:r,channel:c,extending:NSEvent.modifierFlags.contains(.shift)); gridFocused = true},onEditKey:{press in handleScoreKey(press)})
                                .focused($gridFocused)
                        } else {modPatternGrid}
                    }.frame(width:metrics.width(available:geometry.size.width,channels:s.visibleChannels.count),height:geometry.size.height)
                }
            }
            }
            if s.isSymphonie && symSource {SymMODCellInspector().environmentObject(s)}
            if s.isSymphonie {
                HStack {
                    Text(symSource && s.symEntry(at:s.scoreOrder) != nil ? "SOURCE · INSTRUMENTS DEPUIS 0 · AVANT TRANSPOSITION" : "REPRÉSENTATION LIBOPENMPT · CONSULTATION").font(.system(size:9)).foregroundStyle(palette.secondary)
                        .help("Commandes traduites pour la lecture ; elles ne reproduisent pas les événements bruts Symphonie.")
                    Spacer()
                    Button {s.row = max(0,s.row-16)} label:{Image(systemName:"chevron.up")}.help("16 lignes précédentes")
                    Button {s.row = min(s.rows-1,s.row+16)} label:{Image(systemName:"chevron.down")}.help("16 lignes suivantes")
                }.buttonStyle(.plain).disabled(s.playing || s.paused).padding(.horizontal,18).frame(height:28)
            }
        }.overlay(Rectangle().stroke(palette.text.opacity(0.05),lineWidth:1))
    }
    var trackHeaders: some View {
        HStack(spacing:0) {
            Text("PAS").frame(width:44)
            ForEach(s.visibleChannels,id:\.self) { c in
                HStack(spacing:s.isOverview ? 4 : 8) {
                    Circle().fill(palette.tracks[c % 4]).frame(width:s.isOverview ? 4 : 6,height:s.isOverview ? 4 : 6)
                    Text(s.isSymphonie ? String(format:s.isOverview ? "%02d" : "PISTE %02d",c+1) : ["BASSE","MÉLODIE","RYTHME","TEXTURE"][c % 4])
                    Spacer(minLength:0)
                    Button {
                        s.toggleMute(c)
                    } label: {Image(systemName:s.muted.contains(c) ? "speaker.slash.fill" : "speaker.wave.1")}
                        .disabled(!s.consoleActive).help("Muet temporaire · activer la console de mixage")
                        .foregroundStyle(s.effectiveMuted.contains(c) ? palette.danger : palette.secondary)
                        .buttonStyle(.plain).help("Activer / couper la piste \(c+1)")
                }.padding(.horizontal,s.isOverview ? 5 : 12).frame(maxWidth:.infinity)
            }
        }.font(.system(size:9,weight:.semibold)).tracking(s.isOverview ? 0 : 1).foregroundStyle(palette.secondary).frame(height:s.isOverview ? 30 : 38)
    }
    var modPatternGrid: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing:0) {ForEach(0..<s.scoreRows,id:\.self) {r in
                        HStack(spacing:0) {
                            Text(String(format:"%02X",r)).font(.system(size:metrics.font,weight:r%4 == 0 ? .bold : .regular,design:.monospaced)).foregroundStyle(r == s.scoreRow ? palette.accent : palette.secondary).frame(width:44)
                            ForEach(s.visibleChannels,id:\.self) {c in
                                let note = s.scoreNote(at:r,channel:c)
                                Button {if !s.rendering {s.selectCell(order:s.scoreOrder,row:r,channel:c,extending:NSEvent.modifierFlags.contains(.shift)); gridFocused = true}} label:{
                                    HStack(spacing:7) {
                                        Text(note.label).foregroundStyle(note.period > 0 ? palette.tracks[c % 4] : palette.secondary.opacity(0.7))
                                        Text(note.sample == 0 ? "··" : String(format:"%02X",note.sample)).foregroundStyle(palette.text.opacity(note.sample == 0 ? 0.4 : 0.85))
                                        Text(note.displayEffect ?? (note.effect == 0 && note.parameter == 0 ? "···" : String(format:"%X%02X",note.effect,note.parameter))).foregroundStyle(note.displayEffect == nil && note.effect == 0 && note.parameter == 0 ? palette.secondary.opacity(0.65) : palette.effect)
                                    }.font(.system(size:metrics.font,weight:.medium,design:.monospaced)).frame(maxWidth:.infinity,minHeight:metrics.rowHeight)
                                        .background(!s.playing && !s.rendering && s.order == s.scoreOrder && s.selection.contains(row:r,channel:c) ? palette.accent.opacity(0.18) : .clear)
                                        .overlay {
                                            if !s.playing && !s.rendering && s.order == s.scoreOrder && r == s.row && c == s.channel {
                                                Rectangle().stroke(palette.accent.opacity(0.65),lineWidth:1)
                                            }
                                        }.opacity(s.effectiveMuted.contains(c) ? 0.3 : 1)
                                }.buttonStyle(.plain)
                                .help(NoteExplanation.effect(note))
                                .accessibilityLabel(NoteExplanation.label(note,row:r,channel:c))
                            }
                        }.background(r == (s.followPlayback && s.playing ? s.playbackRow : s.row) ? palette.accent.opacity(s.followPlayback && s.playing ? 0.12 : 0.04) : r%4 == 0 ? palette.text.opacity(0.025) : .clear)
                            .overlay(alignment:.top) {
                                if s.playing && s.scoreOrder == s.playbackOrder && r == s.playbackRow { Rectangle().fill(palette.accent.opacity(0.45)).frame(height:1) }
                            }
                            .overlay(alignment:.bottom) {
                                if s.playing && s.scoreOrder == s.playbackOrder && r == s.playbackRow { Rectangle().fill(palette.accent.opacity(0.45)).frame(height:1) }
                            }.id(r)
                    }}
                }.onChange(of:s.scoreRow) { _,r in proxy.scrollTo(r,anchor:.center) }
            }
            .focusable(!s.isSymphonie).focused($gridFocused).focusEffectDisabled()
            .onKeyPress { press in
                guard !s.isSymphonie && !s.playing && !s.rendering else {return .ignored}
                if press.modifiers.contains(.command) {return .ignored}
                let extending = press.modifiers.contains(.shift)
                switch press.key {
                case .upArrow: s.selectCell(order:s.order,row:max(0,s.row-1),channel:s.channel,extending:extending)
                case .downArrow: s.selectCell(order:s.order,row:min(63,s.row+1),channel:s.channel,extending:extending)
                case .leftArrow: s.selectCell(order:s.order,row:s.row,channel:max(0,s.channel-1),extending:extending)
                case .rightArrow: s.selectCell(order:s.order,row:s.row,channel:min(3,s.channel+1),extending:extending)
                case .delete: s.clearSelection()
                default:
                    guard press.modifiers.isEmpty,
                          let index = (MusicalKeyboard(rawValue:keyboardLayout) ?? .qwerty).note(for:press.characters) else {return .ignored}
                    s.enter(index)
                }
                return .handled
            }
    }
    @ViewBuilder var sampleEditor: some View {
        if s.isSymphonie {
            HStack(spacing:14) {
                Image(systemName:"waveform").font(.system(size:28)).foregroundStyle(palette.accent)
                VStack(alignment:.leading,spacing:7) {
                    caption("BANQUE SYMPHONIE")
                    Text(s.currentSample.name.isEmpty ? "Instrument \(s.sample+1)" : s.currentSample.name).font(.system(size:15,weight:.medium))
                    Text("Instrument source \(s.sample) · données audio conservées").font(.system(size:11)).foregroundStyle(palette.secondary)
                }
                Spacer()
                Button("Écouter") {s.auditionSymInstrument(s.sample)}.disabled(s.playing || s.rendering)
                Button("Ouvrir la banque") {s.symInstrumentPresented = true}
            }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(palette.panel)
        } else { modSampleEditor }
    }
    var modSampleEditor: some View {SampleLabView()}
    @ViewBuilder var inspector: some View {
        if let sym = s.module.symphonie {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    caption("SYMPHONIE PRO")
                    Text(s.module.title).font(.system(size:17,weight:.semibold))
                    Label("Notes source éditables",systemImage:"pencil").font(.system(size:12)).foregroundStyle(palette.accent)
                    Button("Arrangement source…") {s.symArrangementPresented = true}
                    Button("Propriétés des instruments…") {s.symInstrumentPresented = true}
                    Button("Éditer les patterns source…") {s.symEditorPresented = true}
                    selectedCellDetail
                    Divider()
                    Text("\(sym.channels) pistes\n\(s.module.patterns.count) patterns\n\(s.module.orders.count) positions\n\(s.module.samples.count) instruments").font(.system(size:12,design:.monospaced)).lineSpacing(8)
                    if sym.duration > 0 {Text(String(format:"Durée : %d:%02d",Int(sym.duration)/60,Int(sym.duration)%60)).font(.system(size:12))}
                    Divider()
                    caption("LECTURE NATIVE")
                    Text("libopenmpt 0.8.9\nStéréo · 44,1 kHz\nEffets Symphonie et DSP").font(.system(size:11)).foregroundStyle(palette.secondary).lineSpacing(6)
                    Text("Choisis « Toutes », un groupe de quatre ou « Piste sélectionnée ». Source affiche les événements d’origine ; désactive-le pour consulter la traduction de libopenmpt.").font(.system(size:11)).foregroundStyle(palette.secondary).lineSpacing(4)
                    Divider()
                    caption("ENREGISTREMENT")
                    Text("Le projet Atelier conserve le fichier SymMOD original. L’export WAV utilise le même moteur que la lecture. Les notes, instruments de note et volumes simples peuvent être modifiés dans l’éditeur source, puis exportés en SymMOD depuis le menu Fichier. La banque permet d’importer des samples mono et de régler leurs boucles. Le piano-roll et le MIDI éditent les notes source. Les structures audio spécialisées et les DSP restent protégés.").font(.system(size:11)).foregroundStyle(palette.secondary).lineSpacing(4)
                    if !sym.warnings.isEmpty {Divider(); caption("AVERTISSEMENTS DU DÉCODEUR"); Text(sym.warnings.joined(separator:"\n")).font(.system(size:10)).foregroundStyle(palette.effect)}
                    if !sym.message.isEmpty {Divider(); caption("MESSAGE DU MODULE"); Text(sym.message).font(.system(size:10)).foregroundStyle(palette.secondary).textSelection(.enabled)}
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
            }.background(palette.panel.opacity(0.55))
        } else { modInspector }
    }
    var modInspector: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                caption("COMPOSITION")
                TextField("Titre",text:Binding(get:{s.module.title},set:{ value in s.edit {$0.title = String(value.prefix(20))} })).textFieldStyle(.roundedBorder)
                Stepper("Tempo  \(s.module.bpm)",value:Binding(get:{s.module.bpm},set:{v in s.edit {$0.bpm = v}}),in:32...255).font(.system(size:12))
                Stepper("Ticks  \(s.module.speed)",value:Binding(get:{s.module.speed},set:{v in s.edit {$0.speed = v}}),in:1...31).font(.system(size:12))
                Divider()
                selectedCellDetail
                Divider()
                caption("SAISIE DES NOTES")
                Stepper("Octave  \(s.octave)",value:$s.octave,in:1...3).font(.system(size:12))
                Stepper("Avance  \(s.advance)",value:$s.advance,in:0...16).font(.system(size:12))
                Text("Clique une cellule, puis joue au clavier. Le bouton Composer affiche la disposition AZERTY / QWERTY et les touches. Majuscule + flèches ou clic : sélectionner un bloc. ⌫ : effacer.").font(.system(size:11)).foregroundStyle(palette.secondary).lineSpacing(4)
                Divider()
                caption(String(format:"CELLULE %02X · PISTE %d",s.row,s.channel+1))
                HStack {Text(s.note.label).font(.system(size:25,weight:.light,design:.monospaced)).foregroundStyle(palette.tracks[s.channel % 4]); Spacer(); Button {s.setNote(Note())} label:{Image(systemName:"eraser")}.buttonStyle(.plain)}
                Picker("Note",selection:Binding(get:{s.note.period},set:{v in var n = s.note; n.period = v; if n.sample == 0 {n.sample = s.sample+1}; s.setNote(n)})) {Text("Vide").tag(0); ForEach(Note.periods.indices,id:\.self) {i in Text(Note(period:Note.periods[i]).label).tag(Note.periods[i])}}.font(.system(size:11))
                Stepper("Sample  \(s.note.sample)",value:Binding(get:{s.note.sample},set:{v in var n = s.note; n.sample = v; s.setNote(n)}),in:0...31).font(.system(size:12))
                HStack {hexField("FX",value:s.note.effect,max:15) {var n = s.note; n.effect = $0; s.setNote(n)}; hexField("VALEUR",value:s.note.parameter,max:255) {var n = s.note; n.parameter = $0; s.setNote(n)}}
                Divider()
                caption("INSTRUMENT")
                TextField("Nom du sample",text:Binding(get:{s.currentSample.name},set:{v in let i = s.sample; s.edit {$0.samples[i].name = String(v.prefix(22))}})).textFieldStyle(.roundedBorder)
                HStack {Text("Volume"); Spacer(); Text("\(s.currentSample.volume)").monospacedDigit()}.font(.system(size:11)).foregroundStyle(palette.secondary)
                Slider(value:Binding(get:{Double(s.currentSample.volume)},set:{v in let i = s.sample; s.edit {$0.samples[i].volume = Int(v)}}),in:0...64,step:1,onEditingChanged:{editing in if editing {s.beginEditGesture()} else {s.endEditGesture()}})
                    .onDisappear {s.endEditGesture()}
                Toggle("Boucler le sample",isOn:Binding(get:{s.currentSample.loopLength > 2},set:{on in let i = s.sample; s.edit {$0.samples[i].loopStart = 0; $0.samples[i].loopLength = on ? $0.samples[i].data.count : 0}})).font(.system(size:11)).disabled(s.currentSample.data.count < 4)
                Divider()
                caption("MOTEUR AUDIO")
                Text("Natif ARM64 · 44,1 kHz\n4 voix · panoramique stéréo").font(.system(size:10)).foregroundStyle(palette.secondary).lineSpacing(5)
                Text("Effets : 0, 1, 2, 9, A, B, C, D, F. Les autres sont conservés dans le MOD et signalés à la lecture. Rendu limité à 5 minutes.").font(.system(size:10)).foregroundStyle(palette.secondary).lineSpacing(4)
            }.padding(18)
        }.background(palette.panel.opacity(0.55))
    }
    var footer: some View {
        HStack(spacing:8) {Circle().fill(s.playing ? palette.accent : palette.secondary).frame(width:5,height:5); Text(s.status).lineLimit(1); if s.recoveryReady {Image(systemName:s.recoveryStatus.hasPrefix("Échec") || s.recoveryStatus.hasPrefix("Impossible") ? "exclamationmark.triangle" : "clock.arrow.circlepath").help(s.recoveryStatus).accessibilityLabel(s.recoveryStatus)}; Spacer(); Text(s.isSymphonie ? "SYMPHONIE · SOURCE" : s.recording ? "ÉCRITURE" : "ÉCOUTE").foregroundStyle(s.recording ? palette.accent : palette.secondary); Text("·"); Text("⌘S enregistrer   Espace lecture")}.font(.system(size:10)).foregroundStyle(palette.secondary).padding(.horizontal,20).frame(height:30).background(palette.background)
    }
    func caption(_ text: String) -> some View {Text(text).font(.system(size:9,weight:.semibold)).tracking(1.5).foregroundStyle(palette.secondary)}
    func metric(_ label: String,value: String,suffix: String) -> some View {VStack(alignment:.leading,spacing:4) {caption(label); HStack(alignment:.firstTextBaseline,spacing:5) {Text(value).font(.system(size:22,weight:.light,design:.monospaced)); Text(suffix).font(.system(size:8)).foregroundStyle(palette.secondary)}}}
    func hexField(_ title: String,value: Int,max: Int,set: @escaping (Int)->Void) -> some View {
        VStack(alignment:.leading,spacing:5) {caption(title); TextField("",text:Binding(get:{String(format:max == 15 ? "%X" : "%02X",value)},set:{if let n = Int($0,radix:16), n >= 0 && n <= max {set(n)}})).textFieldStyle(.roundedBorder).font(.system(size:13,design:.monospaced))}
    }
}
/// Segmented green/yellow/red peak meter with a held peak marker.
struct TrackMeter: View {
    @Environment(\.colorScheme) private var colorScheme
    private var palette: StudioPalette { StudioPalette(scheme:colorScheme) }
    let level: Double, peak: Double, muted: Bool
    var body: some View {
        Canvas { context,size in
            let count = size.height < 60 ? 16 : 24
            let gap = size.height < 60 ? 1.2 : 1.5
            let h = (size.height-Double(count-1)*gap)/Double(count)
            for i in 0..<count {
                let threshold = Double(i+1)/Double(count)
                let color: Color = i >= count-2 ? palette.danger : i >= count*3/4 ? palette.warning : palette.accent
                let rect = CGRect(x:0,y:size.height-Double(i+1)*h-Double(i)*gap,width:size.width,height:h)
                let lit = !muted && level > 0 && threshold <= level
                context.fill(Path(roundedRect:rect,cornerRadius:0.7),with:.color(color.opacity(lit ? 0.95 : 0.10)))
            }
            if !muted && peak > 0 {
                let y = max(0,size.height*(1-peak)-1)
                context.fill(Path(CGRect(x:0,y:y,width:size.width,height:2)),with:.color(palette.text.opacity(0.9)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Meter updates redraw this small view, without invalidating the score and arrangement.
struct TrackMetersView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var palette: StudioPalette { StudioPalette(scheme:colorScheme) }
    @ObservedObject var meters: TrackMeterState
    let channels: [Int]
    let muted: Set<Int>
    var compact = false
    var body: some View {
        HStack(spacing:0) {
            Color.clear.frame(width:44)
            ForEach(channels,id:\.self) { c in
                column(c).frame(maxWidth:.infinity)
                    .accessibilityElement(children:.ignore)
                    .accessibilityLabel("Vumètre piste \(c+1)")
                    .accessibilityValue(muted.contains(c) ? "Muet" : meters.level(for:c) > 0 ? String(format:"%.0f décibels",meters.level(for:c)*48-48) : "Silence")
            }
        }.frame(height:compact ? 70 : 100).background(palette.panel.opacity(0.6))
    }
    @ViewBuilder func column(_ c: Int) -> some View {
        if compact {
            VStack(spacing:4) {
                TrackMeter(level:meters.level(for:c),peak:meters.peak(for:c),muted:muted.contains(c)).frame(width:18,height:42)
                Text(muted.contains(c) ? "MUET" : meters.level(for:c) > 0 ? String(format:"%.0f dB",meters.level(for:c)*48-48) : "−∞")
                    .font(.system(size:9,design:.monospaced)).foregroundStyle(palette.tracks[c % 4])
            }.padding(.vertical,6)
        } else {
            HStack(spacing:12) {
                TrackMeter(level:meters.level(for:c),peak:meters.peak(for:c),muted:muted.contains(c)).frame(width:25,height:76)
                VStack(alignment:.leading,spacing:7) {
                    Text(muted.contains(c) ? "MUET" : "NIVEAU").font(.system(size:8,weight:.semibold)).tracking(1.5).foregroundStyle(palette.secondary)
                    Text(meters.level(for:c) > 0 ? String(format:"%.0f",meters.level(for:c)*48-48) : "−∞")
                        .font(.system(size:23,weight:.light,design:.monospaced)).foregroundStyle(muted.contains(c) ? palette.secondary : palette.tracks[c % 4])
                    Text("dBFS · CRÊTE").font(.system(size:7,design:.monospaced)).foregroundStyle(palette.secondary)
                }
                Spacer(minLength:0)
            }.padding(.horizontal,14).padding(.vertical,12)
        }
    }
}

/// Read-only Symphonie score: draws only the visible rows without scroll/focus layout churn.
struct SymphonieScoreView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var palette: StudioPalette { StudioPalette(scheme:colorScheme) }
    let module: Module
    let order: Int, row: Int
    let channels: [Int]
    let playing: Bool
    var playheadRow: Int? = nil
    var compact = false
    var fontSize = 12.0
    var selectionOrder = 0, selectionRow = 0, selectionChannel = 0
    var sourceDocument: SymMODDocument?
    var sourceEntry: SymMODOrderSource?
    var block: PatternSelection?
    var onSelect: (Int,Int) -> Void = {_,_ in}
    var onEditKey: ((KeyPress) -> KeyPress.Result)?
    private func displayedNote(_ r: Int,_ c: Int) -> Note {
        guard let d = sourceDocument, let entry = sourceEntry, let cell = try? d.cell(in:entry,row:r,channel:c), let e = try? d.event(pattern:cell.pattern,row:cell.row,channel:cell.channel) else {return module.patterns[module.orders[order]][r*module.channelCount+c]}
        var note = Note(period:e.command == 0 && e.pitch >= 0 ? 1 : 0,sample:e.command == 0 && e.pitch >= 0 ? Int(e.instrument)+1 : 0)
        note.displayNote = e.pitchLabel
        if e.isNoteStop {note.displayNote = "OFF"}
        else if e.command == 0 && e.parameter > 100 {note.displayNote = String(format:"SP%02X",e.parameter)}
        note.displayEffect = e.command == 0 ? (e.parameter == 0 ? "···" : e.parameter <= 100 ? "V\(e.parameter)" : String(format:"%02X %02X",e.parameter,e.instrument)) : String(format:"%02X %02X %02X",e.command,e.parameter,e.instrument)
        return note
    }
    private func cellLabel(_ r: Int,_ c: Int) -> String {
        if let d = sourceDocument, let entry = sourceEntry, let cell = try? d.cell(in:entry,row:r,channel:c), let e = try? d.event(pattern:cell.pattern,row:cell.row,channel:cell.channel) {
            return "Source pattern \(cell.pattern), ligne \(cell.row), piste \(c+1) : \(e.isEditableEvent ? "éditable" : "protégée"), \(e.summary)"
        }
        return NoteExplanation.label(displayedNote(r,c),row:r,channel:c)
    }
    private func sampleText(_ note: Note) -> String {note.sample == 0 ? "··" : String(format:"%02X",note.sample-(sourceEntry == nil ? 0 : 1))}
    var body: some View {
        GeometryReader { geometry in
        Canvas { context,size in
            let pattern = module.patterns[module.orders[order]], stride = module.channelCount
            let count = pattern.count/stride, height = ScoreMetrics(font:fontSize,zoom:1,compact:compact).rowHeight
            let visible = max(1,Int(size.height/height))
            let start = max(0,min(row-visible/2,count-visible))
            let width = (size.width-44)/Double(max(1,channels.count))
            if compact {
                for column in 0...channels.count {
                    context.fill(Path(CGRect(x:44+Double(column)*width,y:0,width:1,height:size.height)),with:.color(palette.text.opacity(0.08)))
                }
            }
            for r in start..<min(count,start+visible) {
                let y = Double(r-start)*height
                let rect = CGRect(x:0,y:y,width:size.width,height:height)
                if r == row || r == playheadRow {
                    context.fill(Path(rect),with:.color(palette.accent.opacity(r == playheadRow ? 0.12 : 0.06)))
                    if r == playheadRow {
                        context.fill(Path(CGRect(x:0,y:y,width:size.width,height:1)),with:.color(palette.accent.opacity(0.45)))
                        context.fill(Path(CGRect(x:0,y:y+height-1,width:size.width,height:1)),with:.color(palette.accent.opacity(0.45)))
                    }
                } else if r%4 == 0 {context.fill(Path(rect),with:.color(palette.text.opacity(0.025)))}
                context.draw(Text(String(format:"%02X",r)).font(.system(size:fontSize,weight:r%4 == 0 ? .bold : .regular,design:.monospaced)).foregroundColor(r == row ? palette.accent : palette.secondary),at:CGPoint(x:22,y:y+height/2))
                for (column,c) in channels.enumerated() {
                    let note = displayedNote(r,c), x = 44+Double(column)*width
                    if let d = sourceDocument,let entry = sourceEntry,let cell = try? d.cell(in:entry,row:r,channel:c),let event = try? d.event(pattern:cell.pattern,row:cell.row,channel:cell.channel),!event.isEditableEvent {
                        context.fill(Path(CGRect(x:x+1,y:y+2,width:3,height:height-4)),with:.color(palette.warning))
                    }
                    if !playing && order == selectionOrder, let block, block.contains(row:r,channel:c) {
                        context.fill(Path(CGRect(x:x,y:y,width:width,height:height)),with:.color(palette.accent.opacity(0.16)))
                    }
                    if !playing && order == selectionOrder && r == selectionRow && c == selectionChannel {
                        context.stroke(Path(CGRect(x:x,y:y,width:width,height:height)),with:.color(palette.accent.opacity(0.65)),lineWidth:1)
                    }
                    let label = Text(note.label).foregroundColor(note.period > 0 ? palette.tracks[c%4] : palette.secondary.opacity(0.7))
                        + Text(note.sample == 0 ? " ·· " : " "+sampleText(note)+" ").foregroundColor(palette.text.opacity(note.sample == 0 ? 0.4 : 0.85))
                        + Text(note.displayEffect ?? "···").foregroundColor(palette.effect.opacity(note.displayEffect?.contains(where:{$0 != "·" && $0 != " "}) == true ? 1 : 0.55))
                    if compact {
                        let pitch = Text(note.label).foregroundColor(note.period > 0 ? palette.tracks[c%4] : palette.secondary.opacity(0.7))
                            + Text(note.sample == 0 ? " ··" : " "+sampleText(note)).foregroundColor(palette.text.opacity(note.sample == 0 ? 0.4 : 0.85))
                        context.draw(pitch.font(.system(size:fontSize,weight:.medium,design:.monospaced)),at:CGPoint(x:x+width/2,y:y+height*0.28))
                        context.draw(Text(note.displayEffect ?? "···").font(.system(size:max(9,fontSize-2),design:.monospaced)).foregroundColor(palette.effect.opacity(note.displayEffect?.contains(where:{$0 != "·" && $0 != " "}) == true ? 1 : 0.55)),at:CGPoint(x:x+width/2,y:y+height*0.73))
                    } else {
                        context.draw(label.font(.system(size:fontSize,weight:.medium,design:.monospaced)),at:CGPoint(x:x+width/2,y:y+height/2))
                    }
                }
            }
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .contentShape(Rectangle())
        .onTapGesture { point in
            let count = module.rowCount(pattern:module.orders[order]), height = ScoreMetrics(font:fontSize,zoom:1,compact:compact).rowHeight
            let visible = max(1,Int(geometry.size.height/height))
            let start = max(0,min(row-visible/2,count-visible))
            let width = max(1,(geometry.size.width-44)/Double(max(1,channels.count)))
            let column = Int((point.x-44)/width), selectedRow = start+Int(point.y/height)
            if point.x >= 44, channels.indices.contains(column), selectedRow < count {onSelect(selectedRow,channels[column])}
        }
        }
        .focusable().focusEffectDisabled()
        .onKeyPress { press in
            if let onEditKey {return onEditKey(press)}
            guard !playing, press.modifiers.isEmpty else {return .ignored}
            switch press.key {
            case .upArrow: onSelect(max(0,selectionRow-1),selectionChannel)
            case .downArrow: onSelect(min(module.rowCount(pattern:module.orders[order])-1,selectionRow+1),selectionChannel)
            case .leftArrow: onSelect(selectionRow,max(0,selectionChannel-1))
            case .rightArrow: onSelect(selectionRow,min(module.channelCount-1,selectionChannel+1))
            default: return .ignored
            }
            return .handled
        }
        .accessibilityRepresentation {
            VStack {
                Text("Partition Symphonie, position \(order), ligne \(row). Utilisez l’inspecteur pour choisir une position et une ligne.")
                ForEach(channels,id:\.self) { c in
                    let safeRow = min(max(0,selectionRow),module.rowCount(pattern:module.orders[order])-1)
                    Button {onSelect(safeRow,c)} label:{Text(cellLabel(safeRow,c))}
                }
            }
        }
    }
}

extension StudioView {
    func handleScoreKey(_ press: KeyPress) -> KeyPress.Result {
        guard (!s.playing || !s.followPlayback), !s.rendering else {return .ignored}
        if press.modifiers.contains(.command) {return .ignored}
        let extending = press.modifiers.contains(.shift)
        switch press.key {
        case .upArrow:s.selectCell(order:s.order,row:max(0,s.row-1),channel:s.channel,extending:extending)
        case .downArrow:s.selectCell(order:s.order,row:min(s.rows-1,s.row+1),channel:s.channel,extending:extending)
        case .leftArrow:s.selectCell(order:s.order,row:s.row,channel:max(0,s.channel-1),extending:extending)
        case .rightArrow:s.selectCell(order:s.order,row:s.row,channel:min(s.module.channelCount-1,s.channel+1),extending:extending)
        case .delete:if symSource && !s.playing {s.clearSelection()} else {return .ignored}
        default:
            guard !s.playing, symSource, press.modifiers.isEmpty, let index = (MusicalKeyboard(rawValue:keyboardLayout) ?? .qwerty).note(for:press.characters) else {return .ignored}
            s.enter(index)
        }
        return .handled
    }
    var displaySettings: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Affichage de la partition").font(.headline)
            HStack {Text("Largeur des pistes"); Spacer(); Text("\(Int(scoreZoom*100)) %").monospacedDigit()}
            Slider(value:$scoreZoom,in:1...2.5,step:0.1).accessibilityLabel("Zoom horizontal des pistes")
            HStack {Text("Taille des notes"); Spacer(); Text("\(Int(scoreFont)) pt").monospacedDigit()}
            Slider(value:$scoreFont,in:10...20,step:1).accessibilityLabel("Taille de la police de la partition")
            Text("La vue d’ensemble utilise une police de 2 points plus petite. À fort zoom, faites défiler les pistes horizontalement.").font(.caption).foregroundStyle(palette.secondary)
            Divider()
            Toggle("Arrangement et instruments",isOn:$arrangementVisible)
            Toggle("Inspecteur",isOn:$inspectorVisible)
            if s.isOverview {Toggle("Afficher les panneaux en vue générale",isOn:$overviewPanels)}
            Text("Glissez les séparateurs pour régler la largeur des panneaux. Ces préférences sont conservées entre les lancements.").font(.caption).foregroundStyle(palette.secondary)
            Button("Réinitialiser l’affichage") {
                scoreZoom = 1; scoreFont = 13; leftWidth = 218; rightWidth = 222
                arrangementVisible = true; inspectorVisible = true; overviewPanels = false
            }
        }.padding(20).frame(width:320)
    }
    var fieldLegend: some View {
        HStack(spacing:0) {
            Text("HEX").frame(width:44).help("Numéros de ligne en hexadécimal")
            ForEach(s.visibleChannels,id:\.self) {_ in
                Text(s.isOverview ? "NOTE · INS\nVOL · FX" : s.isSymphonie ? "NOTE  ·  INS  ·  VOL  ·  FX" : "NOTE  ·  INS  ·  FX")
                    .frame(maxWidth:.infinity).multilineTextAlignment(.center)
                    .help(s.isSymphonie ? (symSource ? "Source : instrument depuis 0, volume ou commande et paramètres bruts hexadécimaux. Une seule commande par cellule." : "Note, instrument, volume et effet traduits par libopenmpt.") : "Note, numéro d’instrument, effet et paramètre hexadécimal. Le volume est réglé par Cxx ou par le sample.")
            }
        }.font(.system(size:8,weight:.semibold,design:.monospaced)).foregroundStyle(palette.secondary)
            .frame(height:s.isOverview ? 30 : 22).background(palette.panel.opacity(0.6))
    }
    var selectedCellDetail: some View {
        VStack(alignment:.leading,spacing:7) {
            HStack {
                Text("CELLULE SÉLECTIONNÉE").font(.system(size:9,weight:.semibold)).foregroundStyle(palette.secondary)
                Spacer()
                Text(String(format:"%02X : %02X · piste %d",s.order,s.row,s.channel+1)).font(.system(size:10,design:.monospaced))
            }
            if s.isSymphonie {
                Stepper("Position \(s.order+1)",value:Binding(get:{s.order},set:{s.selectCell(order:$0,row:0,channel:s.channel)}),in:0...max(0,s.module.orders.count-1))
                Stepper("Ligne \(String(format:"%02X",s.row))",value:Binding(get:{s.row},set:{s.selectCell(order:s.order,row:$0,channel:s.channel)}),in:0...max(0,s.rows-1))
                Picker("Piste",selection:$s.channel) {ForEach(0..<s.module.channelCount,id:\.self) {Text("\($0+1)").tag($0)}}
            }
            if s.isSymphonie && s.symScoreSource, let e = s.selectedSymEvent {
                Text(e.summary).font(.system(size:11,design:.monospaced)).foregroundStyle(palette.tracks[s.channel%4])
                Text(e.effect?.explanation ?? "Commande protégée conservée sans modification.").font(.system(size:11)).foregroundStyle(palette.secondary).fixedSize(horizontal:false,vertical:true)
            } else {
            Text("Note : \(s.note.label)   ·   Instrument : \(s.note.sample)").font(.system(size:11,design:.monospaced))
                .foregroundStyle(palette.tracks[s.channel%4])
            if s.isSymphonie {
                let fields = NoteExplanation.fields(s.note)
                Text("Volume : \(fields.volume)   ·   Effet : \(fields.effect)").font(.system(size:11,design:.monospaced)).foregroundStyle(palette.effect)
            }
            Text(NoteExplanation.effect(s.note)).font(.system(size:11)).foregroundStyle(palette.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(.vertical,8)
    }
}
