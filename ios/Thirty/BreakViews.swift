import SwiftUI

/// Dot-matrix pictures drawn on the same LCD as the slats and digits.
/// Unlit dots stay faintly visible, like the unlit segments.
struct PixelGrid: View {
    @Environment(\.skin) private var skin
    let cells: [[Bool]]
    /// The gap between dots, as a share of one dot.
    var gap: CGFloat = 0.14

    var body: some View {
        let rows = cells.count, columns = cells.first?.count ?? 0
        Canvas { context, size in
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let origin = CGPoint(x: (size.width - cell * CGFloat(columns)) / 2,
                                 y: (size.height - cell * CGFloat(rows)) / 2)
            let inset = cell * gap / 2
            var lit = Path(), unlit = Path()
            for (row, line) in cells.enumerated() {
                for (column, on) in line.enumerated() {
                    let rect = CGRect(x: origin.x + CGFloat(column) * cell, y: origin.y + CGFloat(row) * cell,
                                      width: cell, height: cell).insetBy(dx: inset, dy: inset)
                    if on { lit.addRect(rect) } else { unlit.addRect(rect) }
                }
            }
            context.fill(unlit, with: .color(skin.ghost))
            context.fill(lit, with: .color(skin.ink))
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The break's picture where the slats usually are. The coffee goes down
/// as the break runs, so it still reads as a timer.
struct CoffeeCup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Coffee left, 0...levels.
    let level: Int
    /// Remaining seconds, so the steam sways on the same beat as the digits.
    let seconds: Int
    static let levels = 9

    // '#' is the cup, 'c' the coffee inside.
    private static let cup = [
        "..##############...",
        "..#cccccccccccc#...",
        "..#cccccccccccc####",
        "..#cccccccccccc#..#",
        "..#cccccccccccc#..#",
        "..#cccccccccccc#..#",
        "..#cccccccccccc####",
        "..#cccccccccccc#...",
        "...#cccccccccc#....",
        "....#cccccccc#.....",
        ".....########......",
        "...................",
        "##################.",
    ]
    private static let steamRows = 4

    var body: some View {
        PixelGrid(cells: Self.cells(level: level, frame: reduceMotion ? 0 : seconds % 2))
            .accessibilityHidden(true)
    }

    static func cells(level: Int, frame: Int) -> [[Bool]] {
        let width = cup[0].count
        // Three wisps that sway one dot side to side.
        var steam = (0..<steamRows).map { row in
            (0..<width).map { column in [5, 9, 13].contains { column == $0 - (row + frame) % 2 } }
        }
        steam.append(Array(repeating: false, count: width))
        let interiorRows = cup.filter { $0.contains("c") }.count
        var interior = 0
        let body = cup.map { line -> [Bool] in
            let isInterior = line.contains("c")
            defer { if isInterior { interior += 1 } }
            // Rows count up from the bottom of the coffee.
            let fromBottom = interiorRows - 1 - interior
            return line.map { $0 == "#" || ($0 == "c" && fromBottom < level) }
        }
        return steam + body
    }
}

/// "+10" or "−1" in the same segments as the time. At button size the unlit
/// segments only add noise, so they are left out.
struct SegmentText: View {
    @Environment(\.skin) private var skin
    let text: String
    var height: CGFloat = 18

    var body: some View {
        HStack(spacing: height * 0.14) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                glyph(character).fill(skin.ink)
                    .frame(width: height * 0.55, height: height)
                    // A one only lights its right edge; drop the empty left so "+1" sits together.
                    .frame(width: character == "1" ? height * 0.12 : height * 0.55, alignment: .trailing)
            }
        }
        .accessibilityHidden(true)
    }

    private func glyph(_ character: Character) -> AnyShape {
        switch character {
        case "+": return AnyShape(SegmentSign(parts: [.bar, .stem]))
        case "−", "-": return AnyShape(SegmentSign(parts: [.bar]))
        default: return AnyShape(SegmentDigit(segments: SegmentDigit.masks[character.wholeNumberValue ?? 0]))
        }
    }
}

/// Plus and minus on the digits' 22×40 grid: the middle bar and a split stem.
struct SegmentSign: Shape {
    enum Part { case bar, stem }
    let parts: Set<Part>

    func path(in rect: CGRect) -> Path {
        let outlines: [[(CGFloat, CGFloat)]] = (parts.contains(.bar) ? [[(3, 18), (15, 18), (17, 20), (15, 22), (3, 22), (1, 20)]] : [])
            + (parts.contains(.stem) ? [[(9, 8), (11, 10), (11, 16), (9, 18), (7, 16), (7, 10)],
                                         [(9, 22), (11, 24), (11, 30), (9, 32), (7, 30), (7, 24)]] : [])
        let scaleX = rect.width / 22, scaleY = rect.height / 40
        var path = Path()
        for outline in outlines {
            path.addLines(outline.map { CGPoint(x: rect.minX + ($0.0 + 2) * scaleX, y: rect.minY + $0.1 * scaleY) })
            path.closeSubpath()
        }
        return path
    }
}

/// Repeat on the left of play, break on the right, like a music player.
struct RepeatButton: View {
    @Environment(\.skin) private var skin
    let isOn: Bool
    let locked: Bool
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "repeat").font(.system(size: 19, weight: .semibold))
                .opacity(isOn ? 1 : 0.4)
                .modeButton(isOn: isOn, locked: locked, size: size, skin: skin)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(String(localized: "くり返し"))
        .accessibilityValue(isOn ? String(localized: "オン") : String(localized: "オフ"))
        .accessibilityIdentifier("repeat-button")
    }
}

struct BreakButton: View {
    @Environment(\.skin) private var skin
    /// 0 is no break.
    let minutes: Int
    let locked: Bool
    var size: CGFloat = 56
    let onLocked: () -> Void
    let onChange: (Int) -> Void
    @State private var showPicker = false
    var body: some View {
        Button {
            if locked { onLocked() } else { showPicker = true }
        } label: { label }
            .buttonStyle(SoftPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "休憩"))
            .accessibilityValue(minutes == 0 || locked ? String(localized: "休憩なし") : String(localized: "\(minutes)分"))
            .accessibilityHint(locked ? "" : String(localized: "休憩の長さを選ぶ"))
            .accessibilityAction(named: String(localized: "休憩の長さを選ぶ")) { if locked { onLocked() } else { showPicker = true } }
            .accessibilityIdentifier("break-button")
            .sheet(isPresented: $showPicker) {
                BreakPicker(minutes: minutes, onChange: onChange)
            }
    }

    private var on: Bool { minutes > 0 && !locked }

    private var label: some View {
        VStack(spacing: 1) {
            Image(systemName: on ? "cup.and.saucer.fill" : "cup.and.saucer").font(.system(size: 17, weight: .semibold))
            Text(on ? "\(minutes)" : "–").font(.system(size: 11, weight: .bold).monospacedDigit())
        }
        .opacity(on ? 1 : 0.4)
        .modeButton(isOn: on, locked: locked, size: size, skin: skin)
    }
}

/// Any break from none to an hour, a minute at a time.
struct BreakPicker: View {
    @State var minutes: Int
    let onChange: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    private let choices = [0, 5, 10, 15, 20, 30]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(choices, id: \.self) { choice in
                            Button { minutes = choice } label: {
                                Text(choice == 0 ? String(localized: "休憩なし") : String(localized: "\(choice)分"))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(minutes == choice ? Color.accentColor.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                Picker(String(localized: "休憩"), selection: $minutes) {
                    Text(String(localized: "休憩なし")).tag(0)
                    ForEach(1...60, id: \.self) { Text(String(localized: "\($0)分")).tag($0) }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("break-duration-picker")
                .padding(.horizontal, 24)
            }
            .navigationTitle(String(localized: "休憩")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(String(localized: "キャンセル"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onChange(minutes); dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel(String(localized: "決定"))
                        .accessibilityIdentifier("confirm-break-duration")
                }
            }
        }
        .presentationDetents([.height(390)])
    }
}

private extension View {
    /// Off is an outline, on is filled; a padlock marks Thirty+.
    func modeButton(isOn: Bool, locked: Bool, size: CGFloat, skin: Skin) -> some View {
        frame(width: size, height: size)
            .background(isOn ? skin.soft : .clear, in: Circle())
            .overlay(Circle().stroke(isOn ? .clear : skin.line, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                        .padding(4).background(skin.lcd, in: Circle())
                }
            }
            .contentShape(Circle())
    }
}
