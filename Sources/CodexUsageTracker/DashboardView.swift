import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var pricingStore: PricingStore

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16, alignment: .top)
    ]
    private let metricColumns = [
        GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)
    ]
    private let supportColumns = [
        GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .top)
    ]

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
                        selectedRangeSection(snapshot: snapshot)
                        supportSection(snapshot: snapshot)
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
            .navigationTitle("Codex Usage Tracker")
            .toolbar {
                ToolbarItemGroup {
                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }

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
        LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
            SummaryCard(title: "All-Time Usage", usage: snapshot.allTime, cost: snapshot.cost(for: .allTime, using: pricingStore), accent: .blue)
            SummaryCard(title: "This Month", usage: snapshot.thisMonth, cost: snapshot.cost(for: .thisMonth, using: pricingStore), accent: .green)
            SummaryCard(title: "Today", usage: snapshot.today, cost: snapshot.cost(for: .today, using: pricingStore), accent: .orange)
        }
    }

    private func selectedRangeSection(snapshot: UsageSnapshot) -> some View {
        let usage = snapshot.selectedRange
        let cost = snapshot.selectedRangeCost(using: pricingStore)

        return VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    rangeControls(snapshot: snapshot)
                    selectedRangeSummary(usage: usage, cost: cost)
                }

                VStack(alignment: .leading, spacing: 20) {
                    rangeControls(snapshot: snapshot)
                    selectedRangeSummary(usage: usage, cost: cost)
                }
            }

            Divider()

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                BreakdownTile(label: "Total", value: Formatters.fullTokenCount(usage.totalTokens))
                BreakdownTile(label: "Input", value: Formatters.fullTokenCount(usage.inputTokens))
                BreakdownTile(label: "Cached", value: Formatters.fullTokenCount(usage.cachedInputTokens))
                BreakdownTile(label: "Output", value: Formatters.fullTokenCount(usage.outputTokens))
                BreakdownTile(label: "Reasoning", value: Formatters.fullTokenCount(usage.reasoningOutputTokens))
                BreakdownTile(label: "Est. Cost", value: Formatters.currency(cost))
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func rangeControls(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Date Range")
                .font(.title3.weight(.semibold))

            Picker("Date Filter", selection: $store.selectedFilter) {
                ForEach(UsageDateFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.large)

            if store.selectedFilter == .custom {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        dateField(title: "From", selection: $store.customStartDate)
                        dateField(title: "To", selection: $store.customEndDate)
                    }

                    VStack(spacing: 12) {
                        dateField(title: "From", selection: $store.customStartDate)
                        dateField(title: "To", selection: $store.customEndDate)
                    }
                }
            }

            Label(snapshot.selectedRangeLabel, systemImage: "calendar")
                .font(.callout.weight(.medium))

            if snapshot.selectedRangeExcludedThreads > 0 {
                Label(
                    "\(snapshot.selectedRangeExcludedThreads) older threads were excluded because no pre-range checkpoint was available.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedRangeSummary(usage: UsageSlice, cost: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Range")
                .font(.headline)

            Text(Formatters.compactTokenCount(usage.totalTokens))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("Estimated cost \(Formatters.currency(cost))")
                .font(.subheadline.weight(.medium))

            Divider()

            HStack(spacing: 18) {
                compactMetric(label: "Fresh", value: Formatters.compactTokenCount(usage.nonCachedTokens))
                compactMetric(label: "Cached", value: Formatters.compactTokenCount(usage.cachedInputTokens))
                compactMetric(label: "Output", value: Formatters.compactTokenCount(usage.outputTokens))
            }
        }
        .padding(18)
        .frame(maxWidth: 280, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func supportSection(snapshot: UsageSnapshot) -> some View {
        LazyVGrid(columns: supportColumns, alignment: .leading, spacing: 16) {
            SupportMetric(title: "Tracked Threads", value: "\(snapshot.threadCount)", detail: "\(snapshot.threadsWithDetailedBreakdown) with full token breakdown")
            SupportMetric(title: "Last Refresh", value: Formatters.absoluteDate(snapshot.generatedAt), detail: snapshot.codexHome)
            SupportMetric(title: "Pricing Baseline", value: PricingConfiguration.sourceLabel, detail: PricingConfiguration.sourceURL.absoluteString)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dateField(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            DatePicker("", selection: selection, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func compactMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modelSection(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Breakdown")
                .font(.title3.weight(.semibold))

            VStack(spacing: 10) {
                ForEach(snapshot.modelUsage) { model in
                    ModelUsageRow(
                        modelName: model.modelName,
                        usage: model.selectedRange,
                        cost: model.selectedRange.estimatedCost(using: pricingStore.rates(for: model.modelName))
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
                    ThreadRow(
                        thread: thread,
                        usage: thread.selectedRange,
                        cost: thread.selectedRange.estimatedCost(using: pricingStore.rates(for: thread.model))
                    )
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
}

private struct BreakdownTile: View {
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
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SupportMetric: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
