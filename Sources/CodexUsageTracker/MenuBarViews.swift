import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot?

    var body: some View {
        Label {
            Text(menuTitle)
                .font(.caption.monospacedDigit())
        } icon: {
            Image(systemName: "chart.bar.xaxis")
        }
    }

    private var menuTitle: String {
        guard let snapshot else { return "Codex" }
        return Formatters.compactTokenCount(snapshot.month.totalTokens)
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var pricingStore: PricingStore
    @Environment(\.openSettings) private var openSettings

    init(store: UsageStore) {
        self.store = store
        _pricingStore = ObservedObject(wrappedValue: store.pricingStore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = store.snapshot {
                Text("This Month")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(Formatters.compactTokenCount(snapshot.month.totalTokens))
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                Text(Formatters.currency(snapshot.monthCost(using: pricingStore)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }

            Divider()

            Button("Open Dashboard") {
                openDashboard()
            }

            Button("Refresh Now") {
                store.refreshNow()
            }

            Button("Open Pricing Settings") {
                openSettings()
            }

            Text("Auto-refresh every \(Int(store.refreshInterval))s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
