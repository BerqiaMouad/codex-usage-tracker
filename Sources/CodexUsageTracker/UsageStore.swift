import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var selectedFilter: UsageDateFilter = .thisMonth
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

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.pricingStore = PricingStore(userDefaults: userDefaults)
        let storedInterval = userDefaults.double(forKey: refreshIntervalKey)
        self.refreshInterval = storedInterval > 0 ? storedInterval : 10
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
            let newSnapshot = try await loader.load()
            snapshot = newSnapshot
            errorMessage = nil
            for model in newSnapshot.modelUsage {
                pricingStore.ensureDefaultExists(for: model.modelName)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
