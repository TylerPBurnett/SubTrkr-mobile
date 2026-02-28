import Foundation

struct CalendarDay: Identifiable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

@Observable
@MainActor
final class CalendarViewModel {
    private let itemService: ItemService
    private var hasLoadedInitially = false

    var items: [Item] = []
    var isLoading = false
    var error: String?
    var displayedMonth: Date
    var selectedDate: Date

    // Cached stored properties — recomputed via recomputeCalendar()
    private(set) var calendarDays: [CalendarDay] = []
    private(set) var itemsByDay: [Int: [Item]] = [:]
    private(set) var monthTotal: Double = 0
    private(set) var monthItemCount: Int = 0
    private(set) var selectedDayItems: [Item] = []

    // MARK: - Static DateFormatters

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let dayDetailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    // MARK: - Computed Properties

    var monthTitle: String {
        Self.monthYearFormatter.string(from: displayedMonth)
    }

    var selectedDayTitle: String {
        Self.dayDetailFormatter.string(from: selectedDate)
    }

    // MARK: - Init

    init(itemService: ItemService = ItemService()) {
        self.itemService = itemService
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.year, .month], from: now)
        self.displayedMonth = calendar.date(from: components) ?? now
        self.selectedDate = now
    }

    // MARK: - Actions

    func loadData(forceRefresh: Bool = false) async {
        guard !hasLoadedInitially || forceRefresh else { return }
        isLoading = true
        error = nil
        do {
            items = try await itemService.getItems()
            hasLoadedInitially = true
            recomputeCalendar()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func navigateMonth(by offset: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = newMonth

        // Auto-select today if navigating to the current month, otherwise select 1st
        let now = Date.now
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        let newComponents = calendar.dateComponents([.year, .month], from: newMonth)

        if nowComponents.year == newComponents.year && nowComponents.month == newComponents.month {
            selectedDate = now
        } else {
            selectedDate = newMonth // newMonth is already 1st of month
        }

        recomputeCalendar()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        recomputeSelectedDayItems()
    }

    // MARK: - Private Recomputation

    private func recomputeCalendar() {
        calendarDays = buildCalendarDays()
        recomputeItemsByDay()
        recomputeSelectedDayItems()
    }

    private func recomputeSelectedDayItems() {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        let displayedComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard selectedComponents.year == displayedComponents.year,
              selectedComponents.month == displayedComponents.month else {
            selectedDayItems = []
            return
        }
        let day = calendar.component(.day, from: selectedDate)
        selectedDayItems = itemsByDay[day] ?? []
    }

    private func buildCalendarDays() -> [CalendarDay] {
        let calendar = Calendar.current
        let now = Date.now
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)

        // Number of days in the displayed month
        guard let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let daysInMonth = monthRange.count

        // Weekday of the 1st (Sunday = 1, Saturday = 7)
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        // Leading padding days from previous month
        let leadingPadding = firstWeekday - calendar.firstWeekday
        let adjustedLeading = leadingPadding < 0 ? leadingPadding + 7 : leadingPadding

        // Previous month info
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth),
              let prevMonthRange = calendar.range(of: .day, in: .month, for: prevMonth) else { return [] }
        let daysInPrevMonth = prevMonthRange.count
        let prevYear = calendar.component(.year, from: prevMonth)
        let prevMonthNum = calendar.component(.month, from: prevMonth)

        var days: [CalendarDay] = []

        // Previous month's trailing days
        for i in 0..<adjustedLeading {
            let dayNum = daysInPrevMonth - adjustedLeading + 1 + i
            if let date = calendar.date(from: DateComponents(year: prevYear, month: prevMonthNum, day: dayNum)) {
                let isToday = todayComponents.year == prevYear
                    && todayComponents.month == prevMonthNum
                    && todayComponents.day == dayNum
                days.append(CalendarDay(
                    id: "\(prevYear)-\(prevMonthNum)-\(dayNum)",
                    date: date,
                    dayNumber: dayNum,
                    isCurrentMonth: false,
                    isToday: isToday
                ))
            }
        }

        // Current month days
        for dayNum in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNum)) {
                let isToday = todayComponents.year == year
                    && todayComponents.month == month
                    && todayComponents.day == dayNum
                days.append(CalendarDay(
                    id: "\(year)-\(month)-\(dayNum)",
                    date: date,
                    dayNumber: dayNum,
                    isCurrentMonth: true,
                    isToday: isToday
                ))
            }
        }

        // Next month's leading days to fill the final week
        let totalSoFar = days.count
        let remainder = totalSoFar % 7
        if remainder > 0 {
            let trailingCount = 7 - remainder
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return days }
            let nextYear = calendar.component(.year, from: nextMonth)
            let nextMonthNum = calendar.component(.month, from: nextMonth)

            for dayNum in 1...trailingCount {
                if let date = calendar.date(from: DateComponents(year: nextYear, month: nextMonthNum, day: dayNum)) {
                    let isToday = todayComponents.year == nextYear
                        && todayComponents.month == nextMonthNum
                        && todayComponents.day == dayNum
                    days.append(CalendarDay(
                        id: "\(nextYear)-\(nextMonthNum)-\(dayNum)",
                        date: date,
                        dayNumber: dayNum,
                        isCurrentMonth: false,
                        isToday: isToday
                    ))
                }
            }
        }

        return days
    }

    private func recomputeItemsByDay() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)

        // Filter to active/trial items only
        let activeItems = items.filter { $0.status == .active || $0.status == .trial }

        var grouped: [Int: [Item]] = [:]
        var total: Double = 0
        var eventCount: Int = 0

        for item in activeItems {
            guard let nextBilling = item.nextBillingDateFormatted else { continue }

            let billingDays = projectBillingDays(
                for: item.billingCycle,
                nextBillingDate: nextBilling,
                inYear: year,
                month: month
            )

            for day in billingDays {
                grouped[day, default: []].append(item)
                total += item.amount
                eventCount += 1
            }
        }

        itemsByDay = grouped
        monthTotal = total
        monthItemCount = eventCount
    }

    /// Starting from `nextBillingDate`, advances forward by billing cycle until reaching
    /// the target year/month, then collects all billing days that fall within that month.
    /// Important for weekly items that may have multiple billing dates per month.
    private func projectBillingDays(
        for cycle: BillingCycle,
        nextBillingDate: Date,
        inYear year: Int,
        month: Int
    ) -> [Int] {
        let calendar = Calendar.current

        // Target month boundaries
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        var billingDays: [Int] = []
        var current = nextBillingDate

        // If the billing date is already past the target month, no dates to project
        if current >= monthEnd {
            return []
        }

        // Advance forward until we reach or pass the target month.
        // Safety limit prevents runaway loops if date arithmetic stalls.
        var iterations = 0
        let maxIterations = 520 // ~10 years of weekly advances
        while current < monthStart && iterations < maxIterations {
            current = DateHelper.advanceDate(current, by: cycle)
            iterations += 1
        }

        // Collect all billing days within the target month
        while current < monthEnd {
            let day = calendar.component(.day, from: current)
            billingDays.append(day)
            current = DateHelper.advanceDate(current, by: cycle)
        }

        return billingDays
    }
}
