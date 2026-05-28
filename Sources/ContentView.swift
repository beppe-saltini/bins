import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("uprn", store: sharedDefaults) private var uprn: String?
    @AppStorage("postcode", store: sharedDefaults) private var postcode: String?
    @AppStorage("addressText", store: sharedDefaults) private var addressText: String?

    @State private var result: BinResult?
    @State private var showSettings = false

    var body: some View {
        Group {
            if uprn == nil || showSettings {
                SettingsView(showSettings: $showSettings)
            } else if let result {
                binView(result)
            } else {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView().scaleEffect(2)
                }
            }
        }
        .task(id: uprn) {
            await refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refresh() }
            }
        }
    }

    private func refresh() async {
        guard let pc = postcode, let _ = uprn, let at = addressText else { return }
        let uprn = self.uprn!
        if result == nil {
            result = BinService.guessFromReference()
        }
        let r = await BinService.getCurrentBin(postcode: pc, uprn: uprn, addressText: at)
        result = r
        // App icon (green/black) updates every time you open the app.
        BinService.updateIcon(type: r.collection.type)
        WidgetCenter.shared.reloadAllTimelines()
        await ReminderScheduler.rescheduleFromStoredAddress()
    }

    // MARK: - UI

    @ViewBuilder
    private func binView(_ result: BinResult) -> some View {
        let isGreen = result.collection.type == .green

        ZStack {
            (isGreen ? Color.green : Color.black)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 140))
                        .foregroundStyle(.white)

                    if result.isGuess {
                        Text("*")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .offset(x: 15, y: -15)
                    }
                }

                Text(isGreen ? "Recycling" : "Refuse")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text(result.collection.date.formatted(date: .complete, time: .omitted))
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))

                if result.isGuess {
                    Label("Estimated (offline)", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding()
            }
        }
    }
}
