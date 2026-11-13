import XCTest

@MainActor
final class WindowCaptureTests: XCTestCase {
    func testSimplifiedChineseWindows() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SORTED_CAPTURE_WINDOWS"] == "1",
                          "Capture windows on a disposable macOS profile.")
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-AppleInterfaceStyle", "Light"]
        app.launch()

        let planner = app.windows.firstMatch
        XCTAssertTrue(planner.waitForExistence(timeout: 5))
        XCTAssertTrue(planner.buttons["newScheduleTask"].waitForExistence(timeout: 5))
        attach(planner, named: "Schedule")

        app.typeKey("f", modifierFlags: .command)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        attach(planner, named: "QuickSearch")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(search.waitForNonExistence(timeout: 5))

        planner.buttons["Inbox"].click()
        let newTask = planner.buttons["New Task"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 5))
        XCTAssertTrue(planner.staticTexts["收件箱"].firstMatch.waitForExistence(timeout: 5))
        attach(planner, named: "Inbox")

        newTask.click()
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        title.click()
        title.typeText("Review proposal")
        XCTAssertEqual(title.value as? String, "Review proposal")
        attach(planner, named: "TaskEditor")
        app.buttons["Save"].click()
        let task = planner.staticTexts["Review proposal"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        attach(planner, named: "PopulatedInbox")

        let complete = planner.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "InboxComplete-")).firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.click()
        XCTAssertTrue(task.waitForNonExistence(timeout: 5))
        planner.buttons["History"].click()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        attach(planner, named: "History")
        task.doubleClick()
        let delete = app.buttons["删除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.click()
        planner.buttons["Trash"].click()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        attach(planner, named: "Trash")

        for (section, create, name) in [("Lists", "New List", "Studio"), ("Tags", "New Tag", "Design")] {
            planner.buttons[section].click()
            planner.buttons[create].click()
            let nameField = app.textFields["名称"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.click()
            nameField.typeText(name)
            app.buttons["保存"].click()
            XCTAssertTrue(nameField.waitForNonExistence(timeout: 5))
            let result = planner.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 5))
            attach(planner, named: section)
        }

        app.typeKey(",", modifierFlags: .command)
        let settings = planner.sheets.firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(settings.staticTexts["设置"].firstMatch.exists)
        let done = settings.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(planner.frame.contains(settings.frame))
        attach(settings, named: "Settings")
        attach(planner, named: "PlannerWithSettings")

        done.click()
        XCTAssertTrue(settings.waitForNonExistence(timeout: 5))
        planner.buttons["设置"].click()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(settings.waitForNonExistence(timeout: 5))
    }

    private func attach(_ window: XCUIElement, named name: String) {
        let screenshot = window.screenshot()
        let image = XCTAttachment(data: screenshot.pngRepresentation, uniformTypeIdentifier: "public.png")
        image.name = "SortedEnhance-" + name
        image.lifetime = .keepAlways
        add(image)
    }
}
