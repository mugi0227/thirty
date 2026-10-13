import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var store: Store
    @Binding var skinID: String
    let onShowGuide: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showPlus = false
    @State private var showSkins = false
    @State private var iconName = UIApplication.shared.alternateIconName

    private var plus: Bool { store.hasPlus }
    private var skin: Skin { Skin.resolve(skinID, hasPlus: plus) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("開いたらすぐスタート", isOn: $model.startOnLaunch)
                } header: {
                    Text("始めかた")
                } footer: {
                    Text("ショートカットApp、アクションボタン、コントロールセンター、ホーム画面のアイコンの長押し、ウィジェットからも、ワンタップで始められます。")
                }

                Section("計測中") {
                    Toggle("画面を暗くする", isOn: $model.dimScreen)
                    Toggle("画面を消さない", isOn: $model.keepScreenOn)
                    Toggle("伏せたら画面を消す", isOn: $model.faceDownScreenOff)
                }

                Section {
                    if !plus {
                        Button { showPlus = true } label: {
                            HStack {
                                Label("Thirty+ でできること", systemImage: "sparkles")
                                Spacer()
                                Text(store.product?.displayPrice ?? "").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Button { showSkins = true } label: {
                        HStack {
                            Text("スキン").foregroundStyle(Color.primary)
                            Spacer()
                            Text(skin.name).foregroundStyle(.secondary)
                            SkinSample(skin: skin, lit: 3, slats: 4, compact: true).frame(width: 34, height: 40)
                        }
                    }
                    plusPicker("終了音", selection: $model.endSound) {
                        ForEach(EndSound.allCases) { sound in
                            Text(sound.title + (sound.isFree || plus ? "" : " 🔒")).tag(sound)
                        }
                    } isAllowed: { $0.isFree }
                    plusToggle("休憩をはさんでくり返す", isOn: $model.cycleEnabled)
                    if plus && model.cycleEnabled {
                        Stepper("休憩 \(model.breakMinutes)分", value: $model.breakMinutes, in: 1...30)
                    }
                    plusToggle("閉じても残り時間を表示", isOn: $model.liveActivityEnabled)
                    plusPicker("棒の本数", selection: $model.slatCount) {
                        Text("30本").tag(30)
                        Text("60本" + (plus ? "" : " 🔒")).tag(60)
                    } isAllowed: { $0 == 30 }
                    plusToggle("秒を表示", isOn: $model.showSeconds, lockedValue: true)
                    iconRow
                } header: {
                    HStack {
                        Text("Thirty+")
                        if !plus { Image(systemName: "lock.fill").font(.caption2) }
                    }
                } footer: {
                    if !plus { Text("鍵のついた項目は Thirty+（買い切り）で使えます。") }
                }

                Section {
                    Button("はじめの案内をもう一度見る") {
                        dismiss()
                        onShowGuide()
                    }
                    if model.notificationNotice != nil {
                        Button("終了通知の設定を開く") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    if !plus {
                        Button("購入を復元") { Task { await store.restore() } }
                    }
                }
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("閉じる")
                }
            }
            .sheet(isPresented: $showPlus) { PlusView(store: store) }
            .sheet(isPresented: $showSkins) { SkinPicker(store: store, selectedID: $skinID) }
        }
    }

    /// Locked rows stay visible; changing one opens the Thirty+ sheet instead.
    private func plusToggle(_ title: String, isOn: Binding<Bool>, lockedValue: Bool = false) -> some View {
        Toggle(isOn: Binding(
            get: { plus ? isOn.wrappedValue : lockedValue },
            set: { value in if plus { isOn.wrappedValue = value } else { showPlus = true } }
        )) {
            HStack(spacing: 6) {
                Text(title)
                if !plus { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }

    private func plusPicker<Value: Hashable, Content: View>(
        _ title: String, selection: Binding<Value>, @ViewBuilder content: () -> Content,
        isAllowed: @escaping (Value) -> Bool
    ) -> some View {
        Picker(title, selection: Binding(
            get: { selection.wrappedValue },
            set: { value in if plus || isAllowed(value) { selection.wrappedValue = value } else { showPlus = true } }
        ), content: content)
    }

    private var iconRow: some View {
        let icons: [(String?, String)] = [(nil, "標準"), ("AppIcon-Paper", "ペーパー"), ("AppIcon-Mint", "ミント"),
                                          ("AppIcon-Amber", "アンバー"), ("AppIcon-Night", "ナイトブルー"), ("AppIcon-Ruby", "ルビー")]
        return Picker("アプリのアイコン", selection: Binding(
            get: { iconName ?? "" },
            set: { value in
                guard plus || value.isEmpty else { showPlus = true; return }
                let name = value.isEmpty ? nil : value
                UIApplication.shared.setAlternateIconName(name) { error in
                    DispatchQueue.main.async { if error == nil { iconName = name } }
                }
            }
        )) {
            ForEach(icons.indices, id: \.self) { index in
                let icon = icons[index]
                Text(icon.1 + (icon.0 == nil || plus ? "" : " 🔒")).tag(icon.0 ?? "")
            }
        }
    }
}

/// What Thirty+ adds. Everything needed to time and focus stays free.
struct PlusView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    private let perks: [(String, String, String)] = [
        ("paintpalette", "スキン", "アンバー、ナイトブルー、ルビーなど5種類"),
        ("lock.iphone", "閉じても、残りが見える", "ほかのアプリやロック画面でも、画面上部の黒い部分（Dynamic Island）やロック画面に、減っていく棒と残り時間が出ます。充電中に横置きすると置き時計にも（StandBy）"),
        ("bell", "終了音", "キッチンタイマーのピピピ、ベル、やさしい音、振動のみ"),
        ("arrow.triangle.2.circlepath", "休憩をはさんでくり返す", "30分→休憩5分→30分…を自動で"),
        ("app.badge", "アプリのアイコン", "スキンに合わせた5種類"),
        ("slider.horizontal.3", "表示の細かい設定", "棒を60本に、分だけの表示に"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Thirty+").font(.largeTitle.weight(.bold))
                        Text("タイマーは無料のまま、広告もありません。\n気に入ったら、買い切りでどうぞ。")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(perks.indices, id: \.self) { index in
                            let perk = perks[index]
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: perk.0).font(.title3).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(perk.1).font(.headline)
                                    Text(perk.2).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    if store.hasPlus {
                        Label("購入済みです。ありがとうございます。", systemImage: "heart.fill").foregroundStyle(.secondary)
                    } else {
                        PlusBuyButtons(store: store)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("閉じる")
                }
            }
        }
    }
}

struct PlusBuyButtons: View {
    @ObservedObject var store: Store
    var onPurchased: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await store.purchase()
                    if store.hasPlus { onPurchased() }
                }
            } label: {
                Group {
                    if store.isBusy { ProgressView() } else {
                        Text(store.product == nil ? "Thirty+ を購入" : "\(store.priceText)で購入").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(TimerTheme.onAccent)
                .background(TimerTheme.accent, in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(store.isBusy)
            Text("買い切りです。定期購入ではありません。").font(.caption).foregroundStyle(.secondary)
            Button("購入を復元") { Task { await store.restore() } }
                .font(.footnote).frame(minHeight: 44).disabled(store.isBusy)
            if let message = store.message {
                Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
}
