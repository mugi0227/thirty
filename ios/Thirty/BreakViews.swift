import SwiftUI

/// Dot-matrix pictures drawn on the same LCD as the slats and digits.
/// Unlit dots stay faintly visible, like the unlit segments.
struct PixelGrid: View {
    @Environment(\.skin) private var skin
    let cells: [[Bool]]
    /// Outside the LCD, such as in a system sheet, pass the text colour.
    var color: Color?
    var showsGhost = true
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
            let ink = color ?? skin.ink
            if showsGhost { context.fill(unlit, with: .color(ink.opacity(0.075))) }
            context.fill(lit, with: .color(ink))
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
        TimelineView(.periodic(from: .now, by: 0.8)) { context in
            let frame = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate / 0.8) % 2
            PixelGrid(cells: Self.cells(level: level, frame: frame))
        }
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

/// The small cup on the break button.
struct CoffeeIcon: View {
    var color: Color?
    private static let art = [
        "..#..#....",
        ".#..#.....",
        "..........",
        "#########.",
        "########.#",
        "########.#",
        "#########.",
        ".######...",
    ]
    var body: some View {
        PixelGrid(cells: Self.art.map { $0.map { $0 == "#" } }, color: color, showsGhost: false, gap: 0)
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
    static let choices = [0, 5, 10, 15, 20, 30]

    var body: some View {
        if locked {
            Button(action: onLocked) { label }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(String(localized: "休憩"))
                .accessibilityIdentifier("break-button")
        } else {
            // A tap steps through the usual lengths; a long press lists them all.
            Menu {
                Picker(String(localized: "休憩"), selection: Binding(get: { minutes }, set: onChange)) {
                    ForEach(Self.choices, id: \.self) { choice in
                        Text(choice == 0 ? String(localized: "休憩なし") : String(localized: "休憩 \(choice)分")).tag(choice)
                    }
                }
            } label: {
                label
            } primaryAction: {
                onChange(Self.choices.first { $0 > minutes } ?? 0)
            }
            .accessibilityLabel(String(localized: "休憩"))
            .accessibilityValue(minutes == 0 ? String(localized: "休憩なし") : String(localized: "\(minutes)分"))
            .accessibilityIdentifier("break-button")
        }
    }

    private var label: some View {
        VStack(spacing: 2) {
            CoffeeIcon().frame(width: 22, height: 18)
            Text(minutes > 0 && !locked ? "\(minutes)" : "–")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
        }
        .opacity(minutes > 0 && !locked ? 1 : 0.4)
        .modeButton(isOn: minutes > 0 && !locked, locked: locked, size: size, skin: skin)
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
