import XCTest

final class WidgetDesktopSmokeUITests: XCTestCase {
    func testFinderCanBeActivatedAndItsMenuBarInspected() {
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

final class PackagedCodexBarShareUITests: XCTestCase {
    private let bundleID = "com.steipete.codexbar.debug"
    private let route = "codexbar://share-stats?version=1"

    func testPackagedAppOpensPopulatedSharePreviewWarmAndCold() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CODEXBAR_CI_PACKAGED_PROOF"] == "1" else {
            throw XCTSkip("Packaged share proof is not enabled for this run")
        }
        let bundlePath = try XCTUnwrap(environment["CODEXBAR_CI_PACKAGED_APP"])
        let seedPath = try XCTUnwrap(environment["CODEXBAR_CI_SEED_ROOT"])
        let runnerTemporaryPath = try XCTUnwrap(environment["CODEXBAR_CI_RUNNER_TEMP"])
        guard bundlePath.hasPrefix("/"), seedPath.hasPrefix("/"), runnerTemporaryPath.hasPrefix("/"),
              Self.isStrictDescendant(bundlePath, of: runnerTemporaryPath),
              Self.isStrictDescendant(seedPath, of: runnerTemporaryPath)
        else {
            XCTFail("Packaged app and seed must be absolute descendants of the disposable runner directory")
            throw NSError(domain: "PackagedShareProof", code: 1)
        }

        let appURL = URL(fileURLWithPath: bundlePath, isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            appURL.appendingPathComponent("Contents/MacOS/CodexBar").path))

        // The workflow launches this exact package outside XCTest. Launching through
        // XCUIApplication injects XCTest state and would suppress normal persistence.
        let app = XCUIApplication(bundleIdentifier: self.bundleID)
        guard app.wait(for: .runningBackground, timeout: 15)
            || app.wait(for: .runningForeground, timeout: 1)
        else {
            XCTFail("Packaged menu-bar app must already be running")
            throw NSError(domain: "PackagedShareProof", code: 3)
        }

        try self.openRoute(in: appURL)
        try self.assertPreview(app, phase: "warm")

        // Only the uniquely named debug app on a fresh disposable runner is terminated.
        app.terminate()
        guard app.wait(for: .notRunning, timeout: 10) else {
            XCTFail("Debug app did not quit")
            throw NSError(domain: "PackagedShareProof", code: 4)
        }

        // LaunchServices must cold-launch the same app and consume launchctl GUI seed env.
        try self.openRoute(in: appURL)
        try self.assertPreview(app, phase: "cold")
    }

    private func openRoute(in appURL: URL) throws {
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        command.arguments = ["-a", appURL.path, self.route]
        command.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        try command.run()
        command.waitUntilExit()
        guard command.terminationStatus == 0 else {
            XCTFail("Share URL handoff failed")
            throw NSError(domain: "PackagedShareProof", code: 5)
        }
    }

    private func assertPreview(_ app: XCUIApplication, phase: String) throws {
        let preview = app.windows["Share AI Usage"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20), "No \(phase) share preview")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "packaged-share-\(phase)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "packaged-share-\(phase)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        guard preview.exists else {
            throw NSError(domain: "PackagedShareProof", code: 2)
        }
        XCTAssertEqual(app.windows.matching(identifier: "Share AI Usage").count, 1)
        XCTAssertTrue(preview.frame.width > 0 && preview.frame.height > 0)
        let codexText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Codex")).firstMatch
        XCTAssertTrue(
            codexText.waitForExistence(timeout: 5),
            "\(phase) preview lacks accessible Codex content; inspect attachment")
        let tokenText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "110K")).firstMatch
        XCTAssertTrue(tokenText.exists, "\(phase) preview lacks synthetic token text")
        let costText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "$0.38")).firstMatch
        XCTAssertTrue(costText.exists, "\(phase) preview lacks synthetic estimated cost")
    }

    private static func isStrictDescendant(_ child: String, of parent: String) -> Bool {
        let childComponents = URL(fileURLWithPath: child).resolvingSymlinksInPath().pathComponents
        let parentComponents = URL(fileURLWithPath: parent).resolvingSymlinksInPath().pathComponents
        return childComponents.count > parentComponents.count
            && childComponents.starts(with: parentComponents)
    }
}
