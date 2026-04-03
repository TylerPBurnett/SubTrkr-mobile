import XCTest
@testable import SubTrkr

@MainActor
final class ItemListViewModelTests: XCTestCase {
    func testDescendingPriceSortUsesDeterministicTieBreak() {
        let viewModel = ItemListViewModel(itemType: .subscription)
        viewModel.items = [
            makeItem(id: "b-item", name: "Bravo", amount: 9.99),
            makeItem(id: "a-item", name: "Alpha", amount: 9.99),
        ]
        viewModel.sortOption = .price
        viewModel.sortAscending = false

        XCTAssertEqual(viewModel.filteredItems.map(\.id), ["a-item", "b-item"])
    }

    private func makeItem(id: String, name: String, amount: Double) -> Item {
        Item(
            id: id,
            userId: UUID().uuidString,
            name: name,
            amount: amount,
            currency: "USD",
            billingCycle: .monthly,
            categoryId: nil,
            startDate: "2026-03-01",
            nextBillingDate: "2026-03-15",
            reminderDays: nil,
            notes: nil,
            url: nil,
            logoUrl: nil,
            itemType: .subscription,
            status: .active,
            pausedAt: nil,
            pausedUntil: nil,
            cancelledAt: nil,
            cancellationDate: nil,
            archivedAt: nil,
            trialStartedAt: nil,
            trialEndDate: nil,
            isActive: nil,
            createdAt: DateHelper.formatISO8601(Date.now),
            updatedAt: DateHelper.formatISO8601(Date.now),
            categories: nil
        )
    }
}
