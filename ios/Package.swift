// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThirtyCore",
    defaultLocalization: "ja",
    platforms: [.macOS(.v12), .iOS(.v17)],
    products: [.library(name: "ThirtyCore", targets: ["ThirtyCore"])],
    targets: [
        .target(name: "ThirtyCore", path: "Thirty", exclude: ["TimerModel.swift", "TimerView.swift", "TimerEffects.swift", "GuideView.swift", "ThirtyApp.swift", "Orientation.swift", "Skin.swift", "Store.swift", "SkinPicker.swift", "LiveActivityController.swift", "SettingsView.swift", "beep.wav", "bell.wav", "soft.wav", "Assets.xcassets", "alarm.wav", "Info.plist", "PrivacyInfo.xcprivacy", "ja.lproj", "en.lproj"], sources: ["Countdown.swift", "ProductRequest.swift", "PlusProducts.swift"]),
        .testTarget(name: "ThirtyCoreTests", dependencies: ["ThirtyCore"], path: "Tests")
    ]
)
