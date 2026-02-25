import Foundation
import Supabase

final class CategoryService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Read

    func getCategories(type: ItemType? = nil) async throws -> [Category] {
        if let type {
            return try await client.from("categories")
                .select()
                .eq("type", value: type.rawValue)
                .order("name", ascending: true)
                .execute()
                .value
        }

        return try await client.from("categories")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Create

    func createCategory(_ data: CategoryInsert) async throws -> Category {
        return try await client.from("categories")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Update

    func updateCategory(id: String, data: CategoryUpdate) async throws -> Category {
        return try await client.from("categories")
            .update(data)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Delete

    func deleteCategory(id: String) async throws {
        try await client.from("categories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Seed Defaults

    func seedDefaultCategories(userId: String) async throws {
        let existing = try await getCategories()
        guard existing.isEmpty else { return }

        var inserts: [CategoryInsert] = []

        for cat in Category.defaultSubscriptionCategories {
            inserts.append(CategoryInsert(
                id: UUID().uuidString,
                userId: userId,
                name: cat.name,
                color: cat.color,
                icon: nil,
                type: ItemType.subscription.rawValue
            ))
        }

        for cat in Category.defaultBillCategories {
            inserts.append(CategoryInsert(
                id: UUID().uuidString,
                userId: userId,
                name: cat.name,
                color: cat.color,
                icon: nil,
                type: ItemType.bill.rawValue
            ))
        }

        try await client.from("categories")
            .insert(inserts)
            .execute()
    }
}
