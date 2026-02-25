import Foundation
import Supabase

final class PaymentService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Read

    func getPayments(itemId: String? = nil) async throws -> [Payment] {
        if let itemId {
            return try await client.from("payments")
                .select()
                .eq("item_id", value: itemId)
                .order("paid_date", ascending: false)
                .execute()
                .value
        }

        return try await client.from("payments")
            .select()
            .order("paid_date", ascending: false)
            .execute()
            .value
    }

    // MARK: - Create

    func recordPayment(userId: String, itemId: String, amount: Double, paidDate: Date) async throws -> Payment {
        let insert = PaymentInsert(
            userId: userId,
            itemId: itemId,
            amount: amount,
            paidDate: DateHelper.formatDate(paidDate)
        )

        return try await client.from("payments")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }
}
