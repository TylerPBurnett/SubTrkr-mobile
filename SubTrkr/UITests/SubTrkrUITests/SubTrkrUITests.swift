import XCTest

final class SubTrkrUITests: XCTestCase {
    private let billingHarnessLaunchArgument = "UITEST_BILLING_FORM"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFutureStartDateKeepsFutureDateAsNextBillingDate() throws {
        let app = configuredApp()
        app.launch()

        app.buttons["billingHarness.futureMarch31"].tap()

        XCTAssertEqual(renderedDates(for: app.staticTexts["billingHarness.nextBillingDate"]).last, "2026-03-31")
        XCTAssertEqual(
            uniqueRenderedDates(for: app.staticTexts["billingHarness.previewDates"]),
            ["2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30"]
        )
    }

    func testDueTodayMonthlyAdvancesToNextMonth() throws {
        let app = configuredApp()
        app.launch()

        app.buttons["billingHarness.dueTodayMonthly"].tap()

        XCTAssertEqual(renderedDates(for: app.staticTexts["billingHarness.nextBillingDate"]).last, "2026-04-19")
    }

    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [billingHarnessLaunchArgument]
        app.launchEnvironment["SUBTRKR_FIXED_TODAY"] = "2026-03-19"
        return app
    }

    private func renderedDates(for element: XCUIElement) -> [String] {
        let pattern = /\d{4}-\d{2}-\d{2}/
        return element.label.matches(of: pattern).map { String($0.0) }
    }

    private func uniqueRenderedDates(for element: XCUIElement) -> [String] {
        var seen = Set<String>()
        return renderedDates(for: element).filter { seen.insert($0).inserted }
    }
}
