import SwiftUI

struct SummaryCard: View {
    let title: String
    let usage: UsageSlice
    let cost: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(accent.gradient)
                    .frame(width: 10, height: 10)
            }

            Text(Formatters.compactTokenCount(usage.totalTokens))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("Estimated cost \(Formatters.currency(cost))")
                .font(.subheadline.weight(.medium))

            Divider()

            HStack {
                metric(label: "Fresh", value: Formatters.compactTokenCount(usage.nonCachedTokens))
                metric(label: "Cached", value: Formatters.compactTokenCount(usage.cachedInputTokens))
                metric(label: "Output", value: Formatters.compactTokenCount(usage.outputTokens))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.20), Color(nsColor: .windowBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.2))
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
