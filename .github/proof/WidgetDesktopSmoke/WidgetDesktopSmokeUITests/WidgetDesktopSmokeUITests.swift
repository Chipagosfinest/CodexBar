import AppKit
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
        guard preview.exists else {
            throw NSError(domain: "PackagedShareProof", code: 2)
        }
        XCTAssertEqual(app.windows.matching(identifier: "Share AI Usage").count, 1)
        XCTAssertTrue(preview.frame.width > 0 && preview.frame.height > 0)
        let claudeText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", "Claude", "Claude")).firstMatch
        XCTAssertTrue(
            claudeText.waitForExistence(timeout: 5),
            "\(phase) preview lacks accessible Claude content; inspect attachment")
        let tokenText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "110K", "110K")).firstMatch
        XCTAssertTrue(tokenText.exists, "\(phase) preview lacks synthetic token text")
        let costText = preview.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "$0.45", "$0.45")).firstMatch
        XCTAssertTrue(costText.exists, "\(phase) preview lacks synthetic estimated cost")

        let originalCapture = XCTAttachment(screenshot: self.visiblePreviewCapture(
            preview,
            phase: "\(phase) before foreground activation"))
        originalCapture.name = "packaged-share-\(phase)-before-foreground"
        originalCapture.lifetime = .keepAlways
        add(originalCapture)

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "\(phase) preview app did not become foreground")
        XCTAssertTrue(preview.isHittable, "\(phase) preview exists but is not ready for a visible capture")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "packaged-share-\(phase)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "packaged-share-\(phase)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func visiblePreviewCapture(_ preview: XCUIElement, phase: String) -> XCUIScreenshot {
        var screenshot = XCUIScreen.main.screenshot()
        for attempt in 0..<10 {
            if self.hasRenderedPreview(in: preview.frame, screenshot: screenshot) {
                return screenshot
            }
            if attempt < 9 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
                screenshot = XCUIScreen.main.screenshot()
            }
        }
        XCTFail("\(phase) preview accessibility is ready but its rendered frame remained black")
        return screenshot
    }

    private func hasRenderedPreview(in frame: CGRect, screenshot: XCUIScreenshot) -> Bool {
        guard let bitmap = NSBitmapImageRep(data: screenshot.pngRepresentation),
              let screenFrame = NSScreen.main?.frame,
              screenFrame.width > 0,
              screenFrame.height > 0
        else { return false }
        let scaleX = CGFloat(bitmap.pixelsWide) / screenFrame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / screenFrame.height
        let pixelFrame = CGRect(
            x: (frame.minX - screenFrame.minX) * scaleX,
            y: (frame.minY - screenFrame.minY) * scaleY,
            width: frame.width * scaleX,
            height: frame.height * scaleY).intersection(CGRect(
            x: 0,
            y: 0,
            width: CGFloat(bitmap.pixelsWide),
            height: CGFloat(bitmap.pixelsHigh)))
        guard !pixelFrame.isNull, pixelFrame.width > 2, pixelFrame.height > 2 else { return false }
        func color(at fraction: CGPoint) -> NSColor? {
            let x = Int(pixelFrame.minX + pixelFrame.width * fraction.x)
            let y = Int(pixelFrame.minY + pixelFrame.height * fraction.y)
            return bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
        }
        guard let lightMargin = color(at: CGPoint(x: 0.5, y: 0.1)),
              let darkCard = color(at: CGPoint(x: 0.5, y: 0.35))
        else { return false }
        let light = min(lightMargin.redComponent, lightMargin.greenComponent, lightMargin.blueComponent) > 0.6
        let darkMaximum = max(darkCard.redComponent, darkCard.greenComponent, darkCard.blueComponent)
        let dark = darkMaximum > 0.05 && darkMaximum < 0.55
        return light && dark
    }

    private static func isStrictDescendant(_ child: String, of parent: String) -> Bool {
        let childComponents = URL(fileURLWithPath: child).resolvingSymlinksInPath().pathComponents
        let parentComponents = URL(fileURLWithPath: parent).resolvingSymlinksInPath().pathComponents
        return childComponents.count > parentComponents.count
            && childComponents.starts(with: parentComponents)
    }
}

final class PackagedWidgetGalleryDiscoveryUITests: XCTestCase {
    func testRecordsDesktopWidgetGalleryDiscoveryEvidence() throws {
        let environment = ProcessInfo.processInfo.environment
        let packagedAppPath = try XCTUnwrap(environment["CODEXBAR_CI_PACKAGED_APP"])
        let runnerTemporaryPath = try XCTUnwrap(environment["CODEXBAR_CI_RUNNER_TEMP"])
        guard Self.isStrictDescendant(packagedAppPath, of: runnerTemporaryPath) else {
            XCTFail("Packaged app must be a disposable runner artifact")
            return
        }

        let codexBar = XCUIApplication(bundleIdentifier: "com.steipete.codexbar.debug")
        XCTAssertTrue(
            codexBar.wait(for: .runningBackground, timeout: 10) || codexBar.wait(for: .runningForeground, timeout: 1),
            "The previously proven packaged app must be running for gallery discovery")
        self.closeSharePreviewIfVisible(in: codexBar)

        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: 10), "Finder did not become foreground")
        XCTAssertTrue(finder.menuBars.firstMatch.waitForExistence(timeout: 5), "Finder menu bar was not accessible")

        self.attach("finder-before-widget-gallery", app: finder)
        self.attachText(self.systemWidgetOwnerSummary(), named: "widget-system-owners")
        self.attachSystemOwnerHierarchies()

        let controlCenter = XCUIApplication(bundleIdentifier: "com.apple.controlcenter")
        let clock = controlCenter.descendants(matching: .any)
            .matching(identifier: "com.apple.menuextra.clock").firstMatch
        XCTAssertTrue(clock.waitForExistence(timeout: 5), "Observed clock status item was not accessible")
        XCTAssertTrue(clock.isHittable, "Observed clock status item was not hittable")
        guard clock.exists, clock.isHittable else { return }
        clock.click()

        guard let notificationCenterID = self.waitForNotificationCenterIdentifier() else {
            XCTFail("Clicking the observed clock did not reveal a public Notification Center owner")
            return
        }
        let notificationCenter = XCUIApplication(bundleIdentifier: notificationCenterID)
        self.attach("notification-center-open", app: notificationCenter)

        let editWidgets = notificationCenter.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@", "Edit Widgets")).firstMatch
        XCTAssertTrue(
            editWidgets.waitForExistence(timeout: 5),
            "Notification Center lacked an accessible Edit Widgets control")
        let editWidgetsFrame = editWidgets.frame
        let observedLabel = editWidgets.label
        let validEditWidgetsFrame = editWidgetsFrame.width > 0 && editWidgetsFrame.height > 0 &&
            NSScreen.screens.contains(where: { $0.frame.contains(editWidgetsFrame) })
        XCTAssertTrue(
            observedLabel.localizedCaseInsensitiveContains("Edit Widgets") && validEditWidgetsFrame,
            "Accessible Edit Widgets control must retain its label and an on-screen frame")
        guard editWidgets.exists, observedLabel.localizedCaseInsensitiveContains("Edit Widgets"),
              validEditWidgetsFrame else { return }
        editWidgets.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let editWidgetsClosed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: editWidgets)
        XCTAssertEqual(
            XCTWaiter.wait(for: [editWidgetsClosed], timeout: 5),
            .completed,
            "Edit Widgets remained visible after its action; post-action UI is not a gallery transition")
        let gallerySearch = notificationCenter.searchFields.firstMatch
        let galleryDone = notificationCenter.buttons["Done"]
        var galleryControl: String?
        for attempt in 0..<10 {
            if gallerySearch.exists {
                galleryControl = "search field"
                break
            }
            if galleryDone.exists {
                galleryControl = "Done button"
                break
            }
            if attempt < 9 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        self.attach("after-edit-widgets", app: notificationCenter)
        self.attachText(self.systemWidgetOwnerSummary(), named: "post-edit-widgets-system-owners")
        self.attachSystemOwnerHierarchies()
        self.attachText(
            galleryControl ?? "No observed gallery search or Done control",
            named: "post-edit-widgets-gallery-control")
        self.attachText(
            self.codexBarGalleryCandidates(in: notificationCenter),
            named: "post-edit-widgets-codexbar-candidates")

        let desktopCandidates = finder.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "Desktop", "Desktop"))
        let summaries = (0..<desktopCandidates.count).compactMap { index -> String? in
            let candidate = desktopCandidates.element(boundBy: index)
            guard candidate.exists, candidate.frame.width > 0, candidate.frame.height > 0 else { return nil }
            return "\(candidate.elementType) | \(candidate.identifier) | \(candidate.label) | \(candidate.frame)"
        }
        self.attachText(summaries.joined(separator: "\n"), named: "accessible-desktop-candidates")
        self.attachText(
            "Edit Widgets was clicked and its control disappeared before the post-action capture. Gallery appearance requires attachment inspection unless an observed search or Done control is recorded. No widget was added; this is not installation proof.",
            named: "widget-gallery-discovery-boundary")
    }

    private func waitForNotificationCenterIdentifier() -> String? {
        for attempt in 0..<10 {
            if let identifier = self.systemOwnerIdentifiers().first(where: {
                $0.localizedCaseInsensitiveContains("notificationcenter")
            }) {
                return identifier
            }
            if attempt < 9 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        return nil
    }

    private func codexBarGalleryCandidates(in notificationCenter: XCUIApplication) -> String {
        let candidates = notificationCenter.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "CodexBar", "CodexBar"))
        return (0..<candidates.count).compactMap { index in
            let candidate = candidates.element(boundBy: index)
            guard candidate.exists else { return nil }
            return "\(candidate.elementType) | \(candidate.identifier) | \(candidate.label) | \(candidate.frame)"
        }.joined(separator: "\n")
    }

    private func closeSharePreviewIfVisible(in app: XCUIApplication) {
        let preview = app.windows["Share AI Usage"]
        guard preview.exists else { return }
        app.activate()
        let close = preview.buttons.matching(identifier: "_XCUI:CloseWindow").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Visible share preview lacks its accessible close control")
        guard close.exists else { return }
        close.click()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: preview)
        XCTAssertEqual(
            XCTWaiter.wait(for: [closed], timeout: 5),
            .completed,
            "Share preview did not close before gallery discovery")
    }

    private func systemWidgetOwnerSummary() -> String {
        self.systemOwnerIdentifiers().compactMap { identifier in
            NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == identifier }).map {
                "\(identifier) | \($0.localizedName ?? "") | running=\(!$0.isTerminated)"
            }
        }.joined(separator: "\n")
    }

    private func systemOwnerIdentifiers() -> [String] {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).filter {
            $0 == "com.apple.finder" || $0.localizedCaseInsensitiveContains("controlcenter") ||
                $0.localizedCaseInsensitiveContains("notificationcenter")
        }.sorted()
    }

    private func attachSystemOwnerHierarchies() {
        let identifiers = self.systemOwnerIdentifiers().filter {
            $0.localizedCaseInsensitiveContains("controlcenter") || $0
                .localizedCaseInsensitiveContains("notificationcenter")
        }
        for identifier in identifiers {
            self.attach("system-owner-\(identifier)", app: XCUIApplication(bundleIdentifier: identifier))
        }
    }

    private func attach(_ name: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        self.attachText(app.debugDescription, named: "\(name)-hierarchy")
    }

    private func attachText(_ text: String, named name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func isStrictDescendant(_ child: String, of parent: String) -> Bool {
        let childComponents = URL(fileURLWithPath: child).resolvingSymlinksInPath().pathComponents
        let parentComponents = URL(fileURLWithPath: parent).resolvingSymlinksInPath().pathComponents
        return childComponents.count > parentComponents.count
            && childComponents.starts(with: parentComponents)
    }
}
