import Foundation
import SQLite3

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "Failed to open Codex state database: \(message)"
        case .prepareFailed(let message):
            "Failed to query Codex threads: \(message)"
        }
    }
}

struct ThreadDatabase {
    let path: String

    func fetchAuthenticatedOpenAIThreads() throws -> [ThreadRecord] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT id, rollout_path, created_at, updated_at, COALESCE(model, ''), title, tokens_used
        FROM threads
        WHERE model_provider = 'openai'
          AND (model IS NULL OR model NOT LIKE '%MiniMax%')
        ORDER BY updated_at DESC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        var threads: [ThreadRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = stringColumn(statement, index: 0)
            let rolloutPath = stringColumn(statement, index: 1)
            let createdAt = dateColumn(statement, index: 2)
            let updatedAt = dateColumn(statement, index: 3)
            let rawModel = stringColumn(statement, index: 4)
            let model = rawModel.isEmpty ? "(unknown)" : rawModel
            let title = stringColumn(statement, index: 5)
            let tokensUsed = intColumn(statement, index: 6)

            threads.append(
                ThreadRecord(
                    id: id,
                    rolloutPath: rolloutPath,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    model: model,
                    title: title.isEmpty ? "Untitled thread" : title,
                    tokensUsed: tokensUsed
                )
            )
        }

        return threads
    }

    private func stringColumn(_ statement: OpaquePointer, index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private func intColumn(_ statement: OpaquePointer, index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    private func dateColumn(_ statement: OpaquePointer, index: Int32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, index)))
    }
}
