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
                    Toggle(String(localized: "開いたらすぐスタート"), isOn: $model.startOnLaunch)
                } header: {
                    Text(String(localized: "始めかた"))
                } footer: {
                    Text(String(localized: "ショートカットApp、アクションボタン、コントロールセンター、ホーム画面のアイコンの長押し、ウィジェットからも、ワンタップで始められます。"))
                }

                Section(String(localized: "計測中")) {
                    Toggle(String(localized: "画面を暗くする"), isOn: $model.dimScreen)
                    Toggle(String(localized: "画面を消さない"), isOn: $model.keepScreenOn)
                    Toggle(String(localized: "伏せたら画面を消す"), isOn: $model.faceDownScreenOff)
                }

                Section {
                    if !plus {
                        Button { showPlus = true } label: {
                            HStack {
                                Label(String(localized: "Thirty+ でできること"), systemImage: "sparkles")
                                Spacer()
                                Text(store.product?.displayPrice ?? "").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Button { showSkins = true } label: {
                        HStack {
                            Text(String(localized: "スキン")).foregroundStyle(Color.primary)
                            Spacer()
                            Text(skin.name).foregroundStyle(.secondary)
                            SkinSample(skin: skin, lit: 3, slats: 4, compact: true).frame(width: 34, height: 40)
                        }
                    }
                    plusPicker(String(localized: "終了音"), selection: $model.endSound) {
                        ForEach(EndSound.allCases) { sound in
                            Text(sound.title + (sound.isFree || plus ? "" : " 🔒")).tag(sound)
                        }
                    } isAllowed: { $0.isFree }
                    plusToggle(String(localized: "休憩をはさんでくり返す"), isOn: $model.cycleEnabled)
                    if plus && model.cycleEnabled {
                        Stepper(String(localized: "休憩 \(model.breakMinutes)分"), value: $model.breakMinutes, in: 1...30)
                    }
                    plusToggle(String(localized: "閉じても残り時間を表示"), isOn: $model.liveActivityEnabled)
                    plusPicker(String(localized: "棒の本数"), selection: $model.slatCount) {
                        Text(String(localized: "30本")).tag(30)
                        Text(String(localized: "60本") + (plus ? "" : " 🔒")).tag(60)
                    } isAllowed: { $0 == 30 }
                    plusToggle(String(localized: "秒を表示"), isOn: $model.showSeconds, lockedValue: true)
                    iconRow
                } header: {
                    HStack {
                        Text("Thirty+")
                        if !plus { Image(systemName: "lock.fill").font(.caption2) }
                    }
                } footer: {
                    if !plus { Text(String(localized: "鍵のついた項目は Thirty+（買い切り）で使えます。")) }
                }

                Section {
                    Button(String(localized: "はじめの案内をもう一度見る")) {
                        dismiss()
                        onShowGuide()
                    }
                    if model.notificationNotice != nil {
                        Button(String(localized: "終了通知の設定を開く")) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    if !plus {
                        Button(String(localized: "購入を復元")) { Task { await store.restore() } }
                    }
                    Link(String(localized: "プライバシーポリシー"), destination: URL(string: "https://mugi0227.github.io/thirty-support/privacy-policy/")!)
                        .accessibilityIdentifier("privacy-policy-link")
                    Link(String(localized: "サポート"), destination: URL(string: "https://mugi0227.github.io/thirty-support/support/")!)
                        .accessibilityIdentifier("support-link")
                }
            }
            .navigationTitle(String(localized: "設定")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(String(localized: "閉じる"))
                        .accessibilityIdentifier("close-settings")
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
        let icons: [(String?, String)] = [(nil, String(localized: "標準")), ("AppIcon-Paper", String(localized: "ペーパー")), ("AppIcon-Mint", String(localized: "ミント")),
                                          ("AppIcon-Amber", String(localized: "アンバー")), ("AppIcon-Night", String(localized: "ナイトブルー")), ("AppIcon-Ruby", String(localized: "ルビー"))]
        return Picker(String(localized: "アプリのアイコン"), selection: Binding(
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
        ("paintpalette", String(localized: "スキン"), String(localized: "アンバー、ナイトブルー、ルビーなど5種類")),
        ("lock.iphone", String(localized: "閉じても、残りが見える"), String(localized: "ほかのアプリやロック画面でも、画面上部の黒い部分（Dynamic Island）やロック画面に、減っていく棒と残り時間が出ます。充電中に横置きすると置き時計にも（StandBy）")),
        ("bell", String(localized: "終了音"), String(localized: "キッチンタイマーのピピピ、ベル、やさしい音、振動のみ")),
        ("arrow.triangle.2.circlepath", String(localized: "休憩をはさんでくり返す"), String(localized: "30分→休憩5分→30分…を自動で")),
        ("app.badge", String(localized: "アプリのアイコン"), String(localized: "スキンに合わせた5種類")),
        ("slider.horizontal.3", String(localized: "表示の細かい設定"), String(localized: "棒を60本に、分だけの表示に")),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Thirty+").font(.largeTitle.weight(.bold))
                        Text(String(localized: "タイマーは無料のまま、広告もありません。\n気に入ったら、買い切りでどうぞ。"))
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
                                    if perk.0 == "lock.iphone" {
                                        IslandSample().padding(.top, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    if store.hasPlus {
                        Label(String(localized: "購入済みです。ありがとうございます。"), systemImage: "heart.fill").foregroundStyle(.secondary)
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
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(String(localized: "閉じる"))
                        .accessibilityIdentifier("close-plus")
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
                    if store.product == nil {
                        await store.reloadProduct()
                    } else {
                        await store.purchase()
                        if store.hasPlus { onPurchased() }
                    }
                }
            } label: {
                Group {
                    if store.isBusy || store.isLoadingProducts {
                        HStack {
                            ProgressView()
                            Text(store.isLoadingProducts ? String(localized: "商品情報を読み込み中…") : String(localized: "処理中…"))
                        }
                    } else {
                        Text(store.product == nil ? String(localized: "商品情報を読み直す") : String(localized: "\(store.priceText)で購入")).font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(TimerTheme.onAccent)
                .background(TimerTheme.accent, in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(store.isBusy || store.isLoadingProducts)
            Text(String(localized: "買い切りです。定期購入ではありません。")).font(.caption).foregroundStyle(.secondary)
            Button(String(localized: "購入を復元")) { Task { await store.restore() } }
                .font(.footnote).frame(minHeight: 44).disabled(store.isBusy)
            if let message = store.message ?? store.productLoadFailure {
                Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if let details = store.diagnosticMessage {
                DisclosureGroup(String(localized: "詳しい情報")) {
                    Text(details).font(.caption).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.footnote)
            }
        }
        .task { if store.product == nil { await store.load() } }
    }
}

/// A picture of the Live Activity in the Dynamic Island, at about its real
/// size, so "the black area at the top of the screen" is clear before buying.
struct IslandSample: View {
    private let amber = LCDPalette.colors(for: "amber").ink

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1).fill(index < 4 ? amber : amber.opacity(0.2)).frame(width: 3.5)
                }
            }
            .frame(height: 15)
            Spacer(minLength: 0)
            Text("21:47").font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(amber)
        }
        .padding(.horizontal, 14)
        .frame(width: 230, height: 37)
        .background(Color.black, in: Capsule())
        .accessibilityHidden(true)
    }
}
