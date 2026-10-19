import SwiftUI
import TrackerCore

/// Shared measurements keep headers, meters and notes on the same horizontal grid.
struct ScoreMetrics {
    let font: Double, zoom: Double, compact: Bool
    init(font: Double,zoom: Double,compact: Bool) {
        self.font = min(20,max(10,font.isFinite ? font : 13))
        self.zoom = min(2.5,max(1,zoom.isFinite ? zoom : 1))
        self.compact = compact
    }
    var rowHeight: Double {compact ? font*2+14 : font+16}
    var trackWidth: Double {(compact ? max(62,font*5.2+10) : max(170,font*12+24))*zoom}
    func width(available: Double,channels: Int) -> Double {max(available,44+Double(max(1,channels))*trackWidth)}
    static func panelWidth(saved: Double,available: Double) -> Double {min(max(180,saved.isFinite ? saved : 220),max(180,min(360,(available-680)/2)))}
}

struct PanelResizeHandle: View {
    @Binding var width: Double
    var reversed = false
    var label: String
    @State private var initial: Double?
    var body: some View {
        Rectangle().fill(.secondary.opacity(0.15)).frame(width:6)
            .overlay {Capsule().fill(.secondary.opacity(0.5)).frame(width:2,height:28)}
            .contentShape(Rectangle()).help("Glisser pour redimensionner · "+label)
            .gesture(DragGesture(minimumDistance:0).onChanged {value in
                if initial == nil {initial = width}
                width = min(360,max(180,(initial ?? width)+value.translation.width*(reversed ? -1 : 1)))
            }.onEnded {_ in initial = nil})
            .accessibilityElement().accessibilityLabel(label)
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction {direction in
                width = min(360,max(180,width+(direction == .increment ? 20 : -20)))
            }
    }
}

enum NoteExplanation {
    static func fields(_ note: Note) -> (volume: String,effect: String) {
        let parts = (note.displayEffect ?? "").split(separator:" ").map(String.init)
        return (parts.first ?? "···",parts.count > 1 ? parts[1] : "···")
    }
    static func effect(_ n: Note) -> String {
        if n.displayEffect != nil {return "Volume et effet traduits par libopenmpt : \(n.displayEffect!). Ces commandes représentent la lecture interne ; les événements Symphonie originaux restent conservés dans le fichier source."}
        let x = n.parameter>>4, y = n.parameter&15
        switch n.effect {
        case 0: return n.parameter == 0 ? "Aucun effet." : "Arpège : accord à +\(x) et +\(y) demi-tons."
        case 1: return "Montée de hauteur : période réduite de \(n.parameter) par tick après le premier."
        case 2: return "Descente de hauteur : période augmentée de \(n.parameter) par tick après le premier."
        case 9: return "Départ du sample à l’octet \(n.parameter*256), sur un déclenchement de note."
        case 10: return "Glissement de volume : +\(x), −\(y) par tick après le premier."
        case 11: return "Saut à la position \(n.parameter) de l’arrangement."
        case 12: return "Volume de la voix : \(min(64,n.parameter)) / 64."
        case 13: return "Passage au pattern suivant, ligne \(min(63,x*10+y)) (chiffres décimaux)."
        case 15: return n.parameter == 0 ? "F00 : aucune modification dans ce moteur." : n.parameter < 32 ? "Vitesse : \(n.parameter) ticks par ligne." : "Tempo : \(n.parameter) BPM."
        default: return "Effet conservé à l’enregistrement MOD, mais ignoré par le moteur actuel."
        }
    }
    static func label(_ n: Note,row: Int,channel: Int) -> String {
        "Ligne \(String(format:"%02X",row)), piste \(channel+1), note \(n.label), instrument \(n.sample). "+effect(n)
    }
}
