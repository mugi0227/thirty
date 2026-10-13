import Foundation

// Validate the resources that will ship, rather than the source catalog alone.
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let bundle = Bundle(url: url)!
    precondition(Set(bundle.localizations).isSuperset(of: ["ja", "en"]), "Missing bundled language: \(path)")
    let ja = Bundle(path: bundle.path(forResource: "ja", ofType: "lproj")!)!
    let en = Bundle(path: bundle.path(forResource: "en", ofType: "lproj")!)!
    precondition(ja.localizedString(forKey: "開始", value: nil, table: "Localizable") == "開始")
    precondition(en.localizedString(forKey: "開始", value: nil, table: "Localizable") == "Start")
    let remaining = en.localizedString(forKey: "残り%lld分%lld秒", value: nil, table: "Localizable")
    precondition(String(format: remaining, Int64(2), Int64(5)) == "2 min 5 sec remaining")
    let buy = en.localizedString(forKey: "%@で購入", value: nil, table: "Localizable")
    precondition(String(format: buy, "$2.99") == "Buy for $2.99")
    precondition(en.localizedString(forKey: "時間になりました。", value: nil, table: "Localizable") == "Time's up.")
    if bundle.bundleURL.pathExtension == "app" {
        precondition(en.localizedString(forKey: "30分スタート", value: nil, table: "InfoPlist") == "Start 30 min")
        precondition(ja.localizedString(forKey: "30分スタート", value: nil, table: "InfoPlist") == "30分スタート")
    }
    print("Verified ja/en resources and interpolation in \(url.lastPathComponent)")
}
