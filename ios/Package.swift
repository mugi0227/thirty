// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThirtyCore",
    products: [.library(name: "ThirtyCore", targets: ["ThirtyCore"])],
    targets: [
        .target(name: "ThirtyCore", path: "Thirty", exclude: ["TimerModel.swift", "TimerView.swift", "TimerEffects.swift", "GuideView.swift", "ThirtyApp.swift", "Orientation.swift", "Assets.xcassets", "alarm.wav", "Info.plist"], sources: ["Countdown.swift"]),
        .testTarget(name: "ThirtyCoreTests", dependencies: ["ThirtyCore"], path: "Tests")
    ]
)
