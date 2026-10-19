import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self { case .light: return "Clair"; case .dark: return "Sombre"; case .system: return "Système" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .light: return .light; case .dark: return .dark; case .system: return nil }
    }
    var symbol: String {
        switch self { case .light: return "sun.max"; case .dark: return "moon"; case .system: return "circle.lefthalf.filled" }
    }
}

/// One palette for native controls, pattern canvases, waveforms and meters.
struct StudioPalette {
    let scheme: ColorScheme
    private var isLight: Bool { scheme == .light }
    var background: Color { isLight ? Color(red:0.97,green:0.98,blue:0.985) : Color(red:0.055,green:0.065,blue:0.085) }
    var panel: Color { isLight ? Color(red:0.92,green:0.94,blue:0.95) : Color(red:0.085,green:0.10,blue:0.13) }
    var text: Color { isLight ? Color(red:0.10,green:0.14,blue:0.18) : .white }
    var secondary: Color { isLight ? Color(red:0.34,green:0.39,blue:0.43) : Color(red:0.51,green:0.56,blue:0.64) }
    var accent: Color { isLight ? Color(red:0.0,green:0.43,blue:0.32) : Color(red:0.42,green:0.94,blue:0.76) }
    var effect: Color { isLight ? Color(red:0.65,green:0.30,blue:0.02) : .orange }
    var warning: Color { isLight ? Color(red:0.65,green:0.48,blue:0.0) : .yellow }
    var danger: Color { isLight ? Color(red:0.78,green:0.12,blue:0.16) : .red }
    var tracks: [Color] {
        isLight
            ? [accent,Color(red:0.39,green:0.25,blue:0.72),effect,Color(red:0.05,green:0.35,blue:0.66)]
            : [accent,Color(red:0.65,green:0.61,blue:1),Color(red:1,green:0.72,blue:0.43),Color(red:0.45,green:0.75,blue:1)]
    }
}
