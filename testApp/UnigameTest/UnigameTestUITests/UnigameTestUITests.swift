//
//  UnigameTestUITests.swift
//  UnigameTestUITests
//
//  Created by Josh Auerbach on 12/6/24.
//

import XCTest

final class UnigameTestUITests: XCTestCase {
    var app: XCUIApplication! = nil

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testPlayersScreen() throws {
        
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
