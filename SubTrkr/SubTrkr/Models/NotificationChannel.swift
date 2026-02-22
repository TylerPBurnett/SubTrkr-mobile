import Foundation

struct NotificationChannel: Codable, Identifiable {
    let id: String
    let userId: String
    var channelType: NotificationChannelType
    var channelName: String
    var enabled: Bool
    var config: [String: String]
    var eventTypes: [NotificationEventType]
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelType = "channel_type"
        case channelName = "channel_name"
        case enabled
        case config
        case eventTypes = "event_types"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NotificationPreferences: Codable, Identifiable {
    let id: String
    let userId: String
    var reminderDaysBefore: Int
    var timezone: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case reminderDaysBefore = "reminder_days_before"
        case timezone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NotificationLogEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let channelId: String
    let eventType: NotificationEventType
    let itemId: String
    let status: NotificationLogStatus
    let errorMessage: String?
    let sentAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case eventType = "event_type"
        case itemId = "item_id"
        case status
        case errorMessage = "error_message"
        case sentAt = "sent_at"
    }
}
