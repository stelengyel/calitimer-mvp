import SwiftUI

extension Color {
    // Hex convenience — SwiftUI has no built-in hex init
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let brandBackground  = Color(hex: 0x0C0906)   // midnight
    static let brandEmber       = Color(hex: 0xFF6B2B)   // primary action
    static let brandAmber       = Color(hex: 0xFFAA3B)   // gradient mid
    static let brandGold        = Color(hex: 0xFFD166)   // gradient end
    static let textPrimary      = Color(hex: 0xFAF3EC)
    static let textSecondary    = Color(hex: 0xB8A090)
}
