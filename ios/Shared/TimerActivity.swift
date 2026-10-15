import ActivityKit
import SwiftUI

/// Shared by the app (which starts and updates the activity) and the widget
/// extension (which draws it on the Lock Screen, in StandBy and the Dynamic Island).
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Set while running; the system counts down to it without updates.
        var deadline: Date?
        var remaining: TimeInterval
        var total: TimeInterval
        var isBreak: Bool
        /// Optional so an activity started by an older build still decodes.
        var skinID: String? = nil
        var slats: Int? = nil
    }
    var skinID: String
    var slats: Int
}

/// The few colours the extension needs, keyed by skin id.
enum LCDPalette {
    /// The Island always has a black background, including for light LCD skins.
    static func islandInk(for skinID: String) -> Color {
        switch skinID {
        case "classic", "paper", "mint": return colors(for: skinID).lcd
        case "amber", "night", "ruby": return colors(for: skinID).ink
        default: return colors(for: "classic").lcd
        }
    }

    static func colors(for skinID: String) -> (lcd: Color, ink: Color) {
        switch skinID {
        case "paper": return (rgb(0xECEBE6), rgb(0x222220))
        case "mint": return (rgb(0xD3EBDD), rgb(0x123A2C))
        case "amber": return (rgb(0x130D06), rgb(0xFFB33C))
        case "night": return (rgb(0x07111F), rgb(0x7CC4FF))
        case "ruby": return (rgb(0x0E0405), rgb(0xFF4B3E))
        default: return (rgb(0xB8C1AA), rgb(0x1C231D))
        }
    }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

enum ThirtyLink {
    static let scheme = "thirty"
    /// thirty://start?minutes=30 starts a fresh session from widgets and quick actions.
    static func start(minutes: Int = 30) -> URL {
        URL(string: "\(scheme)://start?minutes=\(minutes)")!
    }
}
