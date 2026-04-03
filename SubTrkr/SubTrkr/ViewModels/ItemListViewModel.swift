import Foundation
import SwiftUI

@Observable
@MainActor
final class ItemListViewModel {
    private let itemService = ItemService()
    private let categoryService = CategoryService()

    let itemType: ItemType

    var items: [Item] = []
    var categories: [Category] = []
    var isLoading = false
    var error: String?

    // Search & Filter
    var searchText = ""
    var selectedCategoryIds: Set<String> = []
    var selectedStatuses: Set<ItemStatus> = [.active, .trial]
    var sortOption: SortOption = .nextBillingDate
    var sortAscending = true

    init(itemType: ItemType) {
        self.itemType = itemType
    }

    // MARK: - Filtered & Sorted Items

    var filteredItems: [Item] {
        var result = items

        // Filter by type
        result = result.filter { $0.itemType == itemType }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        // Category filter
        if !selectedCategoryIds.isEmpty {
            result = result.filter { item in
                guard let catId = item.categoryId else { return false }
                return selectedCategoryIds.contains(catId)
            }
        }

        // Status filter
        if !selectedStatuses.isEmpty {
            result = result.filter { selectedStatuses.contains($0.status) }
        }

        // Sort
        result.sort { a, b in
            let comparison = sortComparison(lhs: a, rhs: b)

            if comparison == .orderedSame {
                return a.id < b.id
            }

            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return result
    }

    var activeTotal: Double {
        items
            .filter { $0.itemType == itemType && $0.status == .active }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var relevantCategories: [Category] {
        categories.filter { $0.type == itemType.rawValue || $0.type == nil }
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let fetchedItems = itemService.getItems(type: itemType)
            async let fetchedCategories = categoryService.getCategories()
            let (i, c) = try await (fetchedItems, fetchedCategories)
            items = i
            categories = c
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteItem(_ item: Item) async {
        do {
            try await itemService.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleStatus(_ status: ItemStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }

    func clearFilters() {
        searchText = ""
        selectedCategoryIds = []
        selectedStatuses = [.active, .trial]
        sortOption = .nextBillingDate
        sortAscending = true
    }

    private func sortComparison(lhs: Item, rhs: Item) -> ComparisonResult {
        switch sortOption {
        case .nextBillingDate:
            return compare(lhs.nextBillingDateFormatted ?? .distantFuture, rhs.nextBillingDateFormatted ?? .distantFuture)
        case .name:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case .price:
            return compare(lhs.amount, rhs.amount)
        case .category:
            return lhs.categoryName.localizedCaseInsensitiveCompare(rhs.categoryName)
        case .status:
            return lhs.status.rawValue.localizedCaseInsensitiveCompare(rhs.status.rawValue)
        }
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }

        if lhs > rhs {
            return .orderedDescending
        }

        return .orderedSame
    }
}
