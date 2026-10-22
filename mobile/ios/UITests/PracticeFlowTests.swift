import XCTest

final class PracticeFlowTests: XCTestCase {
    func testPracticeResultsAndStatisticsPersistAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()
        app.segmentedControls.buttons["Practice"].tap()
        app.segmentedControls.buttons["Easy"].tap()
        app.buttons["Start practice"].tap()
        let question = app.staticTexts["question"]
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        for index in 0..<10 {
            let previousID = question.value as? String ?? ""
            let numbers = question.label.components(separatedBy: " =")[0].components(separatedBy: " + ")
            XCTAssertEqual(numbers.count, 2)
            guard numbers.count == 2, let first = Int(numbers[0]), let second = Int(numbers[1]) else { return }
            app.buttons["answer.\(first + second)"].tap()
            if index == 9 {
                XCTAssertTrue(app.staticTexts["Practice complete"].waitForExistence(timeout: 5))
            } else {
                let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", previousID), object: question)
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
            }
        }
        XCTAssertTrue(app.staticTexts["10/10 correct · 100% accuracy"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Practice results"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["Learning statistics"].tap()
        XCTAssertTrue(app.staticTexts["Practice rounds: 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10/10 correct · 100% accuracy"].exists)
    }
}
