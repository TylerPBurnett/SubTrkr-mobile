import Foundation

@Observable
final class SettingsViewModel {
    private let categoryService = CategoryService()
    private let notificationService = NotificationService()

    var categories: [Category] = []
    var notificationChannels: [NotificationChannel] = []
    var notificationPreferences: NotificationPreferences?
    var isLoading = false
    var error: String?

    // Category editing
    var editingCategory: Category?
    var newCategoryName = ""
    var newCategoryColor = "#6366f1"
    var newCategoryType: ItemType = .subscription

    var subscriptionCategories: [Category] {
        categories.filter { $0.type == ItemType.subscription.rawValue || $0.type == nil }
    }

    var billCategories: [Category] {
        categories.filter { $0.type == ItemType.bill.rawValue }
    }

    // MARK: - Load

    func loadData() async {
        isLoading = true
        do {
            categories = try await categoryService.getCategories()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadNotifications() async {
        do {
            notificationChannels = try await notificationService.getNotificationChannels()
            notificationPreferences = try await notificationService.getNotificationPreferences()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Category CRUD

    func createCategory(userId: String) async {
        guard !newCategoryName.isEmpty else {
            error = "Category name is required"
            return
        }

        isLoading = true
        do {
            let insert = CategoryInsert(
                id: UUID().uuidString,
                userId: userId,
                name: newCategoryName,
                color: newCategoryColor,
                icon: nil,
                type: newCategoryType.rawValue
            )
            let category = try await categoryService.createCategory(insert)
            categories.append(category)
            newCategoryName = ""
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func updateCategory(_ category: Category) async {
        isLoading = true
        do {
            let update = CategoryUpdate(
                name: category.name,
                color: category.color,
                icon: category.icon,
                type: category.type
            )
            let updated = try await categoryService.updateCategory(id: category.id, data: update)
            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                categories[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteCategory(_ category: Category) async {
        isLoading = true
        do {
            try await categoryService.deleteCategory(id: category.id)
            categories.removeAll { $0.id == category.id }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func seedDefaults(userId: String) async {
        do {
            try await categoryService.seedDefaultCategories(userId: userId)
            categories = try await categoryService.getCategories()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
