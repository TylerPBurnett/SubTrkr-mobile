import XCTest
@testable import SubTrkr

@MainActor
final class MaintenanceServiceTests: XCTestCase {
    func testRunIfNeededDeduplicatesConcurrentCallsForSameUser() async throws {
        var callCount = 0
        let service = MaintenanceService(operation: { _ in
            callCount += 1
            try await Task.sleep(nanoseconds: 50_000_000)
        })

        async let firstRun = service.runIfNeeded(userId: "user-1")
        async let secondRun = service.runIfNeeded(userId: "user-1")

        let firstResult = try await firstRun
        let secondResult = try await secondRun

        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertEqual(callCount, 1)
        let thirdResult = try await service.runIfNeeded(userId: "user-1")
        XCTAssertFalse(thirdResult)
    }
}
