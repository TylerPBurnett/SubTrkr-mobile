import SwiftUI

// MARK: - File-level Constants

private let calendarColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

// MARK: - CalendarView

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingSkeleton
            } else if viewModel.items.isEmpty && viewModel.error == nil {
                EmptyStateView(
                    icon: "calendar",
                    title: "No items yet",
                    message: "Add subscriptions or bills to see them on your calendar."
                )
            } else {
                calendarContent
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
                .frame(height: 44)
                .shimmer()

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
                .frame(height: 260)
                .shimmer()

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
                .frame(height: 80)
                .shimmer()
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Content

    private var calendarContent: some View {
        VStack(spacing: 16) {
            // Month navigation header
            CalendarHeader(
                title: viewModel.monthTitle,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )

            // Weekday headers
            weekdayHeaderRow

            // Calendar grid
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

            // Day detail section
            dayDetailSection

            // Month summary
            MonthSummaryCard(
                total: viewModel.monthTotal,
                itemCount: viewModel.monthItemCount
            )
        }
        .padding()
    }

    // MARK: - Weekday Header Row

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Detail Section

    private var dayDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedDayTitle)
                .font(.headline)
                .foregroundStyle(.textPrimary)

            if viewModel.selectedDayItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.title2)
                            .foregroundStyle(.textMuted)
                        Text("No payments due")
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(viewModel.selectedDayItems) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        CalendarItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Helpers

    private func dotColors(for day: CalendarDay) -> [String] {
        guard day.isCurrentMonth else { return [] }
        let dayNumber = day.dayNumber
        guard let items = viewModel.itemsByDay[dayNumber] else { return [] }
        return Array(items.prefix(3).map { $0.categoryColor })
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
                    .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
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
                if isSelected {
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 32, height: 32)
                } else if day.isToday {
                    Circle()
                        .stroke(Color.brand, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Text("\(day.dayNumber)")
                    .font(.subheadline)
                    .foregroundStyle(dayTextColor)
            }

            // Dot indicators
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var dayTextColor: Color {
        if isSelected {
            return .textInverse
        } else if !day.isCurrentMonth {
            return .textMuted
        } else {
            return .textPrimary
        }
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
