import AppKit
import Foundation

// Check the actual rendered extension, including skin updates during one timer.
// The ROI is the Island area above the first row of home-screen icons.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let colors: [(String, UInt32)] = [
    ("classic", 0xB8C1AA), ("paper", 0xECEBE6), ("mint", 0xD3EBDD),
    ("amber", 0xFFB33C), ("night", 0x7CC4FF), ("ruby", 0xFF4B3E)
]
for (skin, hex) in colors {
    let path = directory.appendingPathComponent("island-skin-\(skin).png")
    let bitmap = NSBitmapImageRep(data: try Data(contentsOf: path))!
    let target = [Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)]
    var matches = 0
    for y in Int(Double(bitmap.pixelsHigh) * 0.015)..<Int(Double(bitmap.pixelsHigh) * 0.085) {
        for x in Int(Double(bitmap.pixelsWide) * 0.22)..<Int(Double(bitmap.pixelsWide) * 0.82) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            let actual = [color.redComponent, color.greenComponent, color.blueComponent].map { Double($0) * 255 }
            if zip(actual, target).allSatisfy({ pair in abs(pair.0 - pair.1) < 20 }) { matches += 1 }
        }
    }
    precondition(matches >= 30, "Island missing \(skin) foreground: \(matches) matching pixels")
    print("Verified \(skin) Island foreground: \(matches) rendered pixels")
}
