import SwiftUI

struct EndSoundPicker: View {
    @Binding var selection: EndSound
    @ObservedObject var store: Store
    @ObservedObject var effects: TimerEffects
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlus = false

    private var effectiveSelection: EndSound { store.hasPlus ? selection : .chime }

    var body: some View {
        List {
            Section {
                ForEach(EndSound.allCases) { sound in
                    HStack(spacing: 16) {
                        Button {
                            effects.stopPreview()
                            if sound.isFree || store.hasPlus { selection = sound }
                            else { showPlus = true }
                        } label: {
                            HStack(spacing: 10) {
                                Text(sound.title).foregroundStyle(.primary)
                                if !sound.isFree && !store.hasPlus {
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if effectiveSelection == sound {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold))
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("end-sound-select-" + sound.rawValue)
                        .accessibilityAddTraits(effectiveSelection == sound ? .isSelected : [])

                        Button { effects.preview(sound) } label: {
                            Image(systemName: effects.previewedSound == sound ? "stop.circle.fill" : "play.circle")
                                .font(.title2)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(effects.isPlayingAlarm)
                        .accessibilityLabel(effects.previewedSound == sound
                            ? String(localized: "プレビューを停止")
                            : sound == .vibrate ? String(localized: "振動を試す") : String(localized: "試聴"))
                        .accessibilityValue(sound.title)
                        .accessibilityIdentifier("end-sound-preview-" + sound.rawValue)
                    }
                }
            } footer: {
                Text(String(localized: "再生ボタンで、購入前にも音や振動を試せます。"))
            }
        }
        .navigationTitle(String(localized: "終了音"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlus) { PlusView(store: store) }
        .onDisappear { effects.stopPreview() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { effects.stopPreview() }
        }
    }
}
