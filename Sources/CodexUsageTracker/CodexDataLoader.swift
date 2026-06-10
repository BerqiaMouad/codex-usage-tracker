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
    let beforeCurrentMonth: UsageSlice?
    let beforePreviousMonth: UsageSlice?
    let beforeDay: UsageSlice?
}

actor RolloutCache {
    private struct Entry {
        let size: UInt64
        let modifiedAt: Date
        let currentMonthStart: Date
        let previousMonthStart: Date
        let dayStart: Date
        let needsCurrentMonthBoundary: Bool
        let needsPreviousMonthBoundary: Bool
        let needsDayBoundary: Bool
        let summary: RolloutCheckpointSummary
    }

    private var entries: [String: Entry] = [:]

    func summary(
        for path: String,
        currentMonthStart: Date,
        previousMonthStart: Date,
        dayStart: Date,
        needsCurrentMonthBoundary: Bool,
        needsPreviousMonthBoundary: Bool,
        needsDayBoundary: Bool
    ) throws -> RolloutCheckpointSummary {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = UInt64(values.fileSize ?? 0)
        let modifiedAt = values.contentModificationDate ?? .distantPast

        if let cached = entries[path],
           cached.size == size,
           cached.modifiedAt == modifiedAt,
           cached.currentMonthStart == currentMonthStart,
           cached.previousMonthStart == previousMonthStart,
           cached.dayStart == dayStart,
           cached.needsCurrentMonthBoundary == needsCurrentMonthBoundary,
           cached.needsPreviousMonthBoundary == needsPreviousMonthBoundary,
           cached.needsDayBoundary == needsDayBoundary {
            return cached.summary
        }

        let summary = try RolloutParser.parse(
            path: path,
            currentMonthStart: currentMonthStart,
            previousMonthStart: previousMonthStart,
            dayStart: dayStart,
            needsCurrentMonthBoundary: needsCurrentMonthBoundary,
            needsPreviousMonthBoundary: needsPreviousMonthBoundary,
            needsDayBoundary: needsDayBoundary
        )
        entries[path] = Entry(
            size: size,
            modifiedAt: modifiedAt,
            currentMonthStart: currentMonthStart,
            previousMonthStart: previousMonthStart,
            dayStart: dayStart,
            needsCurrentMonthBoundary: needsCurrentMonthBoundary,
            needsPreviousMonthBoundary: needsPreviousMonthBoundary,
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
        let currentMonthStart = calendar.date(from: monthComponents) ?? dayStart
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart

        var allTime = UsageSlice.zero
        var thisMonth = UsageSlice.zero
        var lastMonth = UsageSlice.zero
        var today = UsageSlice.zero
        var threadsWithDetailedBreakdown = 0
        var modelMap: [String: (all: UsageSlice, thisMonth: UsageSlice, lastMonth: UsageSlice, today: UsageSlice)] = [:]
        var threadUsage: [ThreadUsage] = []

        for record in records {
            let needsCurrentMonthBoundary = record.updatedAt >= currentMonthStart
            let needsPreviousMonthBoundary = record.updatedAt >= previousMonthStart
            let needsDayBoundary = record.updatedAt >= dayStart
            let summary = try await rolloutCache.summary(
                for: record.rolloutPath,
                currentMonthStart: currentMonthStart,
                previousMonthStart: previousMonthStart,
                dayStart: dayStart,
                needsCurrentMonthBoundary: needsCurrentMonthBoundary,
                needsPreviousMonthBoundary: needsPreviousMonthBoundary,
                needsDayBoundary: needsDayBoundary
            )
            let final = summary.final ?? UsageSlice(
                totalTokens: record.tokensUsed,
                inputTokens: 0,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0
            )
            let thisMonthSlice = UsageWindowMath.usageBetween(
                final: final,
                startBoundaryUsage: summary.beforeCurrentMonth,
                endBoundaryUsage: nil,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: currentMonthStart,
                windowEnd: nil
            )
            let lastMonthSlice = UsageWindowMath.usageBetween(
                final: final,
                startBoundaryUsage: summary.beforePreviousMonth,
                endBoundaryUsage: summary.beforeCurrentMonth,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: previousMonthStart,
                windowEnd: currentMonthStart
            )
            let todaySlice = UsageWindowMath.usageBetween(
                final: final,
                startBoundaryUsage: summary.beforeDay,
                endBoundaryUsage: nil,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: dayStart,
                windowEnd: nil
            )

            if summary.final != nil {
                threadsWithDetailedBreakdown += 1
            }

            allTime = allTime + final
            thisMonth = thisMonth + thisMonthSlice
            lastMonth = lastMonth + lastMonthSlice
            today = today + todaySlice

            let current = modelMap[record.model] ?? (.zero, .zero, .zero, .zero)
            modelMap[record.model] = (
                all: current.all + final,
                thisMonth: current.thisMonth + thisMonthSlice,
                lastMonth: current.lastMonth + lastMonthSlice,
                today: current.today + todaySlice
            )

            threadUsage.append(
                ThreadUsage(
                    id: record.id,
                    title: record.title,
                    model: record.model,
                    updatedAt: record.updatedAt,
                    allTime: final,
                    thisMonth: thisMonthSlice,
                    lastMonth: lastMonthSlice,
                    today: todaySlice
                )
            )
        }

        let models = modelMap
            .map { key, value in
                ModelUsage(modelName: key, allTime: value.all, thisMonth: value.thisMonth, lastMonth: value.lastMonth, today: value.today)
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
            thisMonth: thisMonth,
            lastMonth: lastMonth,
            today: today,
            threadCount: records.count,
            threadsWithDetailedBreakdown: threadsWithDetailedBreakdown,
            modelUsage: models,
            recentThreads: Array(recentThreads)
        )
    }
}

enum UsageWindowMath {
    static func usageBetween(
        final: UsageSlice,
        startBoundaryUsage: UsageSlice?,
        endBoundaryUsage: UsageSlice?,
        recordCreatedAt: Date,
        recordUpdatedAt: Date,
        windowStart: Date,
        windowEnd: Date?
    ) -> UsageSlice {
        guard recordUpdatedAt >= windowStart else {
            return .zero
        }

        let startCumulative = cumulativeUsage(
            final: final,
            boundaryUsage: startBoundaryUsage,
            recordCreatedAt: recordCreatedAt,
            recordUpdatedAt: recordUpdatedAt,
            boundaryDate: windowStart
        )

        let endCumulative = if let windowEnd {
            cumulativeUsage(
                final: final,
                boundaryUsage: endBoundaryUsage,
                recordCreatedAt: recordCreatedAt,
                recordUpdatedAt: recordUpdatedAt,
                boundaryDate: windowEnd
            )
        } else {
            final
        }

        return endCumulative - startCumulative
    }

    static func cumulativeUsage(
        final: UsageSlice,
        boundaryUsage: UsageSlice?,
        recordCreatedAt: Date,
        recordUpdatedAt: Date,
        boundaryDate: Date
    ) -> UsageSlice {
        if recordUpdatedAt < boundaryDate {
            return final
        }
        if let boundaryUsage {
            return boundaryUsage
        }
        if recordCreatedAt >= boundaryDate {
            return .zero
        }
        return .zero
    }
}
