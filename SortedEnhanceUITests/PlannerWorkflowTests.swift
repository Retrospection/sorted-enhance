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
        XCTAssertTrue(task(title).waitForExistence(timeout: 3), app.debugDescription)
    }

    func testReplanAroundFixedEventAndPreserveCompletedWorkAfterRelaunch() {
        let runID = UUID().uuidString
        let meeting = "Meeting " + runID
        let outline = "Outline " + runID
        let writing = "Write " + runID
        let calendarName = "Sorted Enhance UI Tests"
        app.launch()
        navigate("Schedule")
        let day = selectEmptyDay()
        addTeardownBlock { @MainActor in
            self.removeFixtures([meeting, outline, writing])
        }
        button("New Event").click()
        let calendars = app.popUpButtons["Calendar"]
        calendars.click()
        let testCalendar = app.menuItems[calendarName]
        XCTAssertTrue(testCalendar.waitForExistence(timeout: 3), "Create the disposable test calendar before running this test.")
        testCalendar.click()
        fill("Title", with: meeting)
        fill("Start time", with: "14:00")
        fill("Duration", with: "60")
        button("Save").click()

        createTask(title: outline, duration: 30)
        createTask(title: writing, duration: 60)
        schedule(from: "13:00")
        assertStart("13:00", for: outline)
        assertStart("15:00", for: writing)
        openTask(outline)
        button("Complete").click()
        schedule(from: "15:30")

        app.terminate()
        app.launch()
        navigate("Schedule")
        showDay(day)
        assertStart("14:00", for: meeting)
        assertStart("15:30", for: writing)
        navigate("History")
        assertStart("13:00", for: outline)
    }

    private func showDay(_ day: String) {
        fill("Schedule date", with: day)
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.staticTexts[day].waitForExistence(timeout: 3))
    }

    private func selectEmptyDay() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        for offset in 1...31 {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let day = formatter.string(from: date)
            showDay(day)
            if app.staticTexts["No scheduled items"].waitForExistence(timeout: 1) {
                return day
            }
        }
        XCTFail("No empty schedule day found in the next month.")
        return ""
    }

    private func removeFixtures(_ titles: [String]) {
        continueAfterFailure = true
        for title in titles {
            // Reset navigation even if cleanup of the preceding item failed.
            app.terminate()
            app.launch()
            app.typeKey("f", modifierFlags: .command)
            let search = app.searchFields.firstMatch
            guard search.waitForExistence(timeout: 3) else {
                XCTFail("Could not search for fixture " + title)
                continue
            }
            search.click()
            search.typeKey("a", modifierFlags: .command)
            search.typeText(title)
            let result = task(title)
            if result.waitForExistence(timeout: 3) {
                result.doubleClick()
                let delete = app.buttons["Delete"]
                if delete.waitForExistence(timeout: 3) {
                    delete.click()
                    XCTAssertTrue(result.waitForNonExistence(timeout: 3), "Fixture still visible: " + title)
                } else {
                    XCTFail("Could not remove fixture " + title)
                }
            }
        }
    }

    private func navigate(_ name: String) {
        let destination = app.descendants(matching: .any).matching(identifier: name).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 3), "Missing destination: \(name)")
        destination.click()
    }

    @discardableResult
    private func createTask(title: String = "Task " + UUID().uuidString, duration: Int? = nil) -> String {
        button("New Task").click()
        fill("Title", with: title)
        if let duration {
            fill("Duration", with: String(duration))
        }
        button("Save").click()
        XCTAssertTrue(task(title).waitForExistence(timeout: 3), app.debugDescription)
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
        fill("Buffer", with: "0")
        button("Apply").click()
    }

    private func assertStart(_ time: String, for title: String) {
        openTask(title)
        XCTAssertEqual(field("Start time").value as? String, time)
        button("Close").click()
    }
}
