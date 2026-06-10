import Foundation

enum RolloutParser {
    static func parse(path: String, boundaries: [String: Date]) throws -> RolloutCheckpointSummary {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        var final: UsageSlice?
        var boundaryUsage: [String: UsageSlice] = [:]

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
            if !boundaries.isEmpty,
               let timestampString = object["timestamp"] as? String,
               let timestamp = formatter.date(from: timestampString) {
                for (key, boundaryDate) in boundaries where boundaryUsage[key] == nil && timestamp < boundaryDate {
                    boundaryUsage[key] = snapshot
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
                    if final != nil, boundaryUsage.count == boundaries.count {
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
            boundaryUsage: boundaryUsage
        )
    }

    private static func intValue(_ any: Any?) -> Int {
        if let int = any as? Int { return int }
        if let number = any as? NSNumber { return number.intValue }
        if let string = any as? String, let int = Int(string) { return int }
        return 0
    }
}
