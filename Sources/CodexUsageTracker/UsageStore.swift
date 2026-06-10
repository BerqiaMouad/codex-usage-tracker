import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var selectedFilter: UsageDateFilter = .thisMonth {
        didSet {
            refreshNow()
        }
    }
    @Published var customStartDate: Date {
        didSet {
            if customStartDate > customEndDate {
                customEndDate = customStartDate
            }
            if selectedFilter == .custom {
                refreshNow()
            }
        }
    }
    @Published var customEndDate: Date {
        didSet {
            if customEndDate < customStartDate {
                customStartDate = customEndDate
            }
            if selectedFilter == .custom {
                refreshNow()
            }
        }
    }
    @Published var refreshInterval: Double {
        didSet {
            userDefaults.set(refreshInterval, forKey: refreshIntervalKey)
            startRefreshLoop()
        }
    }

    let pricingStore: PricingStore

    private let loader = CodexDataLoader()
    private let userDefaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalKey = "CodexUsageTracker.refreshInterval"
    private let customStartDateKey = "CodexUsageTracker.customStartDate"
    private let customEndDateKey = "CodexUsageTracker.customEndDate"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.pricingStore = PricingStore(userDefaults: userDefaults)
        let storedInterval = userDefaults.double(forKey: refreshIntervalKey)
        self.refreshInterval = storedInterval > 0 ? storedInterval : 10
        let now = Date()
        let storedStart = userDefaults.object(forKey: customStartDateKey) as? Date
        let storedEnd = userDefaults.object(forKey: customEndDateKey) as? Date
        self.customEndDate = storedEnd ?? now
        self.customStartDate = storedStart ?? Calendar(identifier: .gregorian).date(byAdding: .day, value: -30, to: now) ?? now
        startRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
    }

    func refreshNow() {
        Task {
            await refresh()
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task {
            await refresh()
            while !Task.isCancelled {
                let delay = UInt64(max(2, refreshInterval) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newSnapshot = try await loader.load(
                selectedFilter: selectedFilter,
                customStartDate: customStartDate,
                customEndDate: customEndDate
            )
            snapshot = newSnapshot
            errorMessage = nil
            for model in newSnapshot.modelUsage {
                pricingStore.ensureDefaultExists(for: model.modelName)
            }
            userDefaults.set(customStartDate, forKey: customStartDateKey)
            userDefaults.set(customEndDate, forKey: customEndDateKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
