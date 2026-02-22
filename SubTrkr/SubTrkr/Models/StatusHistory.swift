import Foundation

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
