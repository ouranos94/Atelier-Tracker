import SwiftUI
import TrackerCore

struct SymMODInstrumentPreview: View {
    @EnvironmentObject var s: Studio
    @Environment(\.colorScheme) private var scheme
    let index: Int
    let instrument: SymMODInstrument
    @AppStorage("sym.audition.pitch") private var pitch = 12
    private var palette: StudioPalette {StudioPalette(scheme:scheme)}
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("PRÉÉCOUTE ISOLÉE").font(.caption.bold())
                Spacer()
                Picker("Note",selection:$pitch) {ForEach(0...84,id:\.self) {Text(SymMODEvent(pitch:Int8($0)).pitchLabel).tag($0)}}.frame(width:110)
                Button("Écouter") {s.auditionSymInstrument(index,pitch:pitch)}.disabled(s.playing || s.rendering || instrument.name.isEmpty)
                Button("Arrêter") {s.cancelSymAudition()}
            }
            Canvas {context,size in
                let peaks = s.symAuditionIndex == index ? s.symAudition?.peaks ?? [] : []
                for (i,peak) in peaks.enumerated() {
                    let x = Double(i)*size.width/Double(max(1,peaks.count)), h = Double(peak)*size.height
                    context.fill(Path(CGRect(x:x,y:(size.height-h)/2,width:max(1,size.width/Double(max(1,peaks.count))-1),height:max(1,h))),with:.color(palette.accent))
                }
                context.fill(Path(CGRect(x:0,y:size.height/2,width:size.width,height:1)),with:.color(palette.secondary.opacity(0.4)))
            }.frame(height:64).background(palette.background,in:RoundedRectangle(cornerRadius:6))
            .accessibilityLabel("Enveloppe de la préécoute rendue")
            Text("Enveloppe rendue à la note choisie (2 s maximum), avec les propriétés du lecteur. Ce n’est pas la forme PCM brute ; les canaux stéréo sont préécoutés séparément.").font(.caption2).foregroundStyle(.secondary)
            GeometryReader {g in
                let a = min(1,max(0,Double(instrument.loop.start)/(100*65536)))
                let b = min(1,max(a,Double(instrument.loop.start+instrument.loop.length)/(100*65536)))
                Capsule().fill(palette.secondary.opacity(0.2))
                Capsule().fill(palette.accent.opacity(instrument.loop.enabled ? 0.8 : 0.25)).frame(width:max(2,(b-a)*g.size.width)).offset(x:a*g.size.width)
            }.frame(height:8).accessibilityLabel("Limites de boucle en pourcentage du sample source")
            Text(String(format:"Boucle source %@ · %.4f %% → %.4f %%",instrument.loop.enabled ? "active" : "inactive",Double(instrument.loop.start)/65536,Double(instrument.loop.start+instrument.loop.length)/65536)).font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(palette.panel,in:RoundedRectangle(cornerRadius:8))
    }
}

struct SymEditorSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let palette = StudioPalette(scheme:scheme)
        content.background(palette.background).tint(palette.accent)
    }
}
extension View {func symEditorSurface() -> some View {modifier(SymEditorSurface())}}
