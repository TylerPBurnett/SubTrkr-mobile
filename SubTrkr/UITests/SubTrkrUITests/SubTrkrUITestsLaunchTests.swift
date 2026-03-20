import XCTest

final class SubTrkrUITestsLaunchTests: XCTestCase {
    private let billingHarnessLaunchArgument = "UITEST_BILLING_FORM"

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesBillingHarness() throws {
        let app = XCUIApplication()
        app.launchArguments = [billingHarnessLaunchArgument]
        app.launchEnvironment["SUBTRKR_FIXED_TODAY"] = "2026-03-19"
        app.launch()

        XCTAssertTrue(app.navigationBars["Billing Harness"].waitForExistence(timeout: 5))
    }
}
