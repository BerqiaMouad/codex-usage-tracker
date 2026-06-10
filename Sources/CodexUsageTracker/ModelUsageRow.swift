import SwiftUI

struct ModelUsageRow: View {
    let modelName: String
    let usage: UsageSlice
    let cost: Double

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modelName)
                    .font(.headline)
                Text("\(Formatters.fullTokenCount(usage.inputTokens)) input · \(Formatters.fullTokenCount(usage.cachedInputTokens)) cached · \(Formatters.fullTokenCount(usage.outputTokens)) output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.compactTokenCount(usage.totalTokens))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(Formatters.currency(cost))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
