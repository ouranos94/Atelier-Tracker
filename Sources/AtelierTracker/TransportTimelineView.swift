import SwiftUI

struct TransportTimelineView: View {
    @EnvironmentObject private var s: Studio
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var clock: TransportClock
    private var palette: StudioPalette { StudioPalette(scheme:scheme) }
    var body: some View {
        VStack(spacing:6) {
            HStack(spacing:12) {
                Text(TransportClock.label(clock.elapsed)).foregroundStyle(palette.accent)
                Slider(value:Binding(get:{min(clock.elapsed,max(0.001,clock.duration))},set:{s.seek(to:$0)}),in:0...max(0.001,clock.duration),onEditingChanged:{editing in if editing {s.beginScrub()} else {s.endScrub()}})
                    .tint(palette.accent).disabled(clock.duration <= 0 || s.phase == .exporting)
                    .accessibilityLabel("Position de lecture").help("Déplacer pour écouter un autre passage")
                Text(TransportClock.label(clock.duration)).foregroundStyle(palette.secondary)
            }.font(.system(size:12,design:.monospaced))
            HStack(spacing:12) {
                Picker("Boucle",selection:Binding(get:{s.loopMode},set:{s.setLoop($0)})) {
                    ForEach(LoopMode.allCases) {Text($0.title).tag($0)}
                }.frame(width:220).controlSize(.small)
                Button {s.markA()} label:{Text("A · "+(s.selectionA.map(TransportClock.label) ?? "—"))}.help("Placer A · Option I")
                Button {s.markB()} label:{Text("B · "+(s.selectionB.map(TransportClock.label) ?? "—"))}.help("Placer B · Option O")
                Spacer()
                Text(String(format:"Sélection %02X : %02X · piste %d",s.order,s.row,s.channel+1)).foregroundStyle(palette.secondary)
            }.font(.system(size:10,design:.monospaced)).buttonStyle(.plain)
        }
    }
}
