import XCTest
@testable import SubTrkr

final class ItemEffectiveDateTests: XCTestCase {
    func testReactivationPrefersEffectiveCancellationDateOverCancelledAtAuditTimestamp() throws {
        let item = makeItem(
            status: .cancelled,
            cancellationDate: "2026-03-10",
            cancelledAt: "2026-03-12T15:30:00.000Z"
        )

        let minimumDate = try XCTUnwrap(item.minimumEffectiveDate(for: "reactivate"))

        XCTAssertEqual(DateHelper.formatDate(minimumDate), "2026-03-10")
    }

    func testReactivationFallsBackToCancelledAtWhenNoEffectiveCancellationDateExists() throws {
        let item = makeItem(
            status: .cancelled,
            cancellationDate: nil,
            cancelledAt: "2026-03-12T15:30:00.000Z"
        )

        let minimumDate = try XCTUnwrap(item.minimumEffectiveDate(for: "reactivate"))

        XCTAssertEqual(DateHelper.formatDate(minimumDate), "2026-03-12")
    }

    func testArchivedReactivationStillUsesArchiveTimestampAsLowerBound() throws {
        let item = makeItem(
            status: .archived,
            cancellationDate: "2026-03-10",
            cancelledAt: "2026-03-12T15:30:00.000Z",
            archivedAt: "2026-03-15T09:00:00.000Z"
        )

        let minimumDate = try XCTUnwrap(item.minimumEffectiveDate(for: "reactivate"))

        XCTAssertEqual(DateHelper.formatDate(minimumDate), "2026-03-15")
    }

    private func makeItem(
        status: ItemStatus,
        cancellationDate: String?,
        cancelledAt: String?,
        archivedAt: String? = nil
    ) -> Item {
        Item(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            name: "Test Item",
            amount: 12.99,
            currency: "USD",
            billingCycle: .monthly,
            categoryId: nil,
            startDate: "2026-03-01",
            nextBillingDate: "2026-03-01",
            reminderDays: nil,
            notes: nil,
            url: nil,
            logoUrl: nil,
            itemType: .subscription,
            status: status,
            pausedAt: nil,
            pausedUntil: nil,
            cancelledAt: cancelledAt,
            cancellationDate: cancellationDate,
            archivedAt: archivedAt,
            trialStartedAt: nil,
            trialEndDate: nil,
            isActive: nil,
            createdAt: DateHelper.formatISO8601(Date.now),
            updatedAt: DateHelper.formatISO8601(Date.now),
            categories: nil
        )
    }
}
