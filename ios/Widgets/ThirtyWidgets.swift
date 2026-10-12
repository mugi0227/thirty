import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ThirtyWidgets: WidgetBundle {
    var body: some Widget {
        StartWidget()
        TimerLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            StartControl()
        }
    }
}

// MARK: Start widget (Home Screen and Lock Screen)

struct StartEntry: TimelineEntry {
    let date: Date
}

struct StartProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartEntry { StartEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (StartEntry) -> Void) { completion(StartEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StartEntry>) -> Void) {
        completion(Timeline(entries: [StartEntry(date: .now)], policy: .never))
    }
}

/// One tap from the Home or Lock Screen starts 30 minutes.
struct StartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "jp.mugilab.thirty.start", provider: StartProvider()) { _ in
            StartWidgetView()
        }
        .configurationDisplayName("30分スタート")
        .description("タップするとすぐに30分を始めます。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct StartWidgetView: View {
    @Environment(\.widgetFamily) private var family
    private let palette = LCDPalette.colors(for: "classic")

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Text("30").font(.system(size: 20, weight: .semibold, design: .rounded))
                        Image(systemName: "play.fill").font(.system(size: 9))
                    }
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill").font(.title2)
                    VStack(alignment: .leading) {
                        Text("30分スタート").font(.headline)
                        Text("Thirty").font(.caption)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    SlatsShape(count: 12).fill(palette.ink).frame(maxHeight: .infinity)
                    Rectangle().fill(palette.ink.opacity(0.16)).frame(height: 1)
                    HStack(alignment: .lastTextBaseline) {
                        Text("30:00").font(.system(size: 26, weight: .light, design: .monospaced))
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(palette.ink)
            }
        }
        .containerBackground(for: .widget) { palette.lcd }
        .widgetURL(ThirtyLink.start(minutes: 30))
    }
}

// MARK: Control Center (iOS 18)

@available(iOSApplicationExtension 18.0, *)
struct StartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "jp.mugilab.thirty.control.start") {
            ControlWidgetButton(action: StartTimerIntent(minutes: 30)) {
                Label("30分スタート", systemImage: "timer")
            }
        }
        .displayName("30分スタート")
        .description("Thirtyを開いて、すぐに30分を始めます。")
    }
}

// MARK: Live Activity (Thirty+)

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenTimer(context: context)
                .activityBackgroundTint(LCDPalette.colors(for: context.attributes.skinID).lcd)
                .activitySystemActionForegroundColor(LCDPalette.colors(for: context.attributes.skinID).ink)
        } dynamicIsland: { context in
            let ink = LCDPalette.colors(for: context.attributes.skinID).ink
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        ActivitySlats(state: context.state, slats: context.attributes.slats, ink: ink, gap: .black, rows: 10)
                            .frame(height: 40)
                        ActivityTime(state: context.state).font(.system(size: 30, weight: .light, design: .monospaced))
                            .foregroundStyle(ink)
                            .frame(width: 110, alignment: .trailing)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "timer").foregroundStyle(ink)
            } compactTrailing: {
                ActivityTime(state: context.state).font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(ink)
            }
            .keylineTint(ink)
        }
    }
}

/// Lock Screen and StandBy: the same bars-and-digits layout as the app.
struct LockScreenTimer: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        let colors = LCDPalette.colors(for: context.attributes.skinID)
        HStack(spacing: 16) {
            ActivitySlats(state: context.state, slats: context.attributes.slats, ink: colors.ink, gap: colors.lcd)
            Rectangle().fill(colors.ink.opacity(0.16)).frame(width: 1.5)
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.isBreak {
                    Text("休憩").font(.caption.weight(.semibold))
                } else if context.state.deadline == nil {
                    Text("一時停止").font(.caption.weight(.semibold))
                }
                ActivityTime(state: context.state).font(.system(size: 36, weight: .light, design: .monospaced))
            }
            .frame(width: 130, alignment: .trailing)
        }
        .foregroundStyle(colors.ink)
        .padding(16)
        .frame(height: 110)
    }
}

/// While running the system animates a countdown ProgressView; slats are
/// drawn by cutting gaps over it in the background colour.
struct ActivitySlats: View {
    let state: TimerActivityAttributes.ContentState
    let slats: Int
    let ink: Color
    let gap: Color
    var rows = 16

    var body: some View {
        ZStack {
            Rectangle().fill(ink.opacity(0.12))
            if let deadline = state.deadline {
                // A linear ProgressView is the only bar the system animates without
                // updates, and it is thin, so several are stacked into one block.
                let start = deadline.addingTimeInterval(-state.total)
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { _ in
                        ProgressView(timerInterval: start...deadline, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .progressViewStyle(.linear)
                            .tint(ink)
                            .frame(maxHeight: .infinity)
                    }
                }
            } else {
                GeometryReader { geometry in
                    let fraction = state.total > 0 ? max(0, min(1, state.remaining / state.total)) : 0
                    Rectangle().fill(ink).frame(width: geometry.size.width * fraction)
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<slats, id: \.self) { _ in
                    Color.clear.overlay(alignment: .trailing) { Rectangle().fill(gap).frame(width: slats > 30 ? 1 : 2) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct ActivityTime: View {
    let state: TimerActivityAttributes.ContentState
    var body: some View {
        if let deadline = state.deadline {
            Text(timerInterval: Date.now...deadline, countsDown: true)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        } else {
            let seconds = Int(ceil(state.remaining))
            Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
        }
    }
}

/// Evenly spaced horizontal slats for the small widget.
struct SlatsShape: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pitch = rect.height / CGFloat(count)
        for index in 0..<count {
            path.addRect(CGRect(x: rect.minX, y: rect.minY + CGFloat(index) * pitch, width: rect.width, height: pitch * 0.62))
        }
        return path
    }
}
