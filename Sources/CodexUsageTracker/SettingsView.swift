import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var pricingStore: PricingStore

    init(store: UsageStore) {
        self.store = store
        _pricingStore = ObservedObject(wrappedValue: store.pricingStore)
    }

    var body: some View {
        Form {
            Section("Refresh") {
                HStack {
                    Text("Refresh interval")
                    Spacer()
                    Stepper(value: $store.refreshInterval, in: 2...60, step: 1) {
                        Text("\(Int(store.refreshInterval)) seconds")
                            .monospacedDigit()
                    }
                    .frame(width: 220)
                }
            }

            Section("Pricing") {
                Text(PricingConfiguration.pricingDisclaimer)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Link(PricingConfiguration.sourceLabel, destination: PricingConfiguration.sourceURL)

                VStack(spacing: 12) {
                    ForEach(modelNames, id: \.self) { modelName in
                        PricingEditorRow(
                            modelName: modelName,
                            rates: Binding(
                                get: { store.pricingStore.rates(for: modelName) ?? PricingRates(inputPerMillion: 0, cachedInputPerMillion: 0, outputPerMillion: 0) },
                                set: { store.pricingStore.setRates($0, for: modelName) }
                            )
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var modelNames: [String] {
        let snapshotModels = store.snapshot?.modelUsage.map(\.modelName) ?? []
        return Array(Set(snapshotModels).union(pricingStore.allRates.keys)).sorted()
    }
}

private struct PricingEditorRow: View {
    let modelName: String
    @Binding var rates: PricingRates

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text(modelName)
                    .font(.headline)
                rateField("Input", value: $rates.inputPerMillion)
                rateField("Cached", value: $rates.cachedInputPerMillion)
                rateField("Output", value: $rates.outputPerMillion)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rateField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(
                "$ / 1M",
                value: value,
                format: .number.precision(.fractionLength(0...3))
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
        }
    }
}
