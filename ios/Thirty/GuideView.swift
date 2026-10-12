import SwiftUI
import LocalAuthentication

/// First launch: what Thirty is, then the optional Guided Access setup.
/// The lock chip reopens it from the setup pages.
struct OnboardingGuide: View {
    enum Page: Int, CaseIterable, Identifiable {
        case welcome, enable, biometry, triple
        var id: Int { rawValue }
    }

    let start: Page
    let hardwareButton: HardwareButton
    let onDone: () -> Void
    @State private var page: Page
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(start: Page, hardwareButton: HardwareButton, onDone: @escaping () -> Void) {
        self.start = start
        self.hardwareButton = hardwareButton
        self.onDone = onDone
        _page = State(initialValue: start)
    }

    private var pages: [Page] { Page.allCases.filter { $0.rawValue >= start.rawValue } }
    private var biometry: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        default: return hardwareButton == .home ? "Touch ID" : "Face ID"
        }
    }
    private var unlockPresses: Int { ProcessInfo.processInfo.operatingSystemVersion.majorVersion <= 18 ? 2 : 3 }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page.animation(reduceMotion ? nil : .easeInOut)) {
                ForEach(pages) { item in
                    ScrollView { content(for: item).padding(.horizontal, 28).padding(.bottom, 12) }
                        .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(TimerTheme.paper.ignoresSafeArea())
        .foregroundStyle(Color.primary)
        .interactiveDismissDisabled(start == .welcome && page == .welcome)
    }

    private var header: some View {
        HStack {
            Button { move(by: -1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .opacity(page == pages.first ? 0 : 1).disabled(page == pages.first)
                .accessibilityLabel("前へ")
            Spacer()
            HStack(spacing: 6) {
                ForEach(pages) { item in
                    Capsule().fill(Color.primary.opacity(item == page ? 1 : 0.2))
                        .frame(width: item == page ? 20 : 6, height: 6)
                }
            }
            .accessibilityElement().accessibilityLabel("\((pages.firstIndex(of: page) ?? 0) + 1) / \(pages.count)")
            Spacer()
            Button(action: onDone) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("案内を閉じる")
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.horizontal, 12).padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button { if page == .triple { onDone() } else { move(by: 1) } } label: {
                Text(page == .triple ? "タイマーへ" : "次へ").font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(TimerTheme.onAccent)
                    .background(TimerTheme.accent, in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            Button(secondaryTitle, action: secondaryAction)
                .font(.system(size: 15)).foregroundStyle(.secondary).frame(minHeight: 44)
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
    }

    private var secondaryTitle: String {
        switch page {
        case .welcome: return "すぐに始める"
        case .enable: return "あとで設定する"
        case .biometry: return "スキップ"
        case .triple: return "最初から見る"
        }
    }

    private func secondaryAction() {
        switch page {
        case .welcome, .enable: onDone()
        case .biometry: page = .triple
        case .triple: page = pages.first ?? .welcome
        }
    }

    private func move(by offset: Int) {
        guard let index = pages.firstIndex(of: page), pages.indices.contains(index + offset) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut) { page = pages[index + offset] }
    }

    @ViewBuilder
    private func content(for item: Page) -> some View {
        VStack(spacing: 0) {
            switch item {
            case .welcome:
                MiniTimerDemo().frame(maxWidth: 190, maxHeight: 300).padding(.vertical, 20)
                titleBlock(eyebrow: "THIRTY", title: "とりあえず、30分！",
                           body: "「やるべきことがあるのに、\nSNSを1時間見てしまっていた…」\nそんな時は、考える前に\nタイマーをスタートしてしまいましょう！")
            case .enable:
                titleBlock(eyebrow: "STEP 1 ・ 任意", title: "ほかのアプリに\n逃げられなくする",
                           body: "iPhoneの「アクセスガイド」を使うと、\n計測中はThirtyから出られなくなります。")
                Breadcrumbs(items: ["設定", "アクセシビリティ", "アクセスガイド"]).padding(.top, 32)
                SettingsMock {
                    SettingsMockRow(title: "アクセスガイド", accessory: .toggle, highlighted: true)
                    SettingsMockNote(text: "設定アプリで、このスイッチをオンにします。")
                    SettingsMockRow(title: "パスコード設定", accessory: .chevron)
                }
                .padding(.top, 12)
                Link("Appleの説明を見る", destination: URL(string: "https://support.apple.com/ja-jp/111795")!)
                    .font(.footnote).foregroundStyle(.secondary).frame(minHeight: 44).padding(.top, 8)
            case .biometry:
                titleBlock(eyebrow: "STEP 2 ・ 任意", title: "解除は\(biometry)で",
                           body: "パスコード設定で\(biometry)をオンにすると、\n終わったあとの解除がかんたんです。")
                Breadcrumbs(items: ["アクセスガイド", "パスコード設定"]).padding(.top, 32)
                SettingsMock {
                    SettingsMockRow(title: "アクセスガイドのパスコードを設定", accessory: .none, isLink: true)
                    SettingsMockNote(text: "はじめてなら、ここで6桁のパスコードを決めます。")
                    SettingsMockRow(title: biometry, accessory: .toggle, highlighted: true)
                }
                .padding(.top, 12)
            case .triple:
                titleBlock(eyebrow: "STEP 3", title: "始めたら、\n\(hardwareButton.title)を3回",
                           body: "Thirtyの画面でカチカチカチ。\n画面が固定され、他のアプリを開けません。")
                PressDiagram(kind: hardwareButton).frame(height: 260).padding(.vertical, 24)
                Text("解除は同じボタンを\(unlockPresses)回 → 認証 → 「終了」。\nタイマーが終わっても、ロックは自動では外れません。")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
            }
        }
        .frame(maxWidth: 440).frame(maxWidth: .infinity)
    }

    private func titleBlock(eyebrow: String, title: String, body: String) -> some View {
        VStack(spacing: 10) {
            Text(eyebrow).font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.secondary)
            Text(title).font(.system(size: 26, weight: .bold)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(body).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }
}

/// A small phone draining its bars, so the idea lands before any words.
struct MiniTimerDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 19
            let lit = reduceMotion ? 12 : 18 - step
            VStack(spacing: 10) {
                VStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1).fill(17 - index < lit ? TimerTheme.ink : TimerTheme.ghost)
                    }
                }
                Rectangle().fill(TimerTheme.line).frame(height: 1.5)
                SevenSegmentTime(text: "30:00").frame(height: 40)
            }
            .padding(.horizontal, 18).padding(.vertical, 22)
            .aspectRatio(9 / 14, contentMode: .fit)
            .background(TimerTheme.lcd, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.primary, lineWidth: 7))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: lit)
        }
        .accessibilityHidden(true)
    }
}

struct Breadcrumbs: View {
    let items: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).opacity(0.5) }
                Text(item)
            }
        }
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        .accessibilityElement().accessibilityLabel(items.joined(separator: "、"))
    }
}

/// Looks like the Settings app so the right row is easy to spot there.
/// It is a picture: nothing in it changes a setting.
struct SettingsMock<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(14)
            .background(Color(uiColor: .systemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: 360)
    }
}

struct SettingsMockRow: View {
    enum Accessory { case none, toggle, chevron }
    let title: String
    let accessory: Accessory
    var highlighted = false
    var isLink = false
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16)).foregroundStyle(isLink ? Color.accentColor : Color.primary)
            Spacer(minLength: 8)
            switch accessory {
            case .toggle:
                Capsule().fill(on ? Color.green : Color(uiColor: .systemFill)).frame(width: 51, height: 31)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 27, height: 27).padding(2).shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
            case .chevron:
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.tertiary)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 52)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.accentColor, lineWidth: 3)
            }
        }
        .onAppear {
            guard accessory == .toggle else { return }
            if reduceMotion { on = true; return }
            on = false
            withAnimation(.easeInOut(duration: 0.35).delay(0.9)) { on = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessory == .toggle ? "設定アプリの\(title)をオンにする" : title)
    }
}

struct SettingsMockNote: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
    }
}

/// The device outline with its button pressed three times, then a pause.
struct PressDiagram: View {
    let kind: HardwareButton
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 8
            let pressed = !reduceMotion && [0, 2, 4].contains(tick)
            let count = reduceMotion ? 3 : min(3, tick / 2 + 1)
            ZStack {
                RoundedRectangle(cornerRadius: kind == .top ? 24 : 32, style: .continuous)
                    .stroke(Color.primary, lineWidth: 3)
                    .frame(width: kind == .top ? 200 : 128, height: kind == .top ? 256 : 250)
                button(pressed: pressed)
                Text("×\(count)").font(.system(size: 44, weight: .light).monospacedDigit())
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func button(pressed: Bool) -> some View {
        switch kind {
        case .side:
            Capsule().frame(width: 5, height: 44).scaleEffect(x: 1, y: pressed ? 0.7 : 1).offset(x: 68, y: -62)
        case .top:
            Capsule().frame(width: 40, height: 5).scaleEffect(x: pressed ? 0.7 : 1, y: 1).offset(x: 60, y: -132)
        case .home:
            Circle().stroke(Color.primary, lineWidth: 2).frame(width: 26, height: 26)
                .scaleEffect(pressed ? 0.75 : 1).offset(y: 100)
        }
    }
}
