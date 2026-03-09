import XCTest

final class NotchTerminalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(tab: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NOTCHTERMINAL_UI_TEST"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let tab {
            app.launchEnvironment["NOTCHTERMINAL_UI_TEST_TAB"] = tab
        }
        app.launch()
        return app
    }

    @MainActor
    func testAppLaunches() throws {
        let app = launchApp()

        let launched = app.wait(for: .runningForeground, timeout: 5) || app.wait(for: .runningBackground, timeout: 5)
        XCTAssertTrue(launched)
        XCTAssertTrue(app.windows["NotchTerminal UITest"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsExpectedTabs() throws {
        let app = launchApp()

        XCTAssertTrue(app.windows["NotchTerminal UITest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Show Dock icon"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Open notch on hover"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Quit"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testGeneralSettingsExposesStableControls() throws {
        let app = launchApp()

        XCTAssertTrue(app.windows["NotchTerminal UITest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Show Dock icon"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Open notch on hover"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testAboutTabExposesStableActions() throws {
        let app = launchApp(tab: "about")

        XCTAssertTrue(app.windows["NotchTerminal UITest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Check for Updates"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Release Notes"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Project Website"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Buy Me a Coffee"].waitForExistence(timeout: 2))
    }
}
