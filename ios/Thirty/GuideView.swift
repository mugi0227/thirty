import SwiftUI
import UIKit
import LocalAuthentication

struct OnboardingGuide: View {
    @ObservedObject var model: TimerModel
    let hardwareButton: HardwareButton
    let onDone: () -> Void
    @State private var step = 0
    private var biometry: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        default: return "Face ID／Touch ID"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index == step ? TimerTheme.ink : TimerTheme.ink.opacity(0.12))
                                .frame(width: index == step ? 24 : 8, height: 8)
                        }
                    }.padding(.top, 24).accessibilityLabel("\(step + 1) / 3")
                    Image(systemName: step == 0 ? "lock" : step == 1 ? (biometry == "Touch ID" ? "touchid" : "faceid") : "hand.tap")
                        .font(.system(size: 40)).padding(.top, 12).accessibilityHidden(true)
                    Text(step == 0 ? "アクセスガイドをオン" : step == 1 ? "解除をかんたんに" : "ボタンを3回")
                        .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    if step == 0 {
                        VStack(spacing: 12) {
                            pathRow("設定", symbol: "gearshape")
                            Image(systemName: "chevron.down").foregroundStyle(.secondary)
                            pathRow("アクセシビリティ", symbol: "accessibility")
                            Image(systemName: "chevron.down").foregroundStyle(.secondary)
                            settingRow("アクセスガイド")
                        }
                    } else if step == 1 {
                        VStack(spacing: 16) {
                            pathRow("パスコード設定", symbol: "key")
                            Image(systemName: "chevron.down").foregroundStyle(.secondary)
                            settingRow(biometry)
                        }
                        Text("任意。\(biometry)でアクセスガイドを解除できます。")
                            .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else {
                        DeviceDiagram(kind: hardwareButton).frame(height: 188)
                        Text("\(hardwareButton.title)を3回連続で押し、アクセスガイドを開始します。")
                            .font(.body).multilineTextAlignment(.center)
                        Text("ホームボタンのある機種はホームボタンを使います。")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text("解除：\(hardwareButton.title)を\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion <= 18 ? 2 : 3)回 → 認証 → 終了")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text("タイマーの終了後も、アクセスガイドは手動で解除します。")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    Button {
                        if step < 2 { step += 1 } else { onDone() }
                    } label: {
                        Text(step < 2 ? "次へ" : "タイマーへ").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(TimerTheme.buttonText).background(TimerTheme.button, in: Capsule())
                    }
                    Button(step == 0 ? "あとで" : step == 1 ? "省略" : "最初から見る") {
                        if step == 0 { onDone() } else if step == 1 { step = 2 } else { step = 0 }
                    }.frame(minHeight: 44).foregroundStyle(.secondary)
                    if step == 0 {
                        Link("Appleの設定手順", destination: URL(string: "https://support.apple.com/ja-jp/111795")!)
                            .font(.footnote).frame(minHeight: 44)
                    }
                    if step == 2 {
                        Toggle("計測中は画面を消さない", isOn: $model.keepScreenOn)
                            .padding(16).background(TimerTheme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                        if model.notificationNotice != nil {
                            Button("終了通知の設定") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                            }.frame(minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 24).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(TimerTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step > 0 {
                        Button { step -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel("前へ")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDone) { Image(systemName: "xmark") }.accessibilityLabel("案内を閉じる")
                }
            }
        }
    }
    private func pathRow(_ name: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol).frame(width: 28)
            Text(name).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding(20).background(TimerTheme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }
    private func settingRow(_ name: String) -> some View {
        HStack {
            Text(name).font(.headline)
            Spacer()
            Capsule().fill(Color.green).frame(width: 50, height: 30)
                .overlay(Circle().fill(.white).frame(width: 26, height: 26).offset(x: 9))
                .accessibilityHidden(true)
        }.padding(20).background(TimerTheme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityLabel("設定で\(name)をオンにする")
    }
}

struct DeviceDiagram: View {
    let kind: HardwareButton
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).stroke(TimerTheme.ink.opacity(0.2), lineWidth: 2)
                .frame(width: kind == .top ? 160 : 112, height: 180)
            if kind == .home {
                Circle().stroke(TimerTheme.ink, lineWidth: 2).frame(width: 18, height: 18).offset(y: 72)
            } else if kind == .side {
                Capsule().fill(TimerTheme.ink).frame(width: 6, height: 36).offset(x: 58, y: -40)
            } else {
                Capsule().fill(TimerTheme.ink).frame(width: 32, height: 6).offset(x: 50, y: -92)
            }
            Text("×3").font(.largeTitle.monospacedDigit().weight(.medium))
        }.accessibilityHidden(true)
    }
}
