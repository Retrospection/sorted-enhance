import XCTest

@MainActor
final class InboxTests: XCTestCase {
    func testTitleOnlyTaskSurvivesRelaunchInInbox() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let title = "Read proposal \(UUID().uuidString)"
        app.launch()
        openInbox(in: app)

        let newTask = app.buttons["New Task"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 3), "Inbox must allow task capture.")
        newTask.click()
        let field = app.textFields["Title"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.click()
        field.typeText(title + "\n")
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        openInbox(in: app)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(identifier: title).count, 1)
    }

    private func openInbox(in app: XCUIApplication) {
        let inbox = app.descendants(matching: .any).matching(identifier: "Inbox").firstMatch
        XCTAssertTrue(inbox.waitForExistence(timeout: 3), "The user must be able to open the Inbox.")
        inbox.click()
    }
}
