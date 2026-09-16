import XCTest

final class WidgetDesktopSmokeUITests: XCTestCase {
    func testFinderCanBeActivatedAndItsMenuBarInspected() throws {
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: 10), "Finder did not become foreground")

        let menuBar = finder.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 5), "Finder menu bar was not accessible")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: finder.debugDescription)
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        let fileMenu = menuBar.menuBarItems["File"]
        guard fileMenu.exists else { return }
        fileMenu.click()
        XCTAssertTrue(finder.menus.firstMatch.waitForExistence(timeout: 5), "Finder File menu did not open")
        finder.typeKey(.escape, modifierFlags: [])
    }
}
