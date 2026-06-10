import SwiftUI

struct ThreadRow: View {
    let thread: ThreadUsage
    let usage: UsageSlice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(thread.model) · updated \(Formatters.relativeDate(thread.updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatters.compactTokenCount(usage.totalTokens))
                        .font(.headline.monospacedDigit())
                    Text(Formatters.absoluteDate(thread.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                tag("Input", Formatters.compactTokenCount(usage.inputTokens))
                tag("Cached", Formatters.compactTokenCount(usage.cachedInputTokens))
                tag("Output", Formatters.compactTokenCount(usage.outputTokens))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tag(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
    }
}
