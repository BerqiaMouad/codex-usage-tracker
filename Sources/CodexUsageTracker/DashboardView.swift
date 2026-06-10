import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var pricingStore: PricingStore

    init(store: UsageStore) {
        self.store = store
        _pricingStore = ObservedObject(wrappedValue: store.pricingStore)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let snapshot = store.snapshot {
                        summaryGrid(snapshot: snapshot)
                        scopeSection(snapshot: snapshot)
                        modelSection(snapshot: snapshot)
                        threadSection(snapshot: snapshot)
                    } else if store.isRefreshing {
                        loadingView
                    } else {
                        emptyView
                    }
                }
                .padding(24)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Codex Usage Tracker")
            .toolbar {
                ToolbarItemGroup {
                    Picker("Scope", selection: $store.selectedScope) {
                        ForEach(UsageScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Button {
                        store.refreshNow()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Native live view over your local authenticated Codex usage.")
                .font(.title2.weight(.semibold))
            Text(PricingConfiguration.pricingDisclaimer)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private func summaryGrid(snapshot: UsageSnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                SummaryCard(title: "All-Time Usage", usage: snapshot.allTime, cost: snapshot.cost(for: .allTime, using: pricingStore), accent: .blue)
                SummaryCard(title: "This Month", usage: snapshot.month, cost: snapshot.cost(for: .month, using: pricingStore), accent: .green)
                SummaryCard(title: "Today", usage: snapshot.today, cost: snapshot.cost(for: .today, using: pricingStore), accent: .orange)
            }
            GridRow {
                MetaCard(title: "Tracked Threads", value: "\(snapshot.threadCount)", detail: "\(snapshot.threadsWithDetailedBreakdown) with full token breakdown")
                MetaCard(title: "Last Refresh", value: Formatters.absoluteDate(snapshot.generatedAt), detail: snapshot.codexHome)
                MetaCard(title: "Pricing Baseline", value: PricingConfiguration.sourceLabel, detail: PricingConfiguration.sourceURL.absoluteString)
            }
        }
    }

    private func scopeSection(snapshot: UsageSnapshot) -> some View {
        let usage = snapshot.usage(for: store.selectedScope)

        return VStack(alignment: .leading, spacing: 12) {
            Text("\(store.selectedScope.rawValue) Breakdown")
                .font(.title3.weight(.semibold))
            HStack(spacing: 16) {
                BreakdownStrip(label: "Total", value: Formatters.fullTokenCount(usage.totalTokens))
                BreakdownStrip(label: "Input", value: Formatters.fullTokenCount(usage.inputTokens))
                BreakdownStrip(label: "Cached", value: Formatters.fullTokenCount(usage.cachedInputTokens))
                BreakdownStrip(label: "Output", value: Formatters.fullTokenCount(usage.outputTokens))
                BreakdownStrip(label: "Reasoning", value: Formatters.fullTokenCount(usage.reasoningOutputTokens))
                BreakdownStrip(label: "Est. Cost", value: Formatters.currency(snapshot.cost(for: store.selectedScope, using: pricingStore)))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func modelSection(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Breakdown")
                .font(.title3.weight(.semibold))

            VStack(spacing: 10) {
                ForEach(snapshot.modelUsage) { model in
                    let usage = model.usage(for: store.selectedScope)
                    ModelUsageRow(
                        modelName: model.modelName,
                        usage: usage,
                        cost: usage.estimatedCost(using: pricingStore.rates(for: model.modelName))
                    )
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func threadSection(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Threads")
                .font(.title3.weight(.semibold))
            VStack(spacing: 12) {
                ForEach(snapshot.recentThreads) { thread in
                    ThreadRow(thread: thread, usage: usageForScope(thread, scope: store.selectedScope))
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var loadingView: some View {
        LoadingStatusView(message: "Scanning local Codex data")
            .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No usage loaded yet.")
                .font(.title3.weight(.semibold))
            Text("Press Refresh to scan `~/.codex` and populate the dashboard.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
    }

    private func usageForScope(_ thread: ThreadUsage, scope: UsageScope) -> UsageSlice {
        switch scope {
        case .allTime:
            thread.allTime
        case .month:
            thread.month
        case .today:
            thread.today
        }
    }
}

struct LoadingStatusView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 72, height: 72)

                if let appIcon = AppResources.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView()
                    .controlSize(.small)
                    .frame(width: 72, height: 72, alignment: .bottomTrailing)
            }

            VStack(spacing: 4) {
                Text(message)
                    .font(.headline)
                Text("Reading local session history and pricing totals.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Reading local session history and pricing totals.")
    }
}

private struct BreakdownStrip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetaCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
