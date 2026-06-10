import Foundation

enum SelfCheckError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            message
        }
    }
}

enum SelfCheck {
    static func run() throws {
        try assertCostEstimate()
        try assertClampedSubtraction()
        try assertDefaultPricingExists()
        try assertFractionalTimestampParsing()
    }

    private static func assertCostEstimate() throws {
        let rates = PricingRates(inputPerMillion: 2.5, cachedInputPerMillion: 0.25, outputPerMillion: 15)
        let usage = UsageSlice(
            totalTokens: 1_600_000,
            inputTokens: 1_000_000,
            cachedInputTokens: 500_000,
            outputTokens: 100_000,
            reasoningOutputTokens: 50_000
        )
        let value = usage.estimatedCost(using: rates)
        guard abs(value - 4.125) < 0.0001 else {
            throw SelfCheckError.failed("Cost estimate mismatch: expected 4.125, got \(value)")
        }
    }

    private static func assertClampedSubtraction() throws {
        let newer = UsageSlice(
            totalTokens: 1_000,
            inputTokens: 900,
            cachedInputTokens: 700,
            outputTokens: 100,
            reasoningOutputTokens: 50
        )
        let older = UsageSlice(
            totalTokens: 1_200,
            inputTokens: 1_000,
            cachedInputTokens: 800,
            outputTokens: 120,
            reasoningOutputTokens: 70
        )
        guard newer - older == .zero else {
            throw SelfCheckError.failed("UsageSlice subtraction should clamp at zero.")
        }
    }

    private static func assertDefaultPricingExists() throws {
        let requiredModels = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini"]
        for model in requiredModels where PricingConfiguration.defaultRates[model] == nil {
            throw SelfCheckError.failed("Missing default pricing for \(model)")
        }
    }

    private static func assertFractionalTimestampParsing() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard formatter.date(from: "2026-06-10T11:57:24.623Z") != nil else {
            throw SelfCheckError.failed("Fractional ISO8601 timestamps should parse.")
        }
    }
}
