import SwiftUI
import UIKit

enum TimerTheme {
    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    /// The whole screen is the LCD; dark mode reads as a backlit panel.
    static let lcd = dynamic(UIColor(red: 0.72, green: 0.76, blue: 0.67, alpha: 1),
                             UIColor(red: 0.055, green: 0.067, blue: 0.055, alpha: 1))
    static let ink = dynamic(UIColor(red: 0.11, green: 0.14, blue: 0.11, alpha: 1),
                             UIColor(red: 0.81, green: 0.88, blue: 0.74, alpha: 1))
    static let ghost = ink.opacity(0.075)
    static let line = ink.opacity(0.16)
    static let soft = ink.opacity(0.08)
    static let paper = dynamic(UIColor(red: 0.953, green: 0.949, blue: 0.933, alpha: 1),
                               UIColor(red: 0.078, green: 0.086, blue: 0.078, alpha: 1))
    static let accent = dynamic(UIColor(red: 0.11, green: 0.14, blue: 0.11, alpha: 1),
                                UIColor(red: 0.81, green: 0.88, blue: 0.74, alpha: 1))
    static let onAccent = dynamic(UIColor(red: 0.953, green: 0.949, blue: 0.933, alpha: 1),
                                  UIColor(red: 0.06, green: 0.075, blue: 0.06, alpha: 1))
}

struct TimerView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var store: Store
    @StateObject private var orientation = OrientationController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AppStorage("onboardingSeen.v3") private var onboardingSeen = false
    @AppStorage("skin") private var skinID = Skin.classic.id
    @AppStorage("completedCount") private var completedCount = 0
    @AppStorage("plusInvitationShown") private var plusInvitationShown = false
    @State private var showSkins = false
    @State private var showSettings = false
    /// Slats lit during the short fill-up that marks a start.
    @State private var ritualLit: Int?
    private static var launched = false
    /// Screenshot runs keep the finished digits steady.
    private static var noBlink: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "ThirtyNoBlink")
        #else
        return false
        #endif
    }
    @State private var guideStart: OnboardingGuide.Page?
    @State private var showTime = false
    @State private var showHint = false
    @State private var lastTouch = Date()
    @State private var hardwareButton: HardwareButton = .side
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let idleDelay: TimeInterval = 4

    private var skin: Skin { Skin.resolve(skinID, hasPlus: store.hasPlus) }

    /// One gentle invitation after the third finished session, never while timing.
    private var showsInvitation: Bool {
        model.countdown.phase == .finished && completedCount >= 3 && !plusInvitationShown && !store.hasPlus
    }

    /// While running, the controls step aside and the phone is only the timer.
    private var chromeHidden: Bool {
        model.countdown.phase == .running && !voiceOver && guideStart == nil && !showTime
            && Date().timeIntervalSince(lastTouch) > idleDelay
    }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                skin.lcd.ignoresSafeArea()
                Group {
                    if landscape { landscapeLayout(geometry.size) } else { portraitLayout }
                }
                .padding(.horizontal, landscape ? 20 : 16).padding(.bottom, landscape ? 12 : 16)
                if showHint && guideStart == nil && !model.isGuidedAccessActive && model.countdown.phase == .running {
                    ButtonHint(kind: hardwareButton) { showHint = false }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { lastTouch = Date() }
            .onAppear { hardwareButton = HardwareButton.current(hasHomeIndicator: geometry.safeAreaInsets.bottom > 0) }
        }
        .foregroundStyle(skin.ink)
        .tint(skin.ink)
        .environment(\.skin, skin)
        .preferredColorScheme(skin.colorScheme)
        .statusBarHidden(chromeHidden)
        .persistentSystemOverlays(chromeHidden ? .hidden : .automatic)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: chromeHidden)
        .onReceive(ticker) { _ in if scenePhase == .active { model.tick() } }
        .onReceive(store.$hasPlus) { model.hasPlus = $0 }
        .onOpenURL { url in
            guard url.scheme == ThirtyLink.scheme, url.host == "start" else { return }
            let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "minutes" }?.value.flatMap(Int.init)
            model.startNow(minutes: minutes)
        }
        .onAppear {
            model.hasPlus = store.hasPlus
            model.sceneChanged(scenePhase)
            if !onboardingSeen { guideStart = .welcome }
            if !Self.launched {
                Self.launched = true
                if onboardingSeen && model.startOnLaunch { model.startNow() }
            }
            showHint = model.countdown.phase == .running
        }
        .onChange(of: scenePhase) { _, phase in model.sceneChanged(phase) }
        .onChange(of: model.countdown.phase) { oldPhase, phase in
            lastTouch = Date()
            if phase == .finished { completedCount += 1 }
            if phase == .running && (oldPhase == .ready || oldPhase == .finished) {
                showHint = true
                playRitual()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
            model.isGuidedAccessActive = UIAccessibility.isGuidedAccessEnabled
            if model.isGuidedAccessActive { showHint = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thirtyNotificationArrived)) { _ in model.tick() }
        .sheet(item: $guideStart, onDismiss: { onboardingSeen = true }) { start in
            OnboardingGuide(start: start, hardwareButton: hardwareButton) {
                onboardingSeen = true
                guideStart = nil
            }
            .largeSheetOnPad()
        }
        .sheet(isPresented: $showSkins) {
            SkinPicker(store: store, selectedID: $skinID).largeSheetOnPad()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model, store: store, skinID: $skinID) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { guideStart = .welcome }
            }
        }
        .sheet(isPresented: $showTime) {
            TimePickerView(seconds: model.countdown.phase == .finished ? model.countdown.configuredSeconds : model.seconds) {
                model.setSeconds($0)
            }
        }
    }

    // MARK: Layouts

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar(landscape: false)
            SlatBars(lit: ritualLit ?? model.bars, count: model.effectiveSlats, stacked: true)
                .padding(.top, 12).padding(.bottom, 18)
            Rectangle().fill(skin.line).frame(height: 1.5)
            digits.frame(maxWidth: 560).padding(.top, 24)
            if showsInvitation { invitation.padding(.top, 16) }
            controls(compact: false).padding(.top, showsInvitation ? 16 : 28)
        }
    }

    private func landscapeLayout(_ size: CGSize) -> some View {
        VStack(spacing: 4) {
            topBar(landscape: true)
            HStack(spacing: 24) {
                SlatBars(lit: ritualLit ?? model.bars, count: model.effectiveSlats, stacked: false)
                Rectangle().fill(skin.line).frame(width: 1.5)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    digits
                    if !chromeHidden {
                        controls(compact: true).padding(.top, 20)
                            .transition(.opacity)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: max(240, size.width * 0.36))
            }
        }
    }

    /// Running or paused: the time can no longer be changed.
    private var timing: Bool {
        model.countdown.phase == .running || model.countdown.phase == .paused
    }

    private var digits: some View {
        Button { lastTouch = Date(); if !timing { showTime = true } } label: {
            SevenSegmentTime(text: model.timeText).opacity(blinkOpacity)
                .overlay(alignment: .topLeading) {
                    if model.isBreak {
                        Text("休憩").font(.system(size: 13, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(skin.lcd).background(skin.ink, in: Capsule())
                            .offset(y: -22)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(timing ? "残り時間" : "時間を変更")
        .accessibilityValue(model.countdown.phase == .paused ? "\(model.remainingLabel)、一時停止中" : model.remainingLabel)
    }

    /// LCD-style blink when finished, and a slower one while paused.
    private var blinkOpacity: Double {
        guard !reduceMotion && !Self.noBlink else { return model.countdown.phase == .paused ? 0.5 : 1 }
        let halfSeconds = Int(Date().timeIntervalSinceReferenceDate * 2)
        switch model.countdown.phase {
        case .finished: return halfSeconds % 2 == 0 ? 1 : 0.15
        case .paused: return halfSeconds % 4 < 2 ? 1 : 0.15
        default: return 1
        }
    }

    private func topBar(landscape: Bool) -> some View {
        HStack(spacing: 4) {
            LockChip(active: model.isGuidedAccessActive) {
                lastTouch = Date()
                guideStart = model.isGuidedAccessActive ? .triple : .enable
            }
            Spacer()
            iconButton("paintpalette", label: "スキン") {
                lastTouch = Date()
                showSkins = true
            }
            iconButton(model.dimScreen ? "moon.fill" : "moon", label: "画面を暗くする") {
                lastTouch = Date()
                model.dimScreen.toggle()
            }
            .accessibilityValue(model.dimScreen ? "オン" : "オフ")
            if orientation.canForce {
                iconButton(landscape ? "iphone" : "arrow.up.left.and.arrow.down.right",
                           label: landscape ? "縦向きに戻す" : "横向きにする") {
                    lastTouch = Date()
                    orientation.toggle(isLandscape: landscape)
                }
            }
            iconButton("gearshape", label: "設定") {
                lastTouch = Date()
                showSettings = true
            }
        }
        .frame(minHeight: 48)
        .opacity(chromeHidden ? 0 : 1)
        .allowsHitTesting(!chromeHidden)
    }

    @ViewBuilder
    private func controls(compact: Bool) -> some View {
        if model.countdown.phase == .finished {
            finishedControls(compact: compact)
        } else {
            timingControls(compact: compact)
        }
    }

    /// Done or not, the only questions are: another round, or stop here.
    private func finishedControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            Button { lastTouch = Date(); model.again() } label: {
                Text("もう\(model.lastMinutes)分").font(.system(size: 18, weight: .bold))
                    .frame(minWidth: 180, minHeight: compact ? 52 : 60)
                    .padding(.horizontal, 12)
                    .foregroundStyle(skin.lcd)
                    .background(skin.ink, in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            Button { lastTouch = Date(); model.reset(); showHint = false } label: {
                Text("おしまい").font(.system(size: 16, weight: .semibold))
                    .frame(minWidth: 140, minHeight: 44)
                    .overlay(Capsule().stroke(skin.line, lineWidth: 1.5))
            }
            .buttonStyle(SoftPressStyle())
        }
        .frame(minHeight: compact ? 120 : 138)
    }

    private func timingControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 18) {
            // Time is set before starting; once a session is under way it stays as it is.
            HStack(spacing: 12) {
                increment(-10)
                increment(-1)
                increment(1)
                increment(10)
            }
            .opacity(timing ? 0 : 1)
            .allowsHitTesting(!timing)
            .accessibilityHidden(timing)
            HStack(spacing: 20) {
                if model.countdown.phase != .ready {
                    Button { lastTouch = Date(); model.reset(); showHint = false } label: {
                        Image(systemName: "stop.fill").font(.system(size: 17))
                            .frame(width: compact ? 48 : 56, height: compact ? 48 : 56)
                            .background(skin.soft, in: Circle())
                    }
                    .buttonStyle(SoftPressStyle()).accessibilityLabel("終了")
                }
                Button(action: primaryAction) {
                    Image(systemName: model.countdown.phase == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 24 : 28))
                        .frame(width: compact ? 64 : 76, height: compact ? 64 : 76)
                        .foregroundStyle(skin.lcd)
                        .background(skin.ink, in: Circle())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(primaryLabel)
                .disabled(model.countdown.configuredSeconds == 0)
                .opacity(model.countdown.configuredSeconds == 0 ? 0.25 : 1)
            }
            .frame(minHeight: compact ? 64 : 76)
        }
        .opacity(chromeHidden ? 0 : 1)
        .allowsHitTesting(!chromeHidden)
    }

    private var primaryLabel: String {
        switch model.countdown.phase {
        case .ready, .finished: return "開始"
        case .running: return "一時停止"
        case .paused: return "再開"
        }
    }

    private func primaryAction() {
        lastTouch = Date()
        switch model.countdown.phase {
        case .ready, .finished: model.start()
        case .running: model.pause()
        case .paused: model.resume(); showHint = true
        }
    }

    /// The slats fill up once before draining: a small "here we go".
    private func playRitual() {
        guard !reduceMotion else { return }
        let total = model.effectiveSlats
        Task { @MainActor in
            for step in stride(from: 0, through: total, by: max(1, total / 15)) {
                ritualLit = step
                try? await Task.sleep(nanoseconds: 35_000_000)
            }
            ritualLit = nil
        }
    }

    private func increment(_ minutes: Int) -> some View {
        Button { lastTouch = Date(); model.addMinutes(minutes) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(minutes > 0 ? "+\(minutes)" : "−\(-minutes)").font(.system(size: 17, weight: .semibold).monospacedDigit())
                Text("分").font(.system(size: 11)).opacity(0.7)
            }
            .frame(minWidth: 60, minHeight: 44).padding(.horizontal, 2)
            .overlay(Capsule().stroke(skin.line, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(minutes < 0 && !model.canSubtract)
        .opacity(minutes < 0 && !model.canSubtract ? 0.3 : 1)
        .accessibilityLabel(minutes > 0 ? "\(minutes)分追加" : "\(-minutes)分減らす")
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 19)).frame(width: 44, height: 44)
        }
        .buttonStyle(SoftPressStyle()).accessibilityLabel(label)
    }

    private var invitation: some View {
        HStack(spacing: 8) {
            Button {
                plusInvitationShown = true
                showSkins = true
            } label: {
                Label("気に入ったら、Thirty+ でスキンを", systemImage: "paintpalette")
                    .font(.system(size: 13, weight: .semibold)).frame(minHeight: 44)
            }
            Button { plusInvitationShown = true } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 36, height: 44)
            }
            .accessibilityLabel("閉じる")
        }
        .padding(.leading, 14).padding(.trailing, 4)
        .overlay(Capsule().stroke(skin.line, lineWidth: 1.5))
        .buttonStyle(SoftPressStyle())
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// Shows whether the screen is pinned, and opens the setup when it is not.
struct LockChip: View {
    @Environment(\.skin) private var skin
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: active ? "lock.fill" : "lock.open").font(.system(size: 13, weight: .semibold))
                Text(active ? "ロック中" : "ロック").font(.system(size: 14, weight: .semibold))
            }
            .padding(.leading, 11).padding(.trailing, 14).frame(height: 36)
            .foregroundStyle(active ? skin.lcd : skin.ink)
            .background(active ? skin.ink : .clear, in: Capsule())
            .overlay(Capsule().stroke(active ? skin.ink : skin.line, lineWidth: 1.5))
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(active ? "アクセスガイド実行中" : "アクセスガイドでロックする方法")
    }
}

/// Thirty slats, like the physical timer. Stacked in portrait so the level
/// drains from the top; side by side in landscape, draining from the right.
struct SlatBars: View {
    @Environment(\.skin) private var skin
    let lit: Int
    var count = Countdown.slats
    let stacked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let length = stacked ? geometry.size.height : geometry.size.width
            let spacing = max(1, min(8, length / CGFloat(count) * 0.3))
            let layout = stacked ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
            layout {
                ForEach(0..<count, id: \.self) { index in
                    let fromStart = stacked ? count - 1 - index : index
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fromStart < lit ? skin.ink : skin.ghost)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: lit)
        .accessibilityHidden(true)
    }
}

/// Points at the hardware button that starts Guided Access.
struct ButtonHint: View {
    @Environment(\.skin) private var skin
    let kind: HardwareButton
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var normalizedLocation: CGPoint {
        let original: CGPoint
        switch kind {
        case .side: original = CGPoint(x: 1, y: 0.2)
        case .top: original = CGPoint(x: 0.85, y: 0)
        case .home: original = CGPoint(x: 0.5, y: 1)
        }
        let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation
        switch orientation {
        case .landscapeLeft: return CGPoint(x: original.y, y: 1 - original.x)
        case .landscapeRight: return CGPoint(x: 1 - original.y, y: original.x)
        case .portraitUpsideDown: return CGPoint(x: 1 - original.x, y: 1 - original.y)
        default: return original
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let point = normalizedLocation
            let vertical = point.y == 0 || point.y == 1
            // Along the top or bottom edge the dots sit beside the text, so the
            // tab is wider, and taller to clear the screen edge and home indicator.
            let size = vertical ? CGSize(width: 184, height: 68) : CGSize(width: 136, height: 52)
            let x = point.x == 0 ? size.width / 2 : point.x == 1 ? geometry.size.width - size.width / 2
                : min(geometry.size.width - size.width / 2, max(size.width / 2, point.x * geometry.size.width))
            let y = point.y == 0 ? size.height / 2 : point.y == 1 ? geometry.size.height - size.height / 2
                : min(geometry.size.height - size.height / 2, max(size.height / 2, point.y * geometry.size.height))
            content(vertical: vertical)
                .padding(point.y == 1 ? .bottom : .top, vertical ? 14 : 0)
                .frame(width: size.width, height: size.height)
                .background(skin.ink, in: edgeShape(point))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .position(x: x, y: y)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func content(vertical: Bool) -> some View {
        HStack(spacing: 10) {
            pulses(vertical: vertical)
            VStack(alignment: .leading, spacing: 0) {
                Text("×3").font(.system(size: 20, weight: .bold).monospacedDigit())
                Text(kind.title).font(.system(size: 10)).opacity(0.75).lineLimit(1).fixedSize()
            }
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).frame(width: 36, height: 44) }
                .accessibilityLabel("ボタンの案内を閉じる")
        }
        .foregroundStyle(skin.lcd)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title)を3回連続で押すと、アクセスガイドでロックできます")
    }

    private func pulses(vertical: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 5) % 9
            let dots = ForEach(0..<3, id: \.self) { index in
                Circle().frame(width: 6, height: 6).opacity(!reduceMotion && tick == index ? 1 : 0.3)
            }
            if vertical { HStack(spacing: 4) { dots } } else { VStack(spacing: 4) { dots } }
        }
        .accessibilityHidden(true)
    }

    private func edgeShape(_ point: CGPoint) -> UnevenRoundedCorners {
        if point.x == 1 { return UnevenRoundedCorners(topLeading: 26, bottomLeading: 26) }
        if point.x == 0 { return UnevenRoundedCorners(bottomTrailing: 26, topTrailing: 26) }
        if point.y == 0 { return UnevenRoundedCorners(bottomLeading: 26, bottomTrailing: 26) }
        return UnevenRoundedCorners(topLeading: 26, topTrailing: 26)
    }
}

/// UnevenRoundedRectangle needs iOS 17; this keeps the iOS 16 target.
struct UnevenRoundedCorners: Shape {
    var topLeading: CGFloat = 0
    var bottomLeading: CGFloat = 0
    var bottomTrailing: CGFloat = 0
    var topTrailing: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
    private var radius: CGFloat { max(topLeading, bottomLeading, bottomTrailing, topTrailing) }
    private var corners: UIRectCorner {
        var corners: UIRectCorner = []
        if topLeading > 0 { corners.insert(.topLeft) }
        if bottomLeading > 0 { corners.insert(.bottomLeft) }
        if bottomTrailing > 0 { corners.insert(.bottomRight) }
        if topTrailing > 0 { corners.insert(.topRight) }
        return corners
    }
}

struct TimePickerView: View {
    @State private var minutes: Int
    @State private var seconds: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    private let presets = [5, 15, 25, 30, 45, 60, 90, 120]

    init(seconds: Int, onSave: @escaping (Int) -> Void) {
        _minutes = State(initialValue: seconds / 60)
        _seconds = State(initialValue: seconds % 60)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button { onSave(preset * 60); dismiss() } label: {
                            Text("\(preset)").font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(SoftPressStyle())
                        .accessibilityLabel("\(preset)分")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)
                HStack(spacing: 0) {
                    Picker("分", selection: $minutes) {
                        ForEach(0...(Countdown.maximumSeconds / 60), id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.pickerStyle(.wheel).accessibilityLabel("分")
                    Text(":").font(.largeTitle)
                    Picker("秒", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.pickerStyle(.wheel).accessibilityLabel("秒")
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("時間").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onSave(minutes * 60 + seconds); dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel("時間を決定")
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
    }
}

extension View {
    /// iPad's default form sheet is small for the illustrated guide.
    @ViewBuilder
    func largeSheetOnPad() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Seven-segment digits drawn as shapes, with unlit segments left faintly
/// visible like a real LCD. Three-digit minutes widen the readout.
struct SevenSegmentTime: View {
    @Environment(\.skin) private var skin
    let text: String
    private var digitCount: CGFloat { CGFloat(text.filter(\.isNumber).count) }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            HStack(spacing: height * 0.09) {
                ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        VStack(spacing: height * 0.26) {
                            Circle().frame(width: height * 0.09, height: height * 0.09)
                            Circle().frame(width: height * 0.09, height: height * 0.09)
                        }
                        .frame(width: height * 0.12)
                    } else {
                        let lit = SegmentDigit.masks[character.wholeNumberValue ?? 0]
                        ZStack {
                            SegmentDigit(segments: Set(0..<7).subtracting(lit)).fill(skin.ink.opacity(0.07))
                            SegmentDigit(segments: lit).fill(skin.ink)
                        }
                        .frame(width: height * 0.55)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(digitCount * 0.64 + 0.3, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct SegmentDigit: Shape {
    static let masks: [Set<Int>] = [
        [0,1,2,4,5,6], [2,5], [0,2,3,4,6], [0,2,3,5,6], [1,2,3,5],
        [0,1,3,5,6], [0,1,3,4,5,6], [0,2,5], [0,1,2,3,4,5,6], [0,1,2,3,5,6]
    ]
    /// Hexagonal segments on a 22×40 grid whose x axis starts at -2.
    private static let polygons: [[CGPoint]] = {
        let outlines: [[(CGFloat, CGFloat)]] = [
            [(3, 0), (15, 0), (17, 2), (15, 4), (3, 4), (1, 2)],
            [(0, 3), (2, 5), (2, 17), (0, 19), (-2, 17), (-2, 5)],
            [(18, 3), (20, 5), (20, 17), (18, 19), (16, 17), (16, 5)],
            [(3, 18), (15, 18), (17, 20), (15, 22), (3, 22), (1, 20)],
            [(0, 21), (2, 23), (2, 35), (0, 37), (-2, 35), (-2, 23)],
            [(18, 21), (20, 23), (20, 35), (18, 37), (16, 35), (16, 23)],
            [(3, 36), (15, 36), (17, 38), (15, 40), (3, 40), (1, 38)],
        ]
        return outlines.map { outline in outline.map { CGPoint(x: $0.0, y: $0.1) } }
    }()

    let segments: Set<Int>

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 22, scaleY = rect.height / 40
        var path = Path()
        for index in segments.sorted() {
            let points = Self.polygons[index].map {
                CGPoint(x: rect.minX + ($0.x + 2) * scaleX, y: rect.minY + $0.y * scaleY)
            }
            path.addLines(points)
            path.closeSubpath()
        }
        return path
    }
}
