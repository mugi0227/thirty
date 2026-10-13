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
                        Text(String(localized: "30分スタート")).font(.headline)
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
                Label(String(localized: "30分スタート"), systemImage: "timer")
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
                        ActivitySlats(state: context.state, ink: ink).frame(height: 44)
                        ActivityTime(state: context.state).font(.system(size: 30, weight: .light, design: .monospaced))
                            .foregroundStyle(ink)
                            .frame(width: 104, alignment: .trailing)
                    }
                    .padding(.horizontal, 8).padding(.bottom, 4)
                }
            } compactLeading: {
                // A small bar timer: six slats of five minutes each.
                ActivitySlats(state: context.state, ink: ink, count: 6, gap: 2).frame(width: 30, height: 16)
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
        HStack(spacing: 14) {
            ActivitySlats(state: context.state, ink: colors.ink)
            Rectangle().fill(colors.ink.opacity(0.16)).frame(width: 1.5)
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.isBreak {
                    Text(String(localized: "休憩")).font(.caption.weight(.semibold))
                } else if context.state.deadline == nil {
                    Text(String(localized: "一時停止中")).font(.caption.weight(.semibold))
                }
                ActivityTime(state: context.state).font(.system(size: 36, weight: .light, design: .monospaced))
            }
            .frame(width: 124, alignment: .trailing)
        }
        .foregroundStyle(colors.ink)
        .padding(16)
        .frame(height: 104)
    }
}

/// Thirty slats that empty on their own, right to left, with no updates.
///
/// Each slat is a system timer ProgressView covering one thirtieth of the
/// session, turned upright. Before its turn it reads full, during its turn
/// it drains from the top, and afterwards it stays empty, so together they
/// behave like the app's bar while the app is suspended.
struct ActivitySlats: View {
    let state: TimerActivityAttributes.ContentState
    let ink: Color
    var count = 30
    var gap: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, (geometry.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            let height = geometry.size.height
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { index in
                    slat(index, length: height)
                        .frame(width: width, height: height)
                }
            }
        }
    }

    @ViewBuilder
    private func slat(_ index: Int, length: CGFloat) -> some View {
        let share = state.total / Double(count)
        if let deadline = state.deadline, share > 0 {
            // Slat `index` (from the left) is lit while more than index × share remains.
            let end = deadline.addingTimeInterval(-Double(index) * share)
            ProgressView(timerInterval: end.addingTimeInterval(-share)...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(ink)
            .frame(width: length)
            .rotationEffect(.degrees(-90))
        } else {
            let lit = state.total > 0 ? Int(ceil(state.remaining / state.total * Double(count))) : 0
            RoundedRectangle(cornerRadius: 1).fill(index < lit ? ink : ink.opacity(0.15))
        }
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
