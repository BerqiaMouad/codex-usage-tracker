import Foundation

struct PricingRates: Codable, Equatable, Sendable {
    var inputPerMillion: Double
    var cachedInputPerMillion: Double
    var outputPerMillion: Double

    func estimatedCost(inputTokens: Int, cachedInputTokens: Int, outputTokens: Int) -> Double {
        (Double(inputTokens) / 1_000_000.0 * inputPerMillion)
        + (Double(cachedInputTokens) / 1_000_000.0 * cachedInputPerMillion)
        + (Double(outputTokens) / 1_000_000.0 * outputPerMillion)
    }
}

struct UsageSlice: Equatable, Sendable {
    var totalTokens: Int
    var inputTokens: Int
    var cachedInputTokens: Int
    var outputTokens: Int
    var reasoningOutputTokens: Int

    static let zero = UsageSlice(
        totalTokens: 0,
        inputTokens: 0,
        cachedInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0
    )

    static func - (lhs: UsageSlice, rhs: UsageSlice) -> UsageSlice {
        UsageSlice(
            totalTokens: max(0, lhs.totalTokens - rhs.totalTokens),
            inputTokens: max(0, lhs.inputTokens - rhs.inputTokens),
            cachedInputTokens: max(0, lhs.cachedInputTokens - rhs.cachedInputTokens),
            outputTokens: max(0, lhs.outputTokens - rhs.outputTokens),
            reasoningOutputTokens: max(0, lhs.reasoningOutputTokens - rhs.reasoningOutputTokens)
        )
    }

    static func + (lhs: UsageSlice, rhs: UsageSlice) -> UsageSlice {
        UsageSlice(
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            cachedInputTokens: lhs.cachedInputTokens + rhs.cachedInputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            reasoningOutputTokens: lhs.reasoningOutputTokens + rhs.reasoningOutputTokens
        )
    }

    var nonCachedTokens: Int {
        max(0, totalTokens - cachedInputTokens)
    }

    func estimatedCost(using rates: PricingRates?) -> Double {
        guard let rates else { return 0 }
        return rates.estimatedCost(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens
        )
    }
}

struct ThreadUsage: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let model: String
    let updatedAt: Date
    let allTime: UsageSlice
    let thisMonth: UsageSlice
    let lastMonth: UsageSlice
    let today: UsageSlice
}

struct ModelUsage: Identifiable, Equatable, Sendable {
    var id: String { modelName }
    let modelName: String
    let allTime: UsageSlice
    let thisMonth: UsageSlice
    let lastMonth: UsageSlice
    let today: UsageSlice
}

struct UsageSnapshot: Equatable, Sendable {
    let generatedAt: Date
    let codexHome: String
    let allTime: UsageSlice
    let thisMonth: UsageSlice
    let lastMonth: UsageSlice
    let today: UsageSlice
    let threadCount: Int
    let threadsWithDetailedBreakdown: Int
    let modelUsage: [ModelUsage]
    let recentThreads: [ThreadUsage]
}

enum UsageDateFilter: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case today = "Today"

    var id: String { rawValue }
}

extension UsageSnapshot {
    func usage(for filter: UsageDateFilter) -> UsageSlice {
        switch filter {
        case .allTime:
            allTime
        case .thisMonth:
            thisMonth
        case .lastMonth:
            lastMonth
        case .today:
            today
        }
    }
}

extension ModelUsage {
    func usage(for filter: UsageDateFilter) -> UsageSlice {
        switch filter {
        case .allTime:
            allTime
        case .thisMonth:
            thisMonth
        case .lastMonth:
            lastMonth
        case .today:
            today
        }
    }
}

extension UsageSnapshot {
    func cost(for filter: UsageDateFilter, using pricingStore: PricingStore) -> Double {
        modelUsage.reduce(into: 0.0) { total, model in
            total += model.usage(for: filter).estimatedCost(using: pricingStore.rates(for: model.modelName))
        }
    }

    func currentMonthCost(using pricingStore: PricingStore) -> Double {
        cost(for: .thisMonth, using: pricingStore)
    }
}
