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
        try assertWindowMath()
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
        guard abs(value - 2.875) < 0.0001 else {
            throw SelfCheckError.failed("Cost estimate mismatch: expected 2.875, got \(value)")
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

    private static func assertWindowMath() throws {
        let final = UsageSlice(
            totalTokens: 600,
            inputTokens: 500,
            cachedInputTokens: 300,
            outputTokens: 100,
            reasoningOutputTokens: 20
        )
        let beforeCurrentMonth = UsageSlice(
            totalTokens: 400,
            inputTokens: 330,
            cachedInputTokens: 200,
            outputTokens: 70,
            reasoningOutputTokens: 15
        )
        let beforePreviousMonth = UsageSlice(
            totalTokens: 150,
            inputTokens: 120,
            cachedInputTokens: 60,
            outputTokens: 30,
            reasoningOutputTokens: 8
        )
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 400)

        let lastMonth = UsageWindowMath.usageBetween(
            final: final,
            startBoundaryUsage: beforePreviousMonth,
            endBoundaryUsage: beforeCurrentMonth,
            recordCreatedAt: createdAt,
            recordUpdatedAt: updatedAt,
            windowStart: Date(timeIntervalSince1970: 200),
            windowEnd: Date(timeIntervalSince1970: 300)
        )

        guard lastMonth == beforeCurrentMonth - beforePreviousMonth else {
            throw SelfCheckError.failed("Last-month usage window should use boundary-to-boundary subtraction.")
        }

        let unknownCarryIn = UsageWindowMath.usageBetween(
            final: final,
            startBoundaryUsage: nil,
            endBoundaryUsage: beforeCurrentMonth,
            recordCreatedAt: createdAt,
            recordUpdatedAt: updatedAt,
            windowStart: Date(timeIntervalSince1970: 200),
            windowEnd: Date(timeIntervalSince1970: 300)
        )

        guard unknownCarryIn == nil else {
            throw SelfCheckError.failed("Ranges should not silently assume zero when carry-in usage is unknown.")
        }
    }
}
