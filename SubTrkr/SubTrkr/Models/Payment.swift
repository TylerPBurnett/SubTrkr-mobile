import Foundation

struct Payment: Codable, Identifiable {
    let id: String
    let userId: String
    let itemId: String
    let amount: Double
    let paidDate: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case amount
        case paidDate = "paid_date"
        case createdAt = "created_at"
    }

    var paidDateFormatted: Date? {
        DateHelper.parseDate(paidDate)
    }
}

struct PaymentInsert: Codable {
    let userId: String
    let itemId: String
    let amount: Double
    let paidDate: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case amount
        case paidDate = "paid_date"
    }
}
