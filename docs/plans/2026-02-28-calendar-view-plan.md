# Calendar View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a monthly calendar view to the Dashboard tab showing subscription/bill due dates with dot indicators and inline day detail.

**Architecture:** Segmented control on Dashboard toggles between Overview (existing) and Calendar. `CalendarViewModel` handles billing date projection and month navigation. `CalendarView` renders a custom `LazyVGrid` calendar with extracted subviews for optimal diffing.

**Tech Stack:** SwiftUI, `@Observable @MainActor`, `LazyVGrid`, `Calendar` API

**Design doc:** `docs/plans/2026-02-28-calendar-view-design.md`

**No test suite configured** — verify via terminal build after each task.

---

### Task 1: Create CalendarViewModel

**Files:**
- Create: `SubTrkr/SubTrkr/ViewModels/CalendarViewModel.swift`

**Step 1: Create the CalendarDay struct and CalendarViewModel**

```swift
import Foundation

// MARK: - Calendar Day

struct CalendarDay: Identifiable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

// MARK: - CalendarViewModel

@Observable
@MainActor
final class CalendarViewModel {
    private let itemService = ItemService()

    var items: [Item] = []
    var isLoading = false
    var error: String?

    var displayedMonth: Date = {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }()

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // Cached computations (recomputed via recomputeCalendar())
    var calendarDays: [CalendarDay] = []
    var itemsByDay: [Int: [Item]] = [:]
    var monthTotal: Double = 0
    var monthItemCount: Int = 0

    // MARK: - Static Formatters

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

    var selectedDayItems: [Item] {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        let displayedComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard selectedComponents.year == displayedComponents.year,
              selectedComponents.month == displayedComponents.month else {
            return []
        }
        let day = calendar.component(.day, from: selectedDate)
        return itemsByDay[day] ?? []
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            items = try await itemService.getItems()
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

        let today = Date()
        let todayComponents = calendar.dateComponents([.year, .month], from: today)
        let newComponents = calendar.dateComponents([.year, .month], from: newMonth)
        if todayComponents.year == newComponents.year && todayComponents.month == newComponents.month {
            selectedDate = calendar.startOfDay(for: today)
        } else {
            selectedDate = newMonth
        }
        recomputeCalendar()
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    // MARK: - Calendar Computation

    private func recomputeCalendar() {
        calendarDays = buildCalendarDays()
        recomputeItemsByDay()
    }

    private func buildCalendarDays() -> [CalendarDay] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let today = calendar.startOfDay(for: Date())

        var days: [CalendarDay] = []

        // Previous month padding
        let prevPadding = firstWeekday - 1
        if prevPadding > 0 {
            guard let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: firstOfMonth),
                  let prevRange = calendar.range(of: .day, in: .month, for: prevMonthDate) else { return [] }
            let prevComponents = calendar.dateComponents([.year, .month], from: prevMonthDate)
            for dayNum in (prevRange.count - prevPadding + 1)...prevRange.count {
                let date = calendar.date(from: DateComponents(
                    year: prevComponents.year, month: prevComponents.month, day: dayNum
                ))!
                days.append(CalendarDay(
                    id: "prev-\(dayNum)",
                    date: date,
                    dayNumber: dayNum,
                    isCurrentMonth: false,
                    isToday: calendar.startOfDay(for: date) == today
                ))
            }
        }

        // Current month days
        for dayNum in 1...range.count {
            let date = calendar.date(from: DateComponents(
                year: components.year, month: components.month, day: dayNum
            ))!
            days.append(CalendarDay(
                id: "\(components.year!)-\(components.month!)-\(dayNum)",
                date: date,
                dayNumber: dayNum,
                isCurrentMonth: true,
                isToday: calendar.startOfDay(for: date) == today
            ))
        }

        // Next month padding
        let remainder = days.count % 7
        if remainder > 0 {
            let nextPadding = 7 - remainder
            guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) else { return days }
            let nextComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
            for dayNum in 1...nextPadding {
                let date = calendar.date(from: DateComponents(
                    year: nextComponents.year, month: nextComponents.month, day: dayNum
                ))!
                days.append(CalendarDay(
                    id: "next-\(dayNum)",
                    date: date,
                    dayNumber: dayNum,
                    isCurrentMonth: false,
                    isToday: calendar.startOfDay(for: date) == today
                ))
            }
        }

        return days
    }

    private func recomputeItemsByDay() {
        let calendar = Calendar.current
        let displayedComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let displayedYear = displayedComponents.year,
              let displayedMonthNum = displayedComponents.month else { return }

        var grouped: [Int: [Item]] = [:]
        let activeItems = items.filter { $0.status == .active || $0.status == .trial }

        for item in activeItems {
            guard let nextBillingDate = item.nextBillingDateFormatted else { continue }

            let projectedDays = projectBillingDays(
                for: item,
                nextBillingDate: nextBillingDate,
                inYear: displayedYear,
                month: displayedMonthNum
            )
            for day in projectedDays {
                grouped[day, default: []].append(item)
            }
        }

        itemsByDay = grouped

        let allItemsInMonth = grouped.values.flatMap { $0 }
        monthTotal = allItemsInMonth.reduce(0) { $0 + $1.amount }
        monthItemCount = allItemsInMonth.count
    }

    private func projectBillingDays(for item: Item, nextBillingDate: Date, inYear year: Int, month: Int) -> [Int] {
        let calendar = Calendar.current
        guard let targetStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let targetEnd = calendar.date(byAdding: .month, value: 1, to: targetStart) else { return [] }

        // Only project forward from nextBillingDate
        if nextBillingDate >= targetEnd { return [] }

        var date = nextBillingDate
        var days: [Int] = []

        // Advance to the target month
        while date < targetStart {
            date = DateHelper.advanceDate(date, by: item.billingCycle)
        }

        // Collect all billing dates within the target month
        while date < targetEnd {
            days.append(calendar.component(.day, from: date))
            date = DateHelper.advanceDate(date, by: item.billingCycle)
        }

        return days
    }
}
```

**Step 2: Build to verify compilation**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED (after adding file to Xcode project — see Task 4)

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/ViewModels/CalendarViewModel.swift
git commit -m "feat: add CalendarViewModel with billing date projection"
```

---

### Task 2: Create CalendarView with subviews

**Files:**
- Create: `SubTrkr/SubTrkr/Views/Dashboard/CalendarView.swift`

**Dependencies:** Task 1 (CalendarViewModel must exist)

**Step 1: Create CalendarView with all subviews**

The file contains: file-level constants, `CalendarView`, `CalendarHeader`, `CalendarDayCell`, `CalendarItemRow`, `MonthSummaryCard`.

```swift
import SwiftUI

private let calendarColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

// MARK: - CalendarView

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                calendarLoadingView
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No items yet",
                    message: "Add subscriptions or bills to see them on the calendar"
                )
            } else {
                calendarContent
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Content

    private var calendarContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                CalendarHeader(
                    title: viewModel.monthTitle,
                    onPrevious: { viewModel.navigateMonth(by: -1) },
                    onNext: { viewModel.navigateMonth(by: 1) }
                )

                calendarGrid

                dayDetailSection

                MonthSummaryCard(
                    total: viewModel.monthTotal,
                    itemCount: viewModel.monthItemCount
                )
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: calendarColumns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(String(symbol.prefix(2)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: calendarColumns, spacing: 4) {
                ForEach(viewModel.calendarDays) { day in
                    CalendarDayCell(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                        dotColors: dotColors(for: day)
                    )
                    .onTapGesture {
                        viewModel.selectDate(day.date)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Day Detail

    private var dayDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedDayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textSecondary)

            if viewModel.selectedDayItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.textMuted)
                        Text("No payments due")
                            .font(.subheadline)
                            .foregroundStyle(.textMuted)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(viewModel.selectedDayItems) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        CalendarItemRow(item: item)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Loading View

    private var calendarLoadingView: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
                .frame(height: 40)
                .shimmer()

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bgCard)
                .frame(height: 280)
                .shimmer()

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bgCard)
                .frame(height: 100)
                .shimmer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func dotColors(for day: CalendarDay) -> [String] {
        guard day.isCurrentMonth else { return [] }
        let items = viewModel.itemsByDay[day.dayNumber] ?? []
        return items.prefix(3).map { $0.categoryColor }
    }
}

// MARK: - CalendarHeader

struct CalendarHeader: View {
    let title: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.brand)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.brand)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - CalendarDayCell

struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let dotColors: [String]

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if day.isToday && !isSelected {
                    Circle()
                        .stroke(Color.brand, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                if isSelected {
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 32, height: 32)
                }

                Text("\(day.dayNumber)")
                    .font(.system(size: 14, weight: day.isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .textInverse :
                        day.isCurrentMonth ? .textPrimary : .textMuted
                    )
            }

            HStack(spacing: 2) {
                ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - CalendarItemRow

struct CalendarItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            ServiceLogo(
                url: item.logoURL,
                name: item.name,
                categoryColor: item.categoryColor,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                Text(item.billingCycle.displayName)
                    .font(.caption)
                    .foregroundStyle(.textMuted)
            }

            Spacer()

            CurrencyText(amount: item.amount, currency: item.currency)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - MonthSummaryCard

struct MonthSummaryCard: View {
    let total: Double
    let itemCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Month Total")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                Text(total.formatted(currency: "USD"))
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Payments")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                Text("\(itemCount)")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.textPrimary)
            }
        }
        .padding()
        .cardStyle()
    }
}
```

**Step 2: Build to verify compilation**

Run the same xcodebuild command from Task 1. Expected: BUILD SUCCEEDED (after adding file to Xcode project — see Task 4).

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Dashboard/CalendarView.swift
git commit -m "feat: add CalendarView with grid, day detail, and month summary"
```

---

### Task 3: Modify DashboardView to add segmented control

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift`

**Dependencies:** Task 2 (CalendarView must exist)

**Step 1: Add selectedTab state property**

Add after the existing `@State` properties:

```swift
@State private var selectedTab = 0
```

**Step 2: Restructure body to add segmented picker**

Replace the current `body` implementation. The key changes:
1. Wrap content in a `VStack` with the segmented picker at the top
2. Move the existing `ScrollView` content into an `overviewContent` computed property
3. Switch between `overviewContent` and `CalendarView()` based on `selectedTab`

Current `body`:
```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                statsSection
                if !viewModel.spendingByCategory.isEmpty {
                    categoryChart
                }
                if !viewModel.upcomingPayments.isEmpty {
                    upcomingSection
                }
            }
            .padding()
        }
        .background(Color.bgBase)
        .navigationTitle("Dashboard")
        .refreshable {
            await viewModel.loadData()
        }
    }
    .task {
        await viewModel.loadData()
        if !hasRunMaintenance, let userId = authService.currentUser?.id.uuidString {
            hasRunMaintenance = true
            await viewModel.runMaintenance(userId: userId)
            await viewModel.loadData()
        }
    }
}
```

New `body`:
```swift
var body: some View {
    NavigationStack {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Calendar").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedTab {
            case 0:
                overviewContent
            case 1:
                CalendarView()
            default:
                EmptyView()
            }
        }
        .background(Color.bgBase)
        .navigationTitle("Dashboard")
    }
    .task {
        await viewModel.loadData()
        if !hasRunMaintenance, let userId = authService.currentUser?.id.uuidString {
            hasRunMaintenance = true
            await viewModel.runMaintenance(userId: userId)
            await viewModel.loadData()
        }
    }
}
```

**Step 3: Extract overviewContent**

Add as a new private computed property on `DashboardView`:

```swift
private var overviewContent: some View {
    ScrollView {
        VStack(spacing: 20) {
            statsSection
            if !viewModel.spendingByCategory.isEmpty {
                categoryChart
            }
            if !viewModel.upcomingPayments.isEmpty {
                upcomingSection
            }
        }
        .padding()
    }
    .refreshable {
        await viewModel.loadData()
    }
}
```

**Step 4: Build to verify compilation**

Run xcodebuild. Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift
git commit -m "feat: add Overview/Calendar segmented control to Dashboard"
```

---

### Task 4: Add new files to Xcode project

**Files:**
- Modify: `SubTrkr/SubTrkr.xcodeproj/project.pbxproj`

**Context:** When adding new Swift files outside Xcode, they must be manually added to the `SubTrkr` target in `project.pbxproj`:
- `PBXFileReference` entry
- `PBXBuildFile` entry
- `PBXSourcesBuildPhase` entry
- `PBXGroup` entry (in the correct group)

**Files to add:**
1. `CalendarViewModel.swift` — add to ViewModels group
2. `CalendarView.swift` — add to Views/Dashboard group

**Step 1: Generate unique UUIDs and add entries**

Study the existing `project.pbxproj` to match the format of existing file entries. Each file needs:
- A unique 24-character hex UUID for the `PBXFileReference`
- A unique 24-character hex UUID for the `PBXBuildFile`
- Both UUIDs added to the appropriate `PBXSourcesBuildPhase`
- The `PBXFileReference` added to the correct `PBXGroup`

Look at how `DashboardViewModel.swift` and `DashboardView.swift` are referenced — mirror that pattern exactly for the new files.

**Step 2: Full build from terminal**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr.xcodeproj/project.pbxproj
git commit -m "chore: add CalendarViewModel and CalendarView to Xcode project"
```

---

### Task 5: Install, launch, and verify

**Dependencies:** All previous tasks

**Step 1: Install on simulator**

```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
```

**Step 2: Launch the app**

```bash
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

**Step 3: Manual verification checklist**

- [ ] Dashboard shows segmented control (Overview / Calendar)
- [ ] Overview tab shows existing content unchanged
- [ ] Calendar tab shows month grid with correct days
- [ ] Today is highlighted with brand ring
- [ ] Tapping a day selects it (brand fill)
- [ ] Dot indicators appear on days with items due
- [ ] Day detail shows items for selected day
- [ ] Tapping an item row navigates to ItemDetailView
- [ ] Month navigation (chevrons) changes the displayed month
- [ ] Month summary card shows correct total and count
- [ ] Empty state shows when no items exist
- [ ] Loading shimmer shows while data loads
- [ ] Pull-to-refresh works on Calendar tab

**Step 4: Final commit with all changes**

```bash
git add -A
git commit -m "feat: complete calendar view with billing date projection and month navigation"
```

---

## Notes

- **No past months:** Calendar only projects billing dates forward from `nextBillingDate`. Past months show nothing.
- **Weekly items:** Items with weekly billing cycles correctly show multiple dots per month (up to 4–5).
- **Performance:** Billing date projection is O(items × cycles_to_advance). For typical use (navigating 1–2 months ahead), this is negligible. Far-future navigation (years ahead) with many weekly items could be optimized with date arithmetic jumps if needed.
- **Existing patterns followed:** Color tokens from `Color+Theme.swift`, `.cardStyle()` for cards, `@Observable @MainActor` for ViewModel, static formatters, extracted subviews with `let` data.
