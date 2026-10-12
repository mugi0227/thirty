import SwiftUI
import UIKit

/// A colour scheme for the whole-screen LCD. Classic follows the system
/// appearance; the others are fixed panels and are part of Thirty+.
struct Skin: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let lcd: Color
    let ink: Color
    /// nil follows the system; fixed skins pin the status bar and sheets.
    let colorScheme: ColorScheme?
    var isFree: Bool { id == Skin.classic.id }

    var ghost: Color { ink.opacity(0.075) }
    var line: Color { ink.opacity(0.16) }
    var soft: Color { ink.opacity(0.08) }

    static func == (lhs: Skin, rhs: Skin) -> Bool { lhs.id == rhs.id }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    static let classic = Skin(id: "classic", name: "クラシック", detail: "反射型の液晶。暗い配色ではバックライト",
                              lcd: TimerTheme.lcd, ink: TimerTheme.ink, colorScheme: nil)
    static let all: [Skin] = [
        classic,
        Skin(id: "paper", name: "ペーパー", detail: "電子ペーパーのような白", lcd: rgb(0xECEBE6), ink: rgb(0x222220), colorScheme: .light),
        Skin(id: "mint", name: "ミント", detail: "やわらかい緑の液晶", lcd: rgb(0xD3EBDD), ink: rgb(0x123A2C), colorScheme: .light),
        Skin(id: "amber", name: "アンバー", detail: "琥珀色のバックライト", lcd: rgb(0x130D06), ink: rgb(0xFFB33C), colorScheme: .dark),
        Skin(id: "night", name: "ナイトブルー", detail: "青く光る夜の時計", lcd: rgb(0x07111F), ink: rgb(0x7CC4FF), colorScheme: .dark),
        Skin(id: "ruby", name: "ルビー", detail: "赤いLEDの表示", lcd: rgb(0x0E0405), ink: rgb(0xFF4B3E), colorScheme: .dark),
    ]

    /// A paid skin chosen before a refund or on another device falls back to Classic.
    static func resolve(_ id: String, hasPlus: Bool) -> Skin {
        guard let skin = all.first(where: { $0.id == id }), skin.isFree || hasPlus else { return classic }
        return skin
    }
}

private struct SkinKey: EnvironmentKey {
    static let defaultValue = Skin.classic
}

extension EnvironmentValues {
    var skin: Skin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
    }
}
