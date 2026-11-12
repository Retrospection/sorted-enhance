import XCTest

@MainActor
final class PlannerWorkflowTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDuplicateCanBeEditedWithoutChangingOriginal() {
        app.launch()
        navigate("Inbox")
        let original = createTask()
        openTask(original)
        button("Duplicate").click()
        let copy = "Copy \(UUID().uuidString)"
        fill("Title", with: copy)
        button("Save").click()

        XCTAssertTrue(task(original).exists)
        XCTAssertTrue(task(copy).exists)
    }

    func testDeletedTaskRestoresWithItsNote() {
        app.launch()
        navigate("Inbox")
        let title = createTask()
        openTask(title)
        fill("Notes", with: "Bring the signed proposal", type: .textView)
        button("Save").click()
        openTask(title)
        button("Delete").click()
        XCTAssertFalse(task(title).exists)

        navigate("Trash")
        openTask(title)
        button("Restore").click()
        navigate("Inbox")
        openTask(title)
        XCTAssertEqual(field("Notes", type: .textView).value as? String, "Bring the signed proposal")
    }

    func testCompletedTaskCanBeReopenedFromHistory() {
        app.launch()
        navigate("Inbox")
        let title = createTask()
        openTask(title)
        button("Complete").click()
        navigate("History")
        openTask(title)
        button("Reopen").click()
        navigate("Inbox")
        XCTAssertTrue(task(title).waitForExistence(timeout: 3))
    }

    func testReplanAroundFixedEventAndPreserveCompletedWorkAfterRelaunch() {
        // Run in an empty test day with a writable calendar and zero schedule buffer.
        app.launch()
        navigate("Schedule")
        let meeting = "Meeting \(UUID().uuidString)"
        button("New Event").click()
        fill("Title", with: meeting)
        fill("Start time", with: "14:00")
        fill("Duration", with: "60")
        button("Save").click()

        let outline = createTask(duration: 30)
        let writing = createTask(duration: 60)
        schedule(from: "13:00")
        assertStart("13:00", for: outline)
        assertStart("15:00", for: writing)
        openTask(outline)
        button("Complete").click()
        schedule(from: "15:30")

        app.terminate()
        app.launch()
        navigate("Schedule")
        assertStart("14:00", for: meeting)
        assertStart("15:30", for: writing)
        navigate("History")
        assertStart("13:00", for: outline)
    }

    private func navigate(_ name: String) {
        let destination = app.descendants(matching: .any).matching(identifier: name).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 3), "Missing destination: \(name)")
        destination.click()
    }

    private func createTask(duration: Int? = nil) -> String {
        let title = "Task \(UUID().uuidString)"
        button("New Task").click()
        fill("Title", with: title)
        if let duration {
            fill("Duration", with: String(duration))
        }
        button("Save").click()
        XCTAssertTrue(task(title).waitForExistence(timeout: 3))
        return title
    }

    private func task(_ title: String) -> XCUIElement {
        app.staticTexts[title]
    }

    private func openTask(_ title: String) {
        let item = task(title)
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.doubleClick()
    }

    private func field(_ label: String, type: XCUIElement.ElementType = .textField) -> XCUIElement {
        let element = app.descendants(matching: type)[label]
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing field: \(label)")
        return element
    }

    private func fill(_ label: String, with value: String, type: XCUIElement.ElementType = .textField) {
        let element = field(label, type: type)
        element.click()
        element.typeKey("a", modifierFlags: .command)
        element.typeText(value)
    }

    private func button(_ label: String) -> XCUIElement {
        let element = app.buttons[label]
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing button: \(label)")
        return element
    }

    private func schedule(from time: String) {
        button("Auto Schedule").click()
        fill("Schedule from", with: time)
        button("Apply").click()
    }

    private func assertStart(_ time: String, for title: String) {
        openTask(title)
        XCTAssertEqual(field("Start time").value as? String, time)
        button("Close").click()
    }
}
