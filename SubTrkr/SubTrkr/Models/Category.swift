import Foundation
import SwiftUI

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var name: String
    var color: String
    var icon: String?
    var type: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case color
        case icon
        case type
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var swiftColor: Color {
        Color(hex: color)
    }

    var itemType: ItemType? {
        guard let type else { return nil }
        return ItemType(rawValue: type)
    }
}

struct CategoryInsert: Codable {
    let id: String
    let userId: String
    let name: String
    let color: String
    let icon: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case color
        case icon
        case type
    }
}

struct CategoryUpdate: Codable {
    var name: String?
    var color: String?
    var icon: String?
    var type: String?
}

// MARK: - Default Categories

extension Category {
    static let defaultSubscriptionCategories: [(name: String, color: String)] = [
        ("Streaming", "#6366f1"),
        ("Software", "#8b5cf6"),
        ("Gaming", "#ec4899"),
        ("News", "#f59e0b"),
        ("Fitness", "#22c55e"),
        ("Music", "#06b6d4"),
        ("Cloud Storage", "#3b82f6"),
        ("Other", "#64748b")
    ]

    static let defaultBillCategories: [(name: String, color: String)] = [
        ("Utilities", "#f59e0b"),
        ("Housing", "#6366f1"),
        ("Insurance", "#3b82f6"),
        ("Phone & Internet", "#06b6d4"),
        ("Transportation", "#22c55e")
    ]
}
