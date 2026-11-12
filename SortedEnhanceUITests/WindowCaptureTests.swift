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
        app.buttons["Close"].click()

        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows.containing(.button, identifier: "完成").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.staticTexts["设置"].firstMatch.exists)
        attach(settings, named: "Settings")
    }

    private func attach(_ window: XCUIElement, named name: String) {
        let screenshot = window.screenshot()
        let image = XCTAttachment(data: screenshot.pngRepresentation, uniformTypeIdentifier: "public.png")
        image.name = "SortedEnhance-" + name
        image.lifetime = .keepAlways
        add(image)
    }
}
