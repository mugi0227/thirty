import SwiftUI

/// Skins can be tried on before buying: tapping a locked one previews it here.
struct SkinPicker: View {
    @ObservedObject var store: Store
    @Binding var selectedID: String
    @Environment(\.dismiss) private var dismiss
    @State private var previewID: String

    init(store: Store, selectedID: Binding<String>) {
        self.store = store
        _selectedID = selectedID
        _previewID = State(initialValue: selectedID.wrappedValue)
    }

    private var preview: Skin { Skin.all.first { $0.id == previewID } ?? .classic }
    private var previewLocked: Bool { !preview.isFree && !store.hasPlus }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SkinSample(skin: preview, lit: 9, slats: 14)
                        .frame(height: 230).frame(maxWidth: 420)
                        .overlay(alignment: .topTrailing) {
                            if previewLocked {
                                Label("試着中", systemImage: "eye").font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule()).padding(12)
                            }
                        }
                    VStack(spacing: 4) {
                        Text(preview.name).font(.headline)
                        Text(preview.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                        ForEach(Skin.all) { skin in tile(skin) }
                    }
                    if store.hasPlus {
                        Label("Thirty+ をご利用いただき、ありがとうございます。", systemImage: "heart.fill")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                    } else {
                        plusCard
                    }
                }
                .padding(20)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("スキン").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("閉じる")
                }
            }
        }
    }

    private func tile(_ skin: Skin) -> some View {
        let locked = !skin.isFree && !store.hasPlus
        return Button {
            previewID = skin.id
            if !locked { selectedID = skin.id }
        } label: {
            VStack(spacing: 6) {
                SkinSample(skin: skin, lit: 5, slats: 7, compact: true)
                    .frame(height: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: previewID == skin.id ? 3 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(skin.ink).padding(8)
                        } else if selectedID == skin.id {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                .foregroundStyle(skin.ink).padding(6)
                        }
                    }
                Text(skin.name).font(.caption.weight(.semibold)).foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(skin.name)
        .accessibilityValue(selectedID == skin.id ? "使用中" : locked ? "Thirty+ で使えます" : "")
    }

    private var plusCard: some View {
        VStack(spacing: 12) {
            Text("Thirty+").font(.title3.weight(.bold))
            Text("すべてのスキンのほか、ロック画面での表示や終了音も選べます。")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            PlusBuyButtons(store: store) { selectedID = previewID }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// A small LCD in the given skin: stacked slats over the digits.
struct SkinSample: View {
    let skin: Skin
    let lit: Int
    let slats: Int
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 5 : 10) {
            VStack(spacing: compact ? 2 : 4) {
                ForEach(0..<slats, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1).fill(slats - 1 - index < lit ? skin.ink : skin.ghost)
                }
            }
            Rectangle().fill(skin.line).frame(height: compact ? 1 : 1.5)
            SevenSegmentTime(text: "30:00").frame(height: compact ? 18 : 48)
        }
        .padding(compact ? 10 : 22)
        .background(skin.lcd, in: RoundedRectangle(cornerRadius: compact ? 14 : 28, style: .continuous))
        .environment(\.skin, skin)
        .accessibilityHidden(true)
    }
}
