import SwiftUI

/// One-time walkthrough for adding the Bins widget to the Home Screen.
struct WidgetTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    /// The user's real next collection, used so the preview matches what they will see.
    var sample: BinCollection?
    var onFinish: () -> Void

    @State private var page = 0

    private let pageCount = 4
    private var isLastPage: Bool { page == pageCount - 1 }

    private var previewCollection: BinCollection {
        sample ?? BinCollection(
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            type: .green
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLastPage {
                    Button("Skip") { finish() }
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(height: 44)

            TabView(selection: $page) {
                TutorialPage(
                    step: 1,
                    title: "Touch and hold",
                    message: "Press and hold any empty space on your Home Screen until the apps start to wiggle.",
                    illustration: { HomeScreenMock(stage: .holding, collection: previewCollection) }
                ).tag(0)

                TutorialPage(
                    step: 2,
                    title: "Open the widget gallery",
                    message: "Tap **Edit** in the top-left corner, then **Add Widget**. On iOS 17, tap the **+** button instead.",
                    illustration: { HomeScreenMock(stage: .editMenu, collection: previewCollection) }
                ).tag(1)

                TutorialPage(
                    step: 3,
                    title: "Find Bins and add it",
                    message: "Search for **Bins**, then tap **Add Widget**. Drop it anywhere you like.",
                    illustration: { WidgetGalleryMock(collection: previewCollection) }
                ).tag(2)

                TutorialPage(
                    step: nil,
                    title: "You’re all set",
                    message: "The widget shows your next collection and updates on its own — green for recycling, black for refuse.",
                    illustration: { HomeScreenMock(stage: .done, collection: previewCollection) }
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            PageDots(count: pageCount, current: page)
                .padding(.bottom, 20)

            Button {
                if isLastPage {
                    finish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLastPage ? "Done" : "Next")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

// MARK: - Page layout

private struct TutorialPage<Illustration: View>: View {
    let step: Int?
    let title: String
    let message: LocalizedStringKey
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            illustration()
                .frame(height: 340)
                .padding(.horizontal, 24)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                if let step {
                    Text("STEP \(step) OF 3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.green)
                        .tracking(1.2)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.green)
                }

                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
    }
}

// MARK: - Widget preview (mirrors BinsWidgetView)

struct WidgetPreviewTile: View {
    let collection: BinCollection
    var size: CGFloat = 150

    var body: some View {
        let isGreen = collection.type == .green
        let scale = size / 150

        VStack(spacing: 6 * scale) {
            Image(systemName: "trash.fill")
                .font(.system(size: 50 * scale))
                .foregroundStyle(.white)
            Text(isGreen ? "Recycling" : "Refuse")
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(.white)
            Text(collection.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.system(size: 11 * scale))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: size, height: size)
        .background(isGreen ? Color.green : Color.black, in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12 * scale, y: 6 * scale)
    }
}

// MARK: - Home Screen mock

private struct HomeScreenMock: View {
    enum Stage { case holding, editMenu, done }

    let stage: Stage
    let collection: BinCollection

    @State private var jiggle = false
    @State private var pulse = false

    private let iconColors: [Color] = [
        .blue, .orange, .pink, .purple,
        .teal, .indigo, .yellow, .mint,
        .red, .cyan, .brown, .gray,
    ]

    var body: some View {
        PhoneFrame {
            ZStack(alignment: .top) {
                // Status bar + optional Edit control
                HStack {
                    if stage == .editMenu {
                        Text("Edit")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.green, lineWidth: 2))
                            .overlay(PulseRing(active: pulse, shape: Capsule()))
                    } else if stage == .holding {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(.ultraThinMaterial, in: Circle())
                            .opacity(0)
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                if stage == .done {
                    VStack(spacing: 18) {
                        WidgetPreviewTile(collection: collection, size: 118)
                        appGrid(rows: 1, jiggling: false)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    appGrid(rows: 3, jiggling: true)
                        .padding(.top, 48)
                }

                if stage == .holding {
                    FingerTap()
                        .offset(x: 0, y: 232)
                }

                if stage == .editMenu {
                    EditMenuPopover()
                        .padding(.top, 44)
                        .padding(.leading, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            jiggle = true
            pulse = true
        }
    }

    @ViewBuilder
    private func appGrid(rows: Int, jiggling: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<(rows * 4), id: \.self) { index in
                AppIconMock(color: iconColors[index % iconColors.count], isBins: index == 5, showMinus: jiggling)
                    .rotationEffect(.degrees(jiggling ? (index.isMultiple(of: 2) ? (jiggle ? 2 : -2) : (jiggle ? -2 : 2)) : 0))
                    .animation(
                        jiggling ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true) : .default,
                        value: jiggle
                    )
            }
        }
        .padding(.horizontal, 18)
    }
}

private struct AppIconMock: View {
    let color: Color
    let isBins: Bool
    let showMinus: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isBins ? Color.green : color.opacity(0.85))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isBins {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            if showMinus {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 14, height: 14)
                    .background(Color(.systemGray5), in: Circle())
                    .offset(x: -4, y: -4)
            }
        }
    }
}

private struct EditMenuPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow("Customise", icon: "paintbrush")
            Divider()
            menuRow("Add Widget", icon: "plus.square.on.square", highlighted: true)
            Divider()
            menuRow("Edit Pages", icon: "square.grid.2x2")
        }
        .frame(width: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private func menuRow(_ title: String, icon: String, highlighted: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: highlighted ? .semibold : .regular))
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 11))
        }
        .foregroundStyle(highlighted ? Color.green : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(highlighted ? Color.green.opacity(0.12) : .clear)
    }
}

// MARK: - Widget gallery mock

private struct WidgetGalleryMock: View {
    let collection: BinCollection
    @State private var pulse = false

    var body: some View {
        PhoneFrame {
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Bins")
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 16)
                    Spacer()
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.top, 14)

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green)
                            .frame(width: 22, height: 22)
                            .overlay(Image(systemName: "trash.fill").font(.system(size: 11)).foregroundStyle(.white))
                        Text("Bins")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    WidgetPreviewTile(collection: collection, size: 110)

                    Text("Next collection at a glance")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("Add Widget")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Color.green, in: Capsule())
                        .overlay(PulseRing(active: pulse, shape: Capsule()))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 14)

                Spacer(minLength: 0)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Shared bits

private struct PhoneFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(width: 230, height: 330)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.32, blue: 0.42), Color(red: 0.07, green: 0.16, blue: 0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 6)
            )
            .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
            .frame(maxWidth: .infinity)
    }
}

private struct PulseRing<S: Shape>: View {
    let active: Bool
    let shape: S

    var body: some View {
        shape
            .stroke(Color.green, lineWidth: 2)
            .scaleEffect(active ? 1.5 : 1)
            .opacity(active ? 0 : 0.9)
            .animation(.easeOut(duration: 1.3).repeatForever(autoreverses: false), value: active)
    }
}

private struct FingerTap: View {
    @State private var pressed = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(pressed ? 1.4 : 1)
                .opacity(pressed ? 0 : 1)
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .scaleEffect(pressed ? 0.8 : 1)
        }
        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pressed)
        .onAppear { pressed = true }
    }
}

#Preview {
    WidgetTutorialView(sample: nil) {}
}
