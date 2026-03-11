import Foundation

struct StatusHistoryMetadata: Codable, Equatable {
    let action: String
    let effectiveDate: String?
}

enum StatusHistoryMetadataCodec {
    private static let prefix = "__subtrkr_meta__:"

    static func encode(metadata: StatusHistoryMetadata?, userNotes: String?) -> String? {
        let trimmedUserNotes = userNotes?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let metadata else {
            return trimmedUserNotes?.isEmpty == false ? trimmedUserNotes : nil
        }

        guard let metadataData = try? JSONEncoder().encode(metadata),
              let metadataString = String(data: metadataData, encoding: .utf8) else {
            return trimmedUserNotes?.isEmpty == false ? trimmedUserNotes : nil
        }

        guard let trimmedUserNotes, !trimmedUserNotes.isEmpty else {
            return prefix + metadataString
        }

        return prefix + metadataString + "\n" + trimmedUserNotes
    }

    static func decodeMetadata(from notes: String?) -> StatusHistoryMetadata? {
        guard let notes, notes.hasPrefix(prefix) else { return nil }

        let metadataLine = notes.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let rawMetadata = metadataLine.dropFirst(prefix.count)
        guard let metadataData = rawMetadata.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StatusHistoryMetadata.self, from: metadataData)
    }

    static func decodeUserNotes(from notes: String?) -> String? {
        guard let notes else { return nil }
        guard notes.hasPrefix(prefix) else {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedNotes.isEmpty ? nil : trimmedNotes
        }

        let parts = notes.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let trimmedNotes = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNotes.isEmpty ? nil : trimmedNotes
    }
}

struct StatusHistory: Codable, Identifiable {
    let id: String
    let itemId: String
    let userId: String
    let status: ItemStatus
    let reason: String?
    let notes: String?
    let changedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case userId = "user_id"
        case status
        case reason
        case notes
        case changedAt = "changed_at"
    }

    var changedAtFormatted: Date? {
        guard let changedAt else { return nil }
        return DateHelper.parseISO8601(changedAt)
    }

    var metadata: StatusHistoryMetadata? {
        StatusHistoryMetadataCodec.decodeMetadata(from: notes)
    }

    var userNotes: String? {
        StatusHistoryMetadataCodec.decodeUserNotes(from: notes)
    }

    var effectiveDateFormatted: Date? {
        guard let effectiveDate = metadata?.effectiveDate else { return nil }
        return DateHelper.parseDate(effectiveDate)
    }
}

struct StatusHistoryInsert: Codable {
    let itemId: String
    let userId: String
    let status: ItemStatus
    let reason: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case userId = "user_id"
        case status
        case reason
        case notes
    }
}

struct StatusChangeData {
    let action: String
    var effectiveDate: Date?
    var reason: String?
    var notes: String?
    var autoResumeDate: Date?
}
