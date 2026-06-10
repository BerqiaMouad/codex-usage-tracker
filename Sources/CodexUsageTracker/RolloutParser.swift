import Foundation

enum RolloutParser {
    static func parse(
        path: String,
        currentMonthStart: Date,
        previousMonthStart: Date,
        dayStart: Date,
        needsCurrentMonthBoundary: Bool,
        needsPreviousMonthBoundary: Bool,
        needsDayBoundary: Bool
    ) throws -> RolloutCheckpointSummary {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        var final: UsageSlice?
        var beforeCurrentMonth: UsageSlice?
        var beforePreviousMonth: UsageSlice?
        var beforeDay: UsageSlice?

        func processLine(_ lineData: Data) {
            guard
                let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                object["type"] as? String == "event_msg",
                let payload = object["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let info = payload["info"] as? [String: Any],
                let total = info["total_token_usage"] as? [String: Any]
            else {
                return
            }

            let snapshot = UsageSlice(
                totalTokens: intValue(total["total_tokens"]),
                inputTokens: intValue(total["input_tokens"]),
                cachedInputTokens: intValue(total["cached_input_tokens"]),
                outputTokens: intValue(total["output_tokens"]),
                reasoningOutputTokens: intValue(total["reasoning_output_tokens"])
            )

            if final == nil {
                final = snapshot
            }
            if needsDayBoundary || needsCurrentMonthBoundary || needsPreviousMonthBoundary,
               let timestampString = object["timestamp"] as? String,
               let timestamp = formatter.date(from: timestampString) {
                if needsDayBoundary, beforeDay == nil, timestamp < dayStart {
                    beforeDay = snapshot
                }
                if needsCurrentMonthBoundary, beforeCurrentMonth == nil, timestamp < currentMonthStart {
                    beforeCurrentMonth = snapshot
                }
                if needsPreviousMonthBoundary, beforePreviousMonth == nil, timestamp < previousMonthStart {
                    beforePreviousMonth = snapshot
                }
            }
        }

        var lineEnd = data.endIndex
        var index = data.endIndex

        while index > data.startIndex {
            index = data.index(before: index)
            if data[index] == 0x0A {
                let lineStart = data.index(after: index)
                if lineStart < lineEnd {
                    processLine(data.subdata(in: lineStart..<lineEnd))
                    let hasNeededDay = !needsDayBoundary || beforeDay != nil
                    let hasNeededCurrentMonth = !needsCurrentMonthBoundary || beforeCurrentMonth != nil
                    let hasNeededPreviousMonth = !needsPreviousMonthBoundary || beforePreviousMonth != nil
                    if final != nil, hasNeededCurrentMonth, hasNeededPreviousMonth, hasNeededDay {
                        break
                    }
                }
                lineEnd = index
            }
        }

        if lineEnd > data.startIndex {
            processLine(data.subdata(in: data.startIndex..<lineEnd))
        }

        return RolloutCheckpointSummary(
            final: final,
            beforeCurrentMonth: beforeCurrentMonth,
            beforePreviousMonth: beforePreviousMonth,
            beforeDay: beforeDay
        )
    }

    private static func intValue(_ any: Any?) -> Int {
        if let int = any as? Int { return int }
        if let number = any as? NSNumber { return number.intValue }
        if let string = any as? String, let int = Int(string) { return int }
        return 0
    }
}
