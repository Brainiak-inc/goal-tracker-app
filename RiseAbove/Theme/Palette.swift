import SwiftUI

enum Palette {
    static let background = Color(hex: 0x05070B)
    static let surface = Color(hex: 0x0B1018)
    static let text = Color(hex: 0xE3EBF6)
    static let muted = Color(hex: 0x8391A7)
    static let fitness = Color(hex: 0x2EE9FF)
    static let fatigue = Color(hex: 0xFFB020)
    static let form = Color(hex: 0x38BDF8)
    static let success = Color(hex: 0x34D399)
    static let warning = Color(hex: 0xFBBF24)

    static func level(_ percent: Int) -> Color {
        if percent >= 75 { return fitness }
        if percent >= 40 { return form }
        return fatigue
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
