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
    let boundaryUsage: [String: UsageSlice]
}

actor RolloutCache {
    private struct Entry {
        let size: UInt64
        let modifiedAt: Date
        let boundarySignature: String
        let summary: RolloutCheckpointSummary
    }

    private var entries: [String: Entry] = [:]

    func summary(
        for path: String,
        boundaries: [String: Date]
    ) throws -> RolloutCheckpointSummary {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = UInt64(values.fileSize ?? 0)
        let modifiedAt = values.contentModificationDate ?? .distantPast
        let signature = boundaries
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.timeIntervalSince1970)" }
            .joined(separator: "|")

        if let cached = entries[path],
           cached.size == size,
           cached.modifiedAt == modifiedAt,
           cached.boundarySignature == signature {
            return cached.summary
        }

        let summary = try RolloutParser.parse(path: path, boundaries: boundaries)
        entries[path] = Entry(
            size: size,
            modifiedAt: modifiedAt,
            boundarySignature: signature,
            summary: summary
        )
        return summary
    }
}

actor CodexDataLoader {
    private let rolloutCache = RolloutCache()

    func load(
        selectedFilter: UsageDateFilter,
        customStartDate: Date,
        customEndDate: Date
    ) async throws -> UsageSnapshot {
        let codexHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let statePath = codexHome.appendingPathComponent("state_5.sqlite").path
        let records = try ThreadDatabase(path: statePath).fetchAuthenticatedOpenAIThreads()

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        let currentMonthStart = calendar.date(from: monthComponents) ?? dayStart
        let normalizedCustomStart = calendar.startOfDay(for: customStartDate)
        let customEndDayStart = calendar.startOfDay(for: customEndDate)
        let normalizedCustomEnd = calendar.date(byAdding: .day, value: 1, to: customEndDayStart) ?? customEndDayStart

        var allTime = UsageSlice.zero
        var thisMonth = UsageSlice.zero
        var today = UsageSlice.zero
        var thisMonthExcludedThreads = 0
        var todayExcludedThreads = 0
        var selectedRange = UsageSlice.zero
        var threadsWithDetailedBreakdown = 0
        var selectedRangeExcludedThreads = 0
        var modelMap: [String: (all: UsageSlice, thisMonth: UsageSlice, today: UsageSlice, selectedRange: UsageSlice)] = [:]
        var threadUsage: [ThreadUsage] = []

        let selectedWindow = SelectedUsageWindow.make(
            filter: selectedFilter,
            now: now,
            dayStart: dayStart,
            currentMonthStart: currentMonthStart,
            customStartDate: normalizedCustomStart,
            customEndDateExclusive: normalizedCustomEnd
        )

        for record in records {
            var boundaries: [String: Date] = [:]
            if record.updatedAt >= currentMonthStart {
                boundaries["currentMonthStart"] = currentMonthStart
            }
            if record.updatedAt >= dayStart {
                boundaries["dayStart"] = dayStart
            }
            if let selectedStart = selectedWindow.start, record.updatedAt >= selectedStart {
                boundaries["selectedStart"] = selectedStart
            }
            if let selectedEnd = selectedWindow.end, record.updatedAt >= selectedEnd {
                boundaries["selectedEnd"] = selectedEnd
            }
            let summary = try await rolloutCache.summary(
                for: record.rolloutPath,
                boundaries: boundaries
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
                startBoundaryUsage: summary.boundaryUsage["currentMonthStart"],
                endBoundaryUsage: nil,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: currentMonthStart,
                windowEnd: nil
            )
            let todaySlice = UsageWindowMath.usageBetween(
                final: final,
                startBoundaryUsage: summary.boundaryUsage["dayStart"],
                endBoundaryUsage: nil,
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: dayStart,
                windowEnd: nil
            )
            let selectedRangeSlice = selectedRangeSlice(
                selectedWindow: selectedWindow,
                summary: summary,
                final: final,
                record: record
            )

            if summary.final != nil {
                threadsWithDetailedBreakdown += 1
            }

            allTime = allTime + final
            if let thisMonthSlice {
                thisMonth = thisMonth + thisMonthSlice
            } else if UsageWindowMath.intersectsWindow(
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: currentMonthStart,
                windowEnd: nil
            ) {
                thisMonthExcludedThreads += 1
            }
            if let todaySlice {
                today = today + todaySlice
            } else if UsageWindowMath.intersectsWindow(
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: dayStart,
                windowEnd: nil
            ) {
                todayExcludedThreads += 1
            }
            if let selectedRangeSlice {
                selectedRange = selectedRange + selectedRangeSlice
            } else if UsageWindowMath.intersectsWindow(
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: selectedWindow.start,
                windowEnd: selectedWindow.end
            ) {
                selectedRangeExcludedThreads += 1
            }

            let current = modelMap[record.model] ?? (.zero, .zero, .zero, .zero)
            modelMap[record.model] = (
                all: current.all + final,
                thisMonth: current.thisMonth + (thisMonthSlice ?? .zero),
                today: current.today + (todaySlice ?? .zero),
                selectedRange: current.selectedRange + (selectedRangeSlice ?? .zero)
            )

            threadUsage.append(
                ThreadUsage(
                    id: record.id,
                    title: record.title,
                    model: record.model,
                    updatedAt: record.updatedAt,
                    allTime: final,
                    thisMonth: thisMonthSlice ?? .zero,
                    today: todaySlice ?? .zero,
                    selectedRange: selectedRangeSlice ?? .zero
                )
            )
        }

        let models = modelMap
            .map { key, value in
                ModelUsage(modelName: key, allTime: value.all, thisMonth: value.thisMonth, today: value.today, selectedRange: value.selectedRange)
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
            today: today,
            thisMonthExcludedThreads: thisMonthExcludedThreads,
            todayExcludedThreads: todayExcludedThreads,
            selectedRange: selectedRange,
            selectedRangeLabel: selectedWindow.label,
            selectedRangeExcludedThreads: selectedRangeExcludedThreads,
            threadCount: records.count,
            threadsWithDetailedBreakdown: threadsWithDetailedBreakdown,
            modelUsage: models,
            recentThreads: Array(recentThreads)
        )
    }

    private func selectedRangeSlice(
        selectedWindow: SelectedUsageWindow,
        summary: RolloutCheckpointSummary,
        final: UsageSlice,
        record: ThreadRecord
    ) -> UsageSlice? {
        switch selectedWindow.kind {
        case .allTime:
            return final
        case .bounded:
            guard let start = selectedWindow.start else { return final }
            return UsageWindowMath.usageBetween(
                final: final,
                startBoundaryUsage: summary.boundaryUsage["selectedStart"],
                endBoundaryUsage: selectedWindow.end == nil ? nil : summary.boundaryUsage["selectedEnd"],
                recordCreatedAt: record.createdAt,
                recordUpdatedAt: record.updatedAt,
                windowStart: start,
                windowEnd: selectedWindow.end
            )
        }
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
    ) -> UsageSlice? {
        guard recordUpdatedAt >= windowStart else {
            return .zero
        }
        if let windowEnd, windowEnd <= windowStart {
            return .zero
        }

        guard let startCumulative = cumulativeUsage(
            final: final,
            boundaryUsage: startBoundaryUsage,
            recordCreatedAt: recordCreatedAt,
            recordUpdatedAt: recordUpdatedAt,
            boundaryDate: windowStart
        ) else {
            return nil
        }

        let endCumulative: UsageSlice
        if let windowEnd {
            guard let cumulative = cumulativeUsage(
                final: final,
                boundaryUsage: endBoundaryUsage,
                recordCreatedAt: recordCreatedAt,
                recordUpdatedAt: recordUpdatedAt,
                boundaryDate: windowEnd
            ) else {
                return nil
            }
            endCumulative = cumulative
        } else {
            endCumulative = final
        }

        return endCumulative - startCumulative
    }

    static func cumulativeUsage(
        final: UsageSlice,
        boundaryUsage: UsageSlice?,
        recordCreatedAt: Date,
        recordUpdatedAt: Date,
        boundaryDate: Date
    ) -> UsageSlice? {
        if recordUpdatedAt < boundaryDate {
            return final
        }
        if let boundaryUsage {
            return boundaryUsage
        }
        if recordCreatedAt >= boundaryDate {
            return .zero
        }
        return nil
    }

    static func intersectsWindow(
        recordCreatedAt: Date,
        recordUpdatedAt: Date,
        windowStart: Date?,
        windowEnd: Date?
    ) -> Bool {
        if let windowStart, recordUpdatedAt < windowStart {
            return false
        }
        if let windowEnd, recordCreatedAt >= windowEnd {
            return false
        }
        return true
    }
}

private struct SelectedUsageWindow {
    enum Kind {
        case allTime
        case bounded
    }

    let kind: Kind
    let start: Date?
    let end: Date?
    let label: String

    static func make(
        filter: UsageDateFilter,
        now: Date,
        dayStart: Date,
        currentMonthStart: Date,
        customStartDate: Date,
        customEndDateExclusive: Date
    ) -> SelectedUsageWindow {
        switch filter {
        case .allTime:
            return SelectedUsageWindow(kind: .allTime, start: nil, end: nil, label: "All Time")
        case .thisMonth:
            return SelectedUsageWindow(kind: .bounded, start: currentMonthStart, end: nil, label: "This Month")
        case .today:
            return SelectedUsageWindow(kind: .bounded, start: dayStart, end: nil, label: "Today")
        case .custom:
            let startText = customStartDate.formatted(date: .abbreviated, time: .omitted)
            let inclusiveEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: customEndDateExclusive) ?? customEndDateExclusive
            let endText = inclusiveEnd.formatted(date: .abbreviated, time: .omitted)
            return SelectedUsageWindow(kind: .bounded, start: customStartDate, end: customEndDateExclusive, label: "\(startText) - \(endText)")
        }
    }
}
