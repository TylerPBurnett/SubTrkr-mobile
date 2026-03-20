import XCTest
@testable import SubTrkr

final class RecurringBillingTests: XCTestCase {
    func testMonthlyRecurringDateRecoversAfterShortMonth() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-01-31"))
        let reference = try XCTUnwrap(DateHelper.parseDate("2026-03-01"))

        let nextDate = DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, onOrAfter: reference)

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-03-31")
    }

    func testMonthlyRecurringDatePreserves30thOfMonthAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-01-30"))
        let intervalStart = try XCTUnwrap(DateHelper.parseDate("2026-02-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2026-05-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .monthly,
            in: DateInterval(start: intervalStart, end: intervalEnd)
        )

        XCTAssertEqual(dates.map(DateHelper.formatDate), [
            "2026-02-28",
            "2026-03-30",
            "2026-04-30"
        ])
    }

    func testQuarterlyRecurringDatePreservesEndOfMonthAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-01-31"))
        let intervalStart = try XCTUnwrap(DateHelper.parseDate("2026-04-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2027-01-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .quarterly,
            in: DateInterval(start: intervalStart, end: intervalEnd)
        )

        XCTAssertEqual(dates.map(DateHelper.formatDate), [
            "2026-04-30",
            "2026-07-31",
            "2026-10-31"
        ])
    }

    func testYearlyRecurringDatePreservesLeapDayAcrossLeapCycle() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2024-02-29"))
        let reference = try XCTUnwrap(DateHelper.parseDate("2027-03-01"))

        let nextDate = DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .yearly, onOrAfter: reference)

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2028-02-29")
    }

    func testYearlyRecurringDateClampsLeapDayDuringNonLeapYears() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2024-02-29"))

        XCTAssertEqual(
            DateHelper.formatDate(
                DateHelper.nextRecurringDate(
                    anchorDate: anchor,
                    cycle: .yearly,
                    onOrAfter: try XCTUnwrap(DateHelper.parseDate("2025-01-01"))
                )
            ),
            "2025-02-28"
        )
        XCTAssertEqual(
            DateHelper.formatDate(
                DateHelper.nextRecurringDate(
                    anchorDate: anchor,
                    cycle: .yearly,
                    onOrAfter: try XCTUnwrap(DateHelper.parseDate("2026-01-01"))
                )
            ),
            "2026-02-28"
        )
        XCTAssertEqual(
            DateHelper.formatDate(
                DateHelper.nextRecurringDate(
                    anchorDate: anchor,
                    cycle: .yearly,
                    onOrAfter: try XCTUnwrap(DateHelper.parseDate("2027-01-01"))
                )
            ),
            "2027-02-28"
        )
    }

    func testOnOrAfterReturnsAnchorWhenReferenceMatchesAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-08"))

        let nextDate = DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, onOrAfter: anchor)

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-03-08")
    }

    func testStrictlyAfterSkipsAnchorWhenReferenceMatchesAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-08"))

        let nextDate = DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, strictlyAfter: anchor)

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-04-08")
    }

    func testNextRecurringDateReturnsFutureAnchorUnchanged() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-05-10"))
        let reference = try XCTUnwrap(DateHelper.parseDate("2026-04-01"))

        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, onOrAfter: reference)),
            "2026-05-10"
        )
        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, strictlyAfter: reference)),
            "2026-05-10"
        )
    }

    func testRecurringDatesProjectsMonthWithoutDrift() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-01-31"))
        let intervalStart = try XCTUnwrap(DateHelper.parseDate("2026-02-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2026-06-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .monthly,
            in: DateInterval(start: intervalStart, end: intervalEnd)
        )

        XCTAssertEqual(dates.map(DateHelper.formatDate), [
            "2026-02-28",
            "2026-03-31",
            "2026-04-30",
            "2026-05-31"
        ])
    }

    func testRecurringDatesReturnsEmptyForZeroDurationInterval() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-15"))
        let boundary = try XCTUnwrap(DateHelper.parseDate("2026-03-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .monthly,
            in: DateInterval(start: boundary, end: boundary)
        )

        XCTAssertEqual(dates, [])
    }

    func testRecurringDatesIncludesAnchorWhenIntervalStartsBeforeAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-15"))
        let intervalStart = try XCTUnwrap(DateHelper.parseDate("2026-03-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2026-04-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .monthly,
            in: DateInterval(start: intervalStart, end: intervalEnd)
        )

        XCTAssertEqual(dates.map(DateHelper.formatDate), ["2026-03-15"])
    }

    func testRecurringDatesProjectsLeapPatternAcrossMultipleYears() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2024-02-29"))
        let intervalStart = try XCTUnwrap(DateHelper.parseDate("2024-01-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2030-01-01"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .yearly,
            in: DateInterval(start: intervalStart, end: intervalEnd)
        )

        XCTAssertEqual(dates.map(DateHelper.formatDate), [
            "2024-02-29",
            "2025-02-28",
            "2026-02-28",
            "2027-02-28",
            "2028-02-29",
            "2029-02-28"
        ])
    }

    func testWeeklyRecurringDatesKeepSameWeekdayAcrossProjection() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-01"))
        let intervalEnd = try XCTUnwrap(DateHelper.parseDate("2026-05-11"))

        let dates = DateHelper.recurringDates(
            anchorDate: anchor,
            cycle: .weekly,
            in: DateInterval(start: anchor, end: intervalEnd)
        )

        XCTAssertEqual(
            Set(dates.map { Calendar.current.component(.weekday, from: $0) }),
            [Calendar.current.component(.weekday, from: anchor)]
        )
        XCTAssertEqual(dates.count, 11)
    }

    func testNextRecurringDateFindsCorrectDateForFarPastAnchor() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2020-01-31"))
        let reference = try XCTUnwrap(DateHelper.parseDate("2026-03-19"))

        let nextDate = DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, onOrAfter: reference)

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-03-31")
    }

    func testNextRecurringDateSupportsEachBillingCycle() throws {
        let anchor = try XCTUnwrap(DateHelper.parseDate("2026-03-19"))

        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .weekly, strictlyAfter: anchor)),
            "2026-03-26"
        )
        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .monthly, strictlyAfter: anchor)),
            "2026-04-19"
        )
        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .quarterly, strictlyAfter: anchor)),
            "2026-06-19"
        )
        XCTAssertEqual(
            DateHelper.formatDate(DateHelper.nextRecurringDate(anchorDate: anchor, cycle: .yearly, strictlyAfter: anchor)),
            "2027-03-19"
        )
    }

    func testBillingAnchorPrefersStartDateEvenWhenStoredNextBillingDateHasDrifted() {
        let item = makeItem(
            startDate: "2026-01-31",
            nextBillingDate: "2026-03-28"
        )

        XCTAssertEqual(DateHelper.formatDate(item.billingAnchorDate!), "2026-01-31")
    }

    func testBillingAnchorFallsBackToCreatedAtWhenDatesAreMissing() {
        let item = makeItem(
            startDate: nil,
            nextBillingDate: nil,
            createdAt: "2026-03-03T15:45:12Z"
        )

        XCTAssertEqual(DateHelper.formatDate(item.billingAnchorDate!), "2026-03-03")
    }

    func testMaintenanceLeavesDueTodayUnchanged() throws {
        let today = try XCTUnwrap(DateHelper.parseDate("2026-03-08"))
        let item = makeItem(
            startDate: "2026-02-08",
            nextBillingDate: "2026-03-08"
        )

        XCTAssertNil(item.nextBillingDateForMaintenance(referenceDate: today))
    }

    func testMaintenanceRecoversEndOfMonthAnchor() throws {
        let referenceDate = try XCTUnwrap(DateHelper.parseDate("2026-03-15"))
        let item = makeItem(
            startDate: "2026-01-31",
            nextBillingDate: "2026-02-28"
        )

        let nextDate = try XCTUnwrap(item.nextBillingDateForMaintenance(referenceDate: referenceDate))

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-03-31")
    }

    func testMaintenanceFallsBackToStoredNextBillingDateWhenStartDateIsMissing() throws {
        let referenceDate = try XCTUnwrap(DateHelper.parseDate("2026-03-15"))
        let item = makeItem(
            startDate: nil,
            nextBillingDate: "2026-02-28"
        )

        let nextDate = try XCTUnwrap(item.nextBillingDateForMaintenance(referenceDate: referenceDate))

        XCTAssertEqual(DateHelper.formatDate(nextDate), "2026-03-28")
    }

    @MainActor
    func testItemFormAutoCalculationUsesNextRecurringDateForTodayAnchors() throws {
        let viewModel = ItemFormViewModel(itemType: .subscription)
        let today = DateHelper.startOfToday()
        let expected = DateHelper.nextRecurringDate(anchorDate: today, cycle: .monthly, strictlyAfter: today)

        viewModel.startDate = today
        viewModel.billingCycle = .monthly
        viewModel.userEditedNextBillingDate = false

        viewModel.autoCalcNextBillingDate()

        XCTAssertEqual(DateHelper.formatDate(viewModel.nextBillingDate), DateHelper.formatDate(expected))
    }

    @MainActor
    func testFutureStartDateRecalculationIsNotBlockedByPreviousAutoFill() throws {
        let viewModel = ItemFormViewModel(itemType: .subscription)
        let today = DateHelper.startOfToday()
        let futureStartDate = try XCTUnwrap(DateHelper.parseDate("2026-03-31"))

        viewModel.startDate = today
        viewModel.billingCycle = .monthly
        viewModel.userEditedNextBillingDate = false
        viewModel.autoCalcNextBillingDate()

        XCTAssertFalse(viewModel.userEditedNextBillingDate)

        viewModel.startDate = futureStartDate
        viewModel.autoCalcNextBillingDate()

        XCTAssertEqual(DateHelper.formatDate(viewModel.nextBillingDate), "2026-03-31")
    }

    private func makeItem(startDate: String?, nextBillingDate: String?, createdAt: String? = DateHelper.formatISO8601(Date.now)) -> Item {
        Item(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            name: "Test Item",
            amount: 12.99,
            currency: "USD",
            billingCycle: .monthly,
            categoryId: nil,
            startDate: startDate,
            nextBillingDate: nextBillingDate,
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
            createdAt: createdAt,
            updatedAt: createdAt,
            categories: nil
        )
    }
}
