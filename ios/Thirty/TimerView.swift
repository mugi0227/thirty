import SwiftUI
import UIKit

enum TimerTheme {
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.10, blue: 0.09, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1)
    })
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let caseTop = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let caseBottom = Color(red: 0.83, green: 0.83, blue: 0.78)
    static let lcd = Color(red: 0.70, green: 0.74, blue: 0.65)
    static let lcdInk = Color(red: 0.12, green: 0.16, blue: 0.13)
    static let button = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .init(red: 0.91, green: 0.92, blue: 0.85, alpha: 1)
            : .init(red: 0.16, green: 0.20, blue: 0.17, alpha: 1)
    })
    static let buttonText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .black : .white
    })
}

struct TimerView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingSeen.v2") private var onboardingSeen = false
    @State private var showGuide = false
    @State private var showTime = false
    @State private var showHint = false
    @State private var hardwareButton: HardwareButton = .side
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                            icon(model.dimScreen ? "moon.fill" : "moon", label: "画面を暗くする", selected: model.dimScreen) {
                                model.dimScreen.toggle()
                            }
                            Spacer()
                            icon("info.circle", label: "アクセスガイドの説明") { showGuide = true }
                        }
                        Spacer(minLength: 120)
                        PhysicalTimer(time: model.timeText, bars: model.bars) { showTime = true }
                            .accessibilityValue(model.countdown.phase == .paused ? "一時停止中" : "")
                        HStack(spacing: 16) {
                            increment(1)
                            increment(10)
                        }.padding(.top, 32)
                        Spacer(minLength: 64)
                        HStack(spacing: 24) {
                            if model.countdown.phase != .ready {
                                icon("stop.fill", label: "終了", diameter: 64) { model.reset(); showHint = false }
                                    .background(TimerTheme.ink.opacity(0.08), in: Circle())
                            }
                            Button(action: primaryAction) {
                                Image(systemName: model.countdown.phase == .running ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24)).frame(width: 80, height: 80)
                                    .foregroundStyle(TimerTheme.buttonText)
                                    .background(TimerTheme.button, in: Circle())
                            }
                            .buttonStyle(SoftPressStyle())
                            .accessibilityLabel(primaryLabel)
                            .disabled(model.countdown.configuredSeconds == 0)
                            .opacity(model.countdown.configuredSeconds == 0 ? 0.35 : 1)
                        }
                        Spacer(minLength: 48)
                        if model.isGuidedAccessActive {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                .accessibilityLabel("アクセスガイド実行中")
                        }
                    }
                    .frame(maxWidth: 520).padding(.horizontal, 28).padding(.vertical, 12)
                    .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                }
                if showHint && !showGuide && !model.isGuidedAccessActive && model.countdown.phase == .running {
                    ButtonHint(kind: hardwareButton, size: geometry.size) { showHint = false }
                }
            }
            .onAppear { hardwareButton = HardwareButton.current(hasHomeIndicator: geometry.safeAreaInsets.bottom > 0) }
            .background(TimerTheme.background.ignoresSafeArea())
        }
        .tint(TimerTheme.ink)
        .onReceive(ticker) { if scenePhase == .active { model.tick(at: $0) } }
        .onAppear {
            model.sceneChanged(scenePhase)
            if !onboardingSeen { showGuide = true }
            showHint = model.countdown.phase == .running
        }
        .onChange(of: scenePhase) { model.sceneChanged($0) }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
            model.isGuidedAccessActive = UIAccessibility.isGuidedAccessEnabled
            if model.isGuidedAccessActive { showHint = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thirtyNotificationArrived)) { _ in model.tick() }
        .sheet(isPresented: $showGuide, onDismiss: { onboardingSeen = true }) {
            OnboardingGuide(model: model, hardwareButton: hardwareButton) {
                onboardingSeen = true
                showGuide = false
            }
        }
        .sheet(isPresented: $showTime) {
            TimePickerView(seconds: model.countdown.phase == .finished ? model.countdown.configuredSeconds : model.seconds) {
                model.setSeconds($0)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.countdown.phase)
    }
    private var primaryLabel: String {
        switch model.countdown.phase {
        case .ready, .finished: return "開始"
        case .running: return "一時停止"
        case .paused: return "再開"
        }
    }
    private func primaryAction() {
        switch model.countdown.phase {
        case .ready, .finished: model.start(); showHint = true
        case .running: model.pause()
        case .paused: model.resume(); showHint = true
        }
    }
    private func increment(_ minutes: Int) -> some View {
        Button("+\(minutes)min") { model.addMinutes(minutes) }
            .font(.system(.title3, design: .rounded)).frame(minWidth: 88, minHeight: 48)
            .background(TimerTheme.ink.opacity(0.06), in: Capsule())
            .accessibilityLabel("\(minutes)分追加")
    }
    private func icon(_ symbol: String, label: String, selected: Bool = false, diameter: CGFloat = 44,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20)).frame(width: diameter, height: diameter)
        }.buttonStyle(SoftPressStyle()).accessibilityLabel(label)
            .accessibilityValue(selected ? "オン" : "")
    }
}

struct TimePickerView: View {
    @State private var minutes: Int
    @State private var seconds: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    init(seconds: Int, onSave: @escaping (Int) -> Void) {
        _minutes = State(initialValue: seconds / 60)
        _seconds = State(initialValue: seconds % 60)
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("分", selection: $minutes) {
                    ForEach(0..<100, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.pickerStyle(.wheel).accessibilityLabel("分")
                Text(":").font(.largeTitle)
                Picker("秒", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.pickerStyle(.wheel).accessibilityLabel("秒")
            }
            .padding(24).navigationTitle("時間").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onSave(minutes * 60 + seconds); dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel("時間を決定")
                }
            }
        }.presentationDetents([.medium])
    }
}

struct ButtonHint: View {
    let kind: HardwareButton
    let size: CGSize
    let onClose: () -> Void
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
    private var location: CGPoint {
        CGPoint(x: min(size.width - 108, max(108, normalizedLocation.x * size.width)),
                y: min(size.height - 56, max(56, normalizedLocation.y * size.height)))
    }
    private var arrow: String {
        if normalizedLocation.y == 0 { return "arrow.up" }
        if normalizedLocation.y == 1 { return "arrow.down" }
        return normalizedLocation.x == 0 ? "arrow.left" : "arrow.right"
    }
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(.caption)
                Text("×3").font(.title2.monospacedDigit().weight(.semibold))
            }
            Image(systemName: arrow)
            Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("ボタンの案内を閉じる")
        }
        .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(TimerTheme.ink.opacity(0.1)))
        .position(location)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title)を3回連続で押すと、アクセスガイドを開始できます")
    }
}

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct PhysicalTimer: View {
    let time: String
    let bars: Int
    let onEdit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { index in
                        Rectangle().fill(TimerTheme.lcdInk.opacity(index < bars ? 1 : 0.09))
                    }
                }
                .accessibilityHidden(true)
                .padding(5)
                .background(TimerTheme.lcd)
                .overlay(Rectangle().stroke(.black.opacity(0.18), lineWidth: 1))
                SevenSegmentTime(text: time)
                    .aspectRatio(2.4, contentMode: .fit)
                    .padding(.horizontal, 6).padding(.vertical, 12)
                    .frame(width: width * 0.30)
                    .background(TimerTheme.lcd)
                    .overlay(Rectangle().stroke(.black.opacity(0.18), lineWidth: 1))
                    .overlay {
                        Button(action: onEdit) { Color.clear.contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("時間を変更").accessibilityValue(time)
                    }
            }
            .padding(12)
            .background(LinearGradient(colors: [TimerTheme.caseTop, TimerTheme.caseBottom], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 16)
        }
        .frame(height: 98)
    }
}

struct SevenSegmentTime: View {
    let text: String
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                if character == ":" {
                    VStack(spacing: 10) {
                        Circle().fill(TimerTheme.lcdInk).frame(width: 3, height: 3)
                        Circle().fill(TimerTheme.lcdInk).frame(width: 3, height: 3)
                    }.frame(width: 4)
                } else {
                    SevenSegmentDigit(value: character.wholeNumberValue ?? 0)
                }
            }
        }
    }
}

struct SevenSegmentDigit: View {
    let value: Int
    private let masks: [Set<Int>] = [
        [0,1,2,4,5,6], [2,5], [0,2,3,4,6], [0,2,3,5,6], [1,2,3,5],
        [0,1,3,5,6], [0,1,3,4,5,6], [0,2,5], [0,1,2,3,4,5,6], [0,1,2,3,5,6]
    ]
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let t = max(1.5, w * 0.16)
            ZStack {
                segment(0).frame(width: w - t, height: t).position(x: w/2, y: t/2)
                segment(3).frame(width: w - t, height: t).position(x: w/2, y: h/2)
                segment(6).frame(width: w - t, height: t).position(x: w/2, y: h-t/2)
                segment(1).frame(width: t, height: h/2 - t).position(x: t/2, y: h/4)
                segment(2).frame(width: t, height: h/2 - t).position(x: w-t/2, y: h/4)
                segment(4).frame(width: t, height: h/2 - t).position(x: t/2, y: h*0.75)
                segment(5).frame(width: t, height: h/2 - t).position(x: w-t/2, y: h*0.75)
            }
        }
    }
    private func segment(_ index: Int) -> some View {
        Capsule().fill(TimerTheme.lcdInk.opacity(masks[value].contains(index) ? 1 : 0.07))
    }
}
