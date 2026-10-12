import AppIntents

/// "Press start before thinking": usable from Shortcuts, Siri, the Action
/// Button and the Control Center control. It opens Thirty and starts at once.
struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "タイマーをスタート"
    static var description = IntentDescription("Thirtyを開いて、すぐに計測を始めます。")
    static var openAppWhenRun = true

    @Parameter(title: "分", default: 30, inclusiveRange: (1, 999))
    var minutes: Int

    init() {}
    init(minutes: Int) { self.minutes = minutes }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        TimerModel.shared.startNow(minutes: minutes)
        #endif
        return .result()
    }
}

#if !WIDGET_EXTENSION
struct ThirtyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(),
                    phrases: ["\(.applicationName)をスタート", "\(.applicationName)で30分", "Start \(.applicationName)"],
                    shortTitle: "30分スタート",
                    systemImageName: "timer")
    }
}
#endif
