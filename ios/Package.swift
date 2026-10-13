// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThirtyCore",
    products: [.library(name: "ThirtyCore", targets: ["ThirtyCore"])],
    targets: [
        .target(name: "ThirtyCore", path: "Thirty", exclude: ["TimerModel.swift", "TimerView.swift", "TimerEffects.swift", "GuideView.swift", "ThirtyApp.swift", "Orientation.swift", "Skin.swift", "Store.swift", "SkinPicker.swift", "LiveActivityController.swift", "SettingsView.swift", "beep.wav", "bell.wav", "soft.wav", "Assets.xcassets", "alarm.wav", "Info.plist", "PrivacyInfo.xcprivacy"], sources: ["Countdown.swift", "ProductRequest.swift"]),
        .testTarget(name: "ThirtyCoreTests", dependencies: ["ThirtyCore"], path: "Tests")
    ]
)
