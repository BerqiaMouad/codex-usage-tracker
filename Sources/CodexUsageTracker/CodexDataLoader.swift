import Foundation

struct ThreadRecord: Sendable {
    let id: String
    let rolloutPath: String
    let createdAt: Date
    let updatedAt: Date
    let model: String
    let title: String
    let tokensUsed: Int
}

struct RolloutCheckpointSummary: Sendable {
    let final: UsageSlice?
    let beforeMonth: UsageSlice?
    let beforeDay: UsageSlice?
}

actor RolloutCache {
    private struct Entry {
        let size: UInt64
        let modifiedAt: Date
        let monthStart: Date
        let dayStart: Date
        let needsMonthBoundary: Bool
        let needsDayBoundary: Bool
        let summary: RolloutCheckpointSummary
    }

    private var entries: [String: Entry] = [:]

    func summary(
        for path: String,
        monthStart: Date,
        dayStart: Date,
        needsMonthBoundary: Bool,
        needsDayBoundary: Bool
    ) throws -> RolloutCheckpointSummary {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = UInt64(values.fileSize ?? 0)
        let modifiedAt = values.contentModificationDate ?? .distantPast

        if let cached = entries[path],
           cached.size == size,
           cached.modifiedAt == modifiedAt,
           cached.monthStart == monthStart,
           cached.dayStart == dayStart,
           cached.needsMonthBoundary == needsMonthBoundary,
           cached.needsDayBoundary == needsDayBoundary {
            return cached.summary
        }

        let summary = try RolloutParser.parse(
            path: path,
            monthStart: monthStart,
            dayStart: dayStart,
            needsMonthBoundary: needsMonthBoundary,
            needsDayBoundary: needsDayBoundary
        )
        entries[path] = Entry(
            size: size,
            modifiedAt: modifiedAt,
            monthStart: monthStart,
            dayStart: dayStart,
            needsMonthBoundary: needsMonthBoundary,
            needsDayBoundary: needsDayBoundary,
            summary: summary
        )
        return summary
    }
}

actor CodexDataLoader {
    private let rolloutCache = RolloutCache()

    func load() async throws -> UsageSnapshot {
        let codexHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let statePath = codexHome.appendingPathComponent("state_5.sqlite").path
        let records = try ThreadDatabase(path: statePath).fetchAuthenticatedOpenAIThreads()

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: monthComponents) ?? dayStart

        var allTime = UsageSlice.zero
        var month = UsageSlice.zero
        var today = UsageSlice.zero
        var threadsWithDetailedBreakdown = 0
        var modelMap: [String: (all: UsageSlice, month: UsageSlice, today: UsageSlice)] = [:]
        var threadUsage: [ThreadUsage] = []

        for record in records {
            let needsMonthBoundary = record.updatedAt >= monthStart
            let needsDayBoundary = record.updatedAt >= dayStart
            let summary = try await rolloutCache.summary(
                for: record.rolloutPath,
                monthStart: monthStart,
                dayStart: dayStart,
                needsMonthBoundary: needsMonthBoundary,
                needsDayBoundary: needsDayBoundary
            )
            let final = summary.final ?? UsageSlice(
                totalTokens: record.tokensUsed,
                inputTokens: 0,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0
            )
            let monthSlice = usageWithinWindow(
                final: final,
                boundaryUsage: summary.beforeMonth,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: monthStart
            )
            let todaySlice = usageWithinWindow(
                final: final,
                boundaryUsage: summary.beforeDay,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: dayStart
            )

            if summary.final != nil {
                threadsWithDetailedBreakdown += 1
            }

            allTime = allTime + final
            month = month + monthSlice
            today = today + todaySlice

            let current = modelMap[record.model] ?? (.zero, .zero, .zero)
            modelMap[record.model] = (
                all: current.all + final,
                month: current.month + monthSlice,
                today: current.today + todaySlice
            )

            threadUsage.append(
                ThreadUsage(
                    id: record.id,
                    title: record.title,
                    model: record.model,
                    updatedAt: record.updatedAt,
                    allTime: final,
                    month: monthSlice,
                    today: todaySlice
                )
            )
        }

        let models = modelMap
            .map { key, value in
                ModelUsage(modelName: key, allTime: value.all, month: value.month, today: value.today)
            }
            .sorted { $0.allTime.totalTokens > $1.allTime.totalTokens }

        let recentThreads = threadUsage
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.allTime.totalTokens > rhs.allTime.totalTokens
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(20)

        return UsageSnapshot(
            generatedAt: now,
            codexHome: "~/.codex",
            allTime: allTime,
            month: month,
            today: today,
            threadCount: records.count,
            threadsWithDetailedBreakdown: threadsWithDetailedBreakdown,
            modelUsage: models,
            recentThreads: Array(recentThreads)
        )
    }

    private func usageWithinWindow(
        final: UsageSlice,
        boundaryUsage: UsageSlice?,
        recordCreatedAt: Date,
        recordUpdatedAt: Date,
        windowStart: Date
    ) -> UsageSlice {
        guard recordUpdatedAt >= windowStart else {
            return .zero
        }
        if let boundaryUsage {
            return final - boundaryUsage
        }
        return recordCreatedAt >= windowStart ? final : .zero
    }
}
