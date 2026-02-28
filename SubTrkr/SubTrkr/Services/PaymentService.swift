import Foundation
import Supabase

final class PaymentService {
    private let client: SupabaseClient

    private struct LegacyPaymentInsert: Encodable {
        let userId: String
        let itemId: String
        let amount: Double
        let paymentDate: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case itemId = "item_id"
            case amount
            case paymentDate = "payment_date"
        }
    }

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Read

    func getPayments(itemId: String? = nil) async throws -> [Payment] {
        do {
            return try await queryPayments(itemId: itemId, orderBy: "paid_date")
        } catch {
            guard isMissingColumn(error, column: "paid_date") else {
                throw error
            }

            do {
                // Backward compatibility for schemas using `payment_date` instead of `paid_date`.
                return try await queryPayments(itemId: itemId, orderBy: "payment_date")
            } catch {
                guard isMissingColumn(error, column: "payment_date") else {
                    throw error
                }

                // Last fallback for older rows that only have created_at.
                return try await queryPayments(itemId: itemId, orderBy: "created_at")
            }
        }
    }

    // MARK: - Create

    func recordPayment(userId: String, itemId: String, amount: Double, paidDate: Date) async throws -> Payment {
        let insert = PaymentInsert(
            userId: userId,
            itemId: itemId,
            amount: amount,
            paidDate: DateHelper.formatDate(paidDate)
        )

        do {
            return try await client.from("payments")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
        } catch {
            // Backward compatibility for schemas using `payment_date`.
            if isMissingColumn(error, column: "paid_date") {
                let legacyInsert = LegacyPaymentInsert(
                    userId: userId,
                    itemId: itemId,
                    amount: amount,
                    paymentDate: DateHelper.formatDate(paidDate)
                )

                return try await client.from("payments")
                    .insert(legacyInsert)
                    .select()
                    .single()
                    .execute()
                    .value
            }
            throw error
        }
    }

    // MARK: - Helpers

    private func queryPayments(itemId: String?, orderBy column: String) async throws -> [Payment] {
        if let itemId {
            return try await client.from("payments")
                .select()
                .eq("item_id", value: itemId)
                .order(column, ascending: false)
                .execute()
                .value
        }

        return try await client.from("payments")
            .select()
            .order(column, ascending: false)
            .execute()
            .value
    }

    private func isMissingColumn(_ error: Error, column: String) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("column")
            && text.contains("payments.\(column.lowercased())")
            && text.contains("does not exist")
    }
}
