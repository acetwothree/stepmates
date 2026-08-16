//
//  StepMatesUITests.swift
//  StepMatesUITests
//

import XCTest

final class StepMatesUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["StepMates"].waitForExistence(timeout: 5))
    }
}
