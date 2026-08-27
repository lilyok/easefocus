import XCTest

final class EaseFocusUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoTheEmptyState() throws {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(app.staticTexts["Ready to focus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["createPlan"].exists)
    }
}
