import Foundation

struct Payment: Decodable, Identifiable {
    let id: String
    let userId: String
    let itemId: String
    let amount: Double
    let paidDate: String
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case amount
        case paidDate = "paid_date"
        case paymentDate = "payment_date"
        case createdAt = "created_at"
    }

    init(id: String, userId: String, itemId: String, amount: Double, paidDate: String, createdAt: String?) {
        self.id = id
        self.userId = userId
        self.itemId = itemId
        self.amount = amount
        self.paidDate = paidDate
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        itemId = try container.decode(String.self, forKey: .itemId)
        amount = try container.decode(Double.self, forKey: .amount)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        if let paidDate = try container.decodeIfPresent(String.self, forKey: .paidDate) {
            self.paidDate = paidDate
        } else if let paymentDate = try container.decodeIfPresent(String.self, forKey: .paymentDate) {
            self.paidDate = paymentDate
        } else if let createdAt, createdAt.count >= 10 {
            // Compatibility fallback for schemas that only persist created_at on payments.
            self.paidDate = String(createdAt.prefix(10))
        } else {
            self.paidDate = ""
        }
    }

    var paidDateFormatted: Date? {
        DateHelper.parseDate(paidDate)
    }
}

struct PaymentInsert: Encodable {
    let userId: String
    let itemId: String
    let amount: Double
    let paidDate: String

    private enum PaidDateCodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case amount
        case paidDate = "paid_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PaidDateCodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(itemId, forKey: .itemId)
        try container.encode(amount, forKey: .amount)
        try container.encode(paidDate, forKey: .paidDate)
    }
}
