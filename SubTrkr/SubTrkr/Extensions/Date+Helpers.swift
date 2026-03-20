import Foundation

enum DateHelper {
    private static var fixedTodayOverride: Date? {
        guard let raw = ProcessInfo.processInfo.environment["SUBTRKR_FIXED_TODAY"] else { return nil }
        return parseDate(raw) ?? parseISO8601(raw)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func parseISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FallbackFormatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func formatISO8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func formatMediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func formatShortMonth(_ date: Date) -> String {
        shortMonthFormatter.string(from: date)
    }

    static func formatYearMonth(_ date: Date) -> String {
        yearMonthFormatter.string(from: date)
    }

    static func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = startOfToday()
        let startOfDate = startOfDay(date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDate).day ?? 0

        switch days {
        case ..<0:
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue"
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case 2...7:
            return "In \(days) days"
        case 8...30:
            let weeks = days / 7
            return "In \(weeks) week\(weeks == 1 ? "" : "s")"
        default:
            return formatMediumDate(date)
        }
    }

    static func startOfToday() -> Date {
        if let fixedTodayOverride {
            return startOfDay(fixedTodayOverride)
        }

        return startOfDay(.now)
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func isBeforeToday(_ date: Date) -> Bool {
        startOfDay(date) < startOfToday()
    }

    static func isBeforeDay(_ lhs: Date, than rhs: Date) -> Bool {
        startOfDay(lhs) < startOfDay(rhs)
    }

    static func isOnOrBeforeDay(_ lhs: Date, comparedTo rhs: Date) -> Bool {
        startOfDay(lhs) <= startOfDay(rhs)
    }

    static func isConsistentRecurringDate(_ scheduledDate: Date, withAnchor anchorDate: Date, cycle: BillingCycle) -> Bool {
        let calendar = Calendar.current

        switch cycle {
        case .weekly:
            return calendar.component(.weekday, from: scheduledDate) == calendar.component(.weekday, from: anchorDate)

        case .monthly:
            return calendar.component(.day, from: scheduledDate)
                == clampedDay(for: anchorDate, inMonthOf: scheduledDate, calendar: calendar)

        case .quarterly:
            let monthDifference = monthsBetween(anchorDate, and: scheduledDate, calendar: calendar)
            guard monthDifference >= 0, monthDifference.isMultiple(of: 3) else { return false }
            return calendar.component(.day, from: scheduledDate)
                == clampedDay(for: anchorDate, inMonthOf: scheduledDate, calendar: calendar)

        case .yearly:
            guard calendar.component(.month, from: scheduledDate) == calendar.component(.month, from: anchorDate) else {
                return false
            }
            return calendar.component(.day, from: scheduledDate)
                == clampedDay(for: anchorDate, inMonthOf: scheduledDate, calendar: calendar)
        }
    }

    static func advanceDate(_ date: Date, by cycle: BillingCycle, anchorDate: Date? = nil) -> Date {
        let calendar = Calendar.current
        switch cycle {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date

        case .monthly:
            guard let targetMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return date }
            return anchoredDate(inSameMonthAs: targetMonth, anchorDate: anchorDate ?? date, calendar: calendar) ?? targetMonth

        case .quarterly:
            guard let targetMonth = calendar.date(byAdding: .month, value: 3, to: date) else { return date }
            return anchoredDate(inSameMonthAs: targetMonth, anchorDate: anchorDate ?? date, calendar: calendar) ?? targetMonth

        case .yearly:
            guard let targetYear = calendar.date(byAdding: .year, value: 1, to: date) else { return date }
            return anchoredDate(inSameMonthAs: targetYear, anchorDate: anchorDate ?? date, calendar: calendar) ?? targetYear
        }
    }

    static func nextRecurringDate(anchorDate: Date, cycle: BillingCycle, onOrAfter referenceDate: Date) -> Date {
        nextRecurringDate(anchorDate: anchorDate, cycle: cycle, referenceDate: referenceDate, strictlyAfter: false)
    }

    static func nextRecurringDate(anchorDate: Date, cycle: BillingCycle, strictlyAfter referenceDate: Date) -> Date {
        nextRecurringDate(anchorDate: anchorDate, cycle: cycle, referenceDate: referenceDate, strictlyAfter: true)
    }

    static func recurringDates(anchorDate: Date, cycle: BillingCycle, in interval: DateInterval) -> [Date] {
        guard interval.duration > 0 else { return [] }

        let normalizedAnchor = startOfDay(anchorDate)
        let intervalStart = startOfDay(interval.start)
        let intervalEnd = interval.end

        var dates: [Date] = []
        var current = nextRecurringDate(anchorDate: normalizedAnchor, cycle: cycle, onOrAfter: intervalStart)
        var iterations = 0
        let maxIterations = 520

        while current < intervalEnd, iterations < maxIterations {
            dates.append(current)
            current = nextRecurringDate(anchorDate: normalizedAnchor, cycle: cycle, strictlyAfter: current)
            iterations += 1
        }

        return dates
    }

    static func nextFutureBillingDate(from anchorDate: Date, by cycle: BillingCycle, referenceDate: Date = .now) -> Date {
        nextRecurringDate(anchorDate: anchorDate, cycle: cycle, strictlyAfter: referenceDate)
    }

    private static func nextRecurringDate(anchorDate: Date,
                                          cycle: BillingCycle,
                                          referenceDate: Date,
                                          strictlyAfter: Bool) -> Date {
        let normalizedAnchor = startOfDay(anchorDate)
        let normalizedReference = startOfDay(referenceDate)

        if strictlyAfter {
            if normalizedAnchor > normalizedReference {
                return normalizedAnchor
            }
        } else if normalizedAnchor >= normalizedReference {
            return normalizedAnchor
        }

        var occurrence = max(0, lowerBoundOccurrenceIndex(
            for: cycle,
            anchorDate: normalizedAnchor,
            referenceDate: normalizedReference
        ))
        var candidate = recurringDate(anchorDate: normalizedAnchor, cycle: cycle, occurrence: occurrence)
        var iterations = 0
        let maxIterations = 520

        while shouldAdvance(candidate, referenceDate: normalizedReference, strictlyAfter: strictlyAfter),
              iterations < maxIterations {
            occurrence += 1
            candidate = recurringDate(anchorDate: normalizedAnchor, cycle: cycle, occurrence: occurrence)
            iterations += 1
        }

        return candidate
    }

    private static func lowerBoundOccurrenceIndex(for cycle: BillingCycle,
                                                  anchorDate: Date,
                                                  referenceDate: Date) -> Int {
        let calendar = Calendar.current

        switch cycle {
        case .weekly:
            let dayDifference = calendar.dateComponents([.day], from: anchorDate, to: referenceDate).day ?? 0
            return max(0, dayDifference / 7)

        case .monthly:
            return max(0, monthsBetween(anchorDate, and: referenceDate, calendar: calendar))

        case .quarterly:
            return max(0, monthsBetween(anchorDate, and: referenceDate, calendar: calendar) / 3)

        case .yearly:
            let anchorYear = calendar.component(.year, from: anchorDate)
            let referenceYear = calendar.component(.year, from: referenceDate)
            return max(0, referenceYear - anchorYear)
        }
    }

    private static func recurringDate(anchorDate: Date, cycle: BillingCycle, occurrence: Int) -> Date {
        let calendar = Calendar.current
        let normalizedAnchor = startOfDay(anchorDate)

        switch cycle {
        case .weekly:
            return calendar.date(byAdding: .day, value: occurrence * 7, to: normalizedAnchor) ?? normalizedAnchor

        case .monthly:
            guard let targetMonth = calendar.date(byAdding: .month, value: occurrence, to: normalizedAnchor) else {
                return normalizedAnchor
            }
            return anchoredDate(inSameMonthAs: targetMonth, anchorDate: normalizedAnchor, calendar: calendar) ?? targetMonth

        case .quarterly:
            guard let targetMonth = calendar.date(byAdding: .month, value: occurrence * 3, to: normalizedAnchor) else {
                return normalizedAnchor
            }
            return anchoredDate(inSameMonthAs: targetMonth, anchorDate: normalizedAnchor, calendar: calendar) ?? targetMonth

        case .yearly:
            let components = calendar.dateComponents([.year, .month], from: normalizedAnchor)
            guard let anchorYear = components.year, let anchorMonth = components.month else {
                return normalizedAnchor
            }

            let targetYear = anchorYear + occurrence
            guard let targetMonth = calendar.date(from: DateComponents(year: targetYear, month: anchorMonth, day: 1)) else {
                return normalizedAnchor
            }

            return anchoredDate(inSameMonthAs: targetMonth, anchorDate: normalizedAnchor, calendar: calendar) ?? targetMonth
        }
    }

    private static func shouldAdvance(_ candidate: Date, referenceDate: Date, strictlyAfter: Bool) -> Bool {
        if strictlyAfter {
            return isOnOrBeforeDay(candidate, comparedTo: referenceDate)
        }

        return isBeforeDay(candidate, than: referenceDate)
    }

    private static func anchoredDate(inSameMonthAs targetDate: Date, anchorDate: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: targetDate)
        guard let year = components.year, let month = components.month else { return nil }

        let day = clampedDay(for: anchorDate, inMonthOf: targetDate, calendar: calendar)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func clampedDay(for anchorDate: Date, inMonthOf targetDate: Date, calendar: Calendar) -> Int {
        let anchorDay = calendar.component(.day, from: anchorDate)
        guard let dayRange = calendar.range(of: .day, in: .month, for: targetDate) else { return anchorDay }
        return min(anchorDay, dayRange.count)
    }

    private static func monthsBetween(_ startDate: Date, and endDate: Date, calendar: Calendar) -> Int {
        let start = calendar.dateComponents([.year, .month], from: startDate)
        let end = calendar.dateComponents([.year, .month], from: endDate)
        guard let startYear = start.year,
              let startMonth = start.month,
              let endYear = end.year,
              let endMonth = end.month else {
            return 0
        }

        return ((endYear - startYear) * 12) + (endMonth - startMonth)
    }
}
