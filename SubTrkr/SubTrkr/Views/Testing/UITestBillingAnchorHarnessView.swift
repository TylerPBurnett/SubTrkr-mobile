import SwiftUI

enum UITestHarness {
    static let billingFormLaunchArgument = "UITEST_BILLING_FORM"

    static var isBillingFormEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(billingFormLaunchArgument)
    }
}

struct UITestBillingAnchorHarnessView: View {
    @State private var viewModel = ItemFormViewModel(itemType: .subscription)

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenarios") {
                    Button("Future March 31 Monthly") {
                        applyScenario(startDate: "2026-03-31", cycle: .monthly)
                    }
                    .accessibilityIdentifier("billingHarness.futureMarch31")

                    Button("Due Today Monthly") {
                        applyScenario(startDate: "2026-03-19", cycle: .monthly)
                    }
                    .accessibilityIdentifier("billingHarness.dueTodayMonthly")
                }

                Section("Computed") {
                    LabeledContent("Start Date") {
                        Text(DateHelper.formatDate(viewModel.startDate))
                            .accessibilityIdentifier("billingHarness.startDate")
                            .accessibilityLabel(DateHelper.formatDate(viewModel.startDate))
                    }

                    LabeledContent("Next Billing Date") {
                        Text(DateHelper.formatDate(viewModel.nextBillingDate))
                            .accessibilityIdentifier("billingHarness.nextBillingDate")
                            .accessibilityLabel(DateHelper.formatDate(viewModel.nextBillingDate))
                    }

                    LabeledContent("Preview") {
                        Text(previewLabel)
                            .accessibilityIdentifier("billingHarness.previewDates")
                            .accessibilityLabel(previewLabel)
                    }
                }
            }
            .navigationTitle("Billing Harness")
        }
        .onAppear {
            applyScenario(startDate: "2026-03-31", cycle: .monthly)
        }
    }

    private var previewDates: [String] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 5, to: viewModel.startDate) ?? viewModel.startDate
        let interval = DateInterval(start: viewModel.startDate, end: endDate)
        let dates = DateHelper.recurringDates(anchorDate: viewModel.startDate, cycle: viewModel.billingCycle, in: interval)
        return Array(dates.prefix(4)).map(DateHelper.formatDate)
    }

    private var previewLabel: String {
        previewDates.joined(separator: ", ")
    }

    private func applyScenario(startDate: String, cycle: BillingCycle) {
        guard let parsedStartDate = DateHelper.parseDate(startDate) else { return }

        viewModel.userEditedNextBillingDate = false
        viewModel.startDate = parsedStartDate
        viewModel.billingCycle = cycle
        viewModel.autoCalcNextBillingDate()
    }
}
