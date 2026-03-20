import XCTest
@testable import SubTrkr

final class AnalyticsServiceTests: XCTestCase {
    private let analyticsService = AnalyticsService()

    func testConvertedTrialDoesNotCountBeforeConversion() {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date.now))!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: monthStart)!

        let item = makeItem(
            status: .active,
            startDate: DateHelper.formatDate(twoMonthsAgo)
        )

        let history = [
            makeHistoryEntry(
                itemId: item.id,
                status: .active,
                action: "convert_trial",
                effectiveDate: DateHelper.formatDate(monthStart)
            )
        ]

        let trend = analyticsService.reconstructMonthlySpending(
            items: [item],
            payments: [],
            statusHistoryByItem: [item.id: history],
            months: 3
        )

        assertEqual(trend.map(\.total), [0, 0, 12.99], accuracy: 0.001)
    }

    func testReactivatedItemCountsOnlyAfterEffectiveReactivationMonth() {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date.now))!
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: monthStart)!

        let item = makeItem(
            status: .active,
            startDate: DateHelper.formatDate(twoMonthsAgo)
        )

        let history = [
            makeHistoryEntry(
                itemId: item.id,
                status: .cancelled,
                action: "cancel",
                effectiveDate: DateHelper.formatDate(oneMonthAgo)
            ),
            makeHistoryEntry(
                itemId: item.id,
                status: .active,
                action: "reactivate",
                effectiveDate: DateHelper.formatDate(monthStart)
            )
        ]

        let trend = analyticsService.reconstructMonthlySpending(
            items: [item],
            payments: [],
            statusHistoryByItem: [item.id: history],
            months: 3
        )

        assertEqual(trend.map(\.total), [12.99, 0, 12.99], accuracy: 0.001)
    }

    func testHistoryMetadataRoundTripsUserNotes() {
        let encodedNotes = StatusHistoryMetadataCodec.encode(
            metadata: StatusHistoryMetadata(action: "reactivate", effectiveDate: "2026-03-01"),
            userNotes: "User added context"
        )

        let history = StatusHistory(
            id: UUID().uuidString,
            itemId: UUID().uuidString,
            userId: UUID().uuidString,
            status: .active,
            reason: "Back on plan",
            notes: encodedNotes,
            action: nil,
            effectiveDate: nil,
            changedAt: DateHelper.formatISO8601(Date.now)
        )

        XCTAssertEqual(history.metadata?.action, "reactivate")
        XCTAssertEqual(history.metadata?.effectiveDate, "2026-03-01")
        XCTAssertEqual(history.userNotes, "User added context")
    }

    func testHistoryPrefersFirstClassColumnsBeforeMetadataFallback() {
        let encodedNotes = StatusHistoryMetadataCodec.encode(
            metadata: StatusHistoryMetadata(action: "cancel", effectiveDate: "2026-02-01"),
            userNotes: "Legacy payload"
        )

        let history = StatusHistory(
            id: UUID().uuidString,
            itemId: UUID().uuidString,
            userId: UUID().uuidString,
            status: .active,
            reason: nil,
            notes: encodedNotes,
            action: "reactivate",
            effectiveDate: "2026-03-01",
            changedAt: DateHelper.formatISO8601(Date.now)
        )

        XCTAssertEqual(history.resolvedAction, "reactivate")
        XCTAssertEqual(DateHelper.formatDate(history.effectiveDateFormatted!), "2026-03-01")
        XCTAssertEqual(history.userNotes, "Legacy payload")
    }

    func testLegacyMetadataFallbackStillReconstructsConvertedTrialHistory() {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date.now))!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: monthStart)!

        let item = makeItem(
            status: .active,
            startDate: DateHelper.formatDate(twoMonthsAgo)
        )

        let encodedNotes = StatusHistoryMetadataCodec.encode(
            metadata: StatusHistoryMetadata(
                action: "convert_trial",
                effectiveDate: DateHelper.formatDate(monthStart)
            ),
            userNotes: nil
        )

        let history = [
            StatusHistory(
                id: UUID().uuidString,
                itemId: item.id,
                userId: UUID().uuidString,
                status: .active,
                reason: nil,
                notes: encodedNotes,
                action: nil,
                effectiveDate: nil,
                changedAt: DateHelper.formatISO8601(Date.now)
            )
        ]

        let trend = analyticsService.reconstructMonthlySpending(
            items: [item],
            payments: [],
            statusHistoryByItem: [item.id: history],
            months: 3
        )

        assertEqual(trend.map(\.total), [0, 0, 12.99], accuracy: 0.001)
    }

    func testSameDayTransitionsRespectRecordedOrder() {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date.now))!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: monthStart)!

        let item = makeItem(
            status: .active,
            startDate: DateHelper.formatDate(twoMonthsAgo)
        )

        let cancelRecordedAt = calendar.date(byAdding: .hour, value: 9, to: monthStart)!
        let reactivateRecordedAt = calendar.date(byAdding: .hour, value: 10, to: monthStart)!

        let history = [
            StatusHistory(
                id: UUID().uuidString,
                itemId: item.id,
                userId: UUID().uuidString,
                status: .cancelled,
                reason: nil,
                notes: nil,
                action: "cancel",
                effectiveDate: DateHelper.formatDate(monthStart),
                changedAt: DateHelper.formatISO8601(cancelRecordedAt)
            ),
            StatusHistory(
                id: UUID().uuidString,
                itemId: item.id,
                userId: UUID().uuidString,
                status: .active,
                reason: nil,
                notes: nil,
                action: "reactivate",
                effectiveDate: DateHelper.formatDate(monthStart),
                changedAt: DateHelper.formatISO8601(reactivateRecordedAt)
            )
        ]

        let trend = analyticsService.reconstructMonthlySpending(
            items: [item],
            payments: [],
            statusHistoryByItem: [item.id: history],
            months: 1
        )

        assertEqual(trend.map(\.total), [12.99], accuracy: 0.001)
    }

    private func makeItem(status: ItemStatus, startDate: String) -> Item {
        Item(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            name: "Test Item",
            amount: 12.99,
            currency: "USD",
            billingCycle: .monthly,
            categoryId: nil,
            startDate: startDate,
            nextBillingDate: startDate,
            reminderDays: nil,
            notes: nil,
            url: nil,
            logoUrl: nil,
            itemType: .subscription,
            status: status,
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

    private func makeHistoryEntry(itemId: String, status: ItemStatus, action: String, effectiveDate: String) -> StatusHistory {
        StatusHistory(
            id: UUID().uuidString,
            itemId: itemId,
            userId: UUID().uuidString,
            status: status,
            reason: nil,
            notes: nil,
            action: action,
            effectiveDate: effectiveDate,
            changedAt: DateHelper.formatISO8601(Date.now)
        )
    }

    private func assertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)

        for (actual, expected) in zip(lhs, rhs) {
            XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
        }
    }
}
