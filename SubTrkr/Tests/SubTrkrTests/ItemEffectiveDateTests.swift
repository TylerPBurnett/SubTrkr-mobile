import XCTest
@testable import SubTrkr

final class ItemEffectiveDateTests: XCTestCase {
    func testHistoricalEffectiveDateNormalizationTreatsTodayAsValidCancellationDate() throws {
        let today = try XCTUnwrap(DateHelper.parseDate("2026-03-24"))
        let selectedDate = Calendar.current.date(
            bySettingHour: 21,
            minute: 45,
            second: 0,
            of: today
        )

        let resolvedDate = try ItemService.normalizeHistoricalEffectiveDate(
            selectedDate,
            today: today,
            futureDateError: .futureCancellationDateUnsupported
        )

        XCTAssertEqual(DateHelper.formatDate(resolvedDate), "2026-03-24")
        XCTAssertEqual(resolvedDate, DateHelper.startOfDay(today))
    }

    func testHistoricalEffectiveDateNormalizationRejectsFutureCancellationDate() throws {
        let today = try XCTUnwrap(DateHelper.parseDate("2026-03-24"))
        let tomorrow = try XCTUnwrap(DateHelper.parseDate("2026-03-25"))

        XCTAssertThrowsError(
            try ItemService.normalizeHistoricalEffectiveDate(
                tomorrow,
                today: today,
                futureDateError: .futureCancellationDateUnsupported
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                ItemService.ItemServiceError.futureCancellationDateUnsupported.localizedDescription
            )
        }
    }

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

    func testArchiveActionIsOnlyAvailableFromCancelledStatus() {
        XCTAssertFalse(ItemStatus.active.availableActions.contains("archive"))
        XCTAssertFalse(ItemStatus.paused.availableActions.contains("archive"))
        XCTAssertTrue(ItemStatus.cancelled.availableActions.contains("archive"))
        XCTAssertFalse(ItemStatus.trial.availableActions.contains("archive"))
        XCTAssertFalse(ItemStatus.archived.availableActions.contains("archive"))
    }

    func testNotificationReminderDaysPrefersItemOverride() {
        let item = makeItem(
            status: .active,
            cancellationDate: nil,
            cancelledAt: nil,
            reminderDays: 14
        )

        XCTAssertEqual(item.notificationReminderDays(fallback: 3), 14)
    }

    func testNotificationReminderDaysFallsBackToGlobalDefault() {
        let item = makeItem(
            status: .active,
            cancellationDate: nil,
            cancelledAt: nil,
            reminderDays: nil
        )

        XCTAssertEqual(item.notificationReminderDays(fallback: 7), 7)
        XCTAssertEqual(item.notificationReminderDays(fallback: 0), 3)
    }

    private func makeItem(
        status: ItemStatus,
        cancellationDate: String?,
        cancelledAt: String?,
        archivedAt: String? = nil,
        reminderDays: Int? = nil
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
            reminderDays: reminderDays,
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
