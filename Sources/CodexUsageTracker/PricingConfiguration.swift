import Foundation

enum PricingConfiguration {
    static let sourceLabel = "OpenAI standard short-context API pricing"
    static let sourceURL = URL(string: "https://openai.com/api/pricing/")!

    static let defaultRates: [String: PricingRates] = [
        "gpt-5.5": PricingRates(inputPerMillion: 5.0, cachedInputPerMillion: 0.5, outputPerMillion: 30.0),
        "gpt-5.4": PricingRates(inputPerMillion: 2.5, cachedInputPerMillion: 0.25, outputPerMillion: 15.0),
        "gpt-5.4-mini": PricingRates(inputPerMillion: 0.75, cachedInputPerMillion: 0.075, outputPerMillion: 4.5),
    ]

    static let pricingDisclaimer = """
    Estimated cost uses editable per-model rates. Defaults come from the public OpenAI API pricing page \
    for standard short-context processing and exclude tool-call fees, priority or flex pricing, taxes, \
    and any Codex-authenticated discounts or internal billing differences.
    """
}

final class PricingStore: ObservableObject {
    @Published private(set) var ratesByModel: [String: PricingRates]

    private let defaultsKey = "CodexUsageTracker.pricingRates"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if
            let data = userDefaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([String: PricingRates].self, from: data)
        {
            ratesByModel = decoded.merging(PricingConfiguration.defaultRates) { current, _ in current }
        } else {
            ratesByModel = PricingConfiguration.defaultRates
        }
    }

    var allRates: [String: PricingRates] {
        ratesByModel
    }

    func rates(for modelName: String) -> PricingRates? {
        ratesByModel[modelName]
    }

    func setRates(_ rates: PricingRates, for modelName: String) {
        ratesByModel[modelName] = rates
        persist()
    }

    func ensureDefaultExists(for modelName: String) {
        guard ratesByModel[modelName] == nil else { return }
        ratesByModel[modelName] = PricingRates(inputPerMillion: 0, cachedInputPerMillion: 0, outputPerMillion: 0)
        persist()
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(ratesByModel) else { return }
        userDefaults.set(encoded, forKey: defaultsKey)
    }
}
