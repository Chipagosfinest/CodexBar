import AppKit
import XCTest

final class WidgetHostProofTests: XCTestCase {
    func testInstalledLargeWidgetCompleteAndIncompleteHistory() {
        let galleryFamily = "small"
        let widgetFamily = "large"
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: 10), "Finder did not become foreground")
        XCTAssertTrue(finder.menuBars.firstMatch.waitForExistence(timeout: 5), "Finder menu bar was not accessible")

        self.attach("finder-before-widget-gallery", app: finder)
        self.attachText(self.systemWidgetOwnerSummary(), named: "widget-system-owners")
        self.attachSystemOwnerHierarchies()

        let notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.notificationcenterui")
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
        XCTAssertEqual(notificationCenterID, "com.apple.notificationcenterui")
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

        let codexBarCategory = notificationCenter.buttons["CodexBar"]
        XCTAssertTrue(
            codexBarCategory.waitForExistence(timeout: 5),
            "Widget gallery lacked the observed CodexBar category")
        guard codexBarCategory.exists else { return }
        codexBarCategory.click()
        let switcherPreview = notificationCenter.descendants(matching: .any).matching(NSPredicate(
            format: "identifier CONTAINS %@ AND identifier CONTAINS %@ AND identifier CONTAINS %@",
            "com.steipete.codexbar.debug", "CodexBarSwitcherWidget", "system\(galleryFamily.capitalized)")).firstMatch
        XCTAssertTrue(
            switcherPreview.waitForExistence(timeout: 5),
            "CodexBar \(galleryFamily) Switcher preview was not available")
        XCTAssertTrue(
            switcherPreview.frame.width > 0 && switcherPreview.frame.height > 0,
            "Switcher preview had no visible frame")
        self.attach("codexbar-switcher-selected-before-actions", app: notificationCenter)

        // This fresh runner's captured desktop has existing widgets at x <= 368,
        // the gallery below y=256, and Notification Center at x >= 664.
        // Recheck the actual window frames before using that empty desktop region.
        let desktop = finder.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@", "desktop")).firstMatch
        XCTAssertTrue(desktop.exists, "Observed Finder desktop disappeared")
        let desktopFrame = desktop.frame
        let installedSize = galleryFamily == "small" ? CGSize(width: 180, height: 180) : CGSize(
            width: 348,
            height: 168)
        // macOS 15's captured widgets occupy the right edge; keep a medium tile wholly left of them.
        let drop = CGPoint(
            x: galleryFamily == "medium" ? desktopFrame.minX + 400 : desktopFrame.midX,
            y: desktopFrame.minY + 120)
        let dropFrame = CGRect(
            x: drop.x - installedSize.width / 2,
            y: drop.y - installedSize.height / 2,
            width: installedSize.width,
            height: installedSize.height)
        let occupied = notificationCenter.windows.allElementsBoundByIndex.contains {
            $0.frame.intersects(dropFrame)
        }
        guard desktopFrame.width == 1024, desktopFrame.height == 768,
              desktopFrame.contains(dropFrame), !occupied,
              NSScreen.screens.contains(where: { $0.frame.contains(switcherPreview.frame) })
        else {
            XCTFail("Captured desktop geometry does not establish a safe empty drop target")
            return
        }
        let target = desktop.coordinate(withNormalizedOffset: CGVector(
            dx: (drop.x - desktopFrame.minX) / desktopFrame.width,
            dy: (drop.y - desktopFrame.minY) / desktopFrame.height))
        switcherPreview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .click(forDuration: 1, thenDragTo: target)
        self.attach("after-switcher-desktop-drop", app: notificationCenter)
        let modernDone = notificationCenter.buttons.matching(identifier: "widget-add-sheet-done").firstMatch
        let legacyDone = notificationCenter.buttons.matching(NSPredicate(format: "label == %@", "Done"))
        let done: XCUIElement
        if modernDone.exists {
            done = modernDone
        } else if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 15, legacyDone.count == 1 {
            // macOS 15's captured gallery exposes the Done label without the newer identifier.
            done = legacyDone.firstMatch
        } else {
            XCTFail("Widget gallery has no uniquely identified Done control")
            return
        }
        guard done.waitForExistence(timeout: 5),
              NSScreen.screens.contains(where: { $0.frame.contains(done.frame) })
        else {
            XCTFail("Observed widget gallery Done control was unavailable")
            return
        }
        let doneReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"), object: done)
        guard XCTWaiter.wait(for: [doneReady], timeout: 5) == .completed else {
            XCTFail("Observed gallery Done control never became hittable after placement")
            return
        }
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let galleryClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: done)
        if XCTWaiter.wait(for: [galleryClosed], timeout: 5) != .completed {
            self.attach("gallery-after-unacknowledged-done", app: notificationCenter)
            // macOS 26 captures sometimes retain the gallery after the first Done click.
            // Retry the same observed control once; disappearance remains mandatory.
            guard done.exists, done.isHittable, done.frame.width > 0, done.frame.height > 0,
                  NSScreen.screens.contains(where: { $0.frame.contains(done.frame) })
            else {
                XCTFail("Gallery did not close and its original Done control is no longer safely actionable")
                return
            }
            done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            let retryClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: done)
            guard XCTWaiter.wait(for: [retryClosed], timeout: 5) == .completed else {
                XCTFail("Gallery remained open after one bounded Done retry")
                return
            }
        }
        // The add sheet and desktop editor have separate Done controls.
        let editorDone = notificationCenter.buttons.matching(identifier: "widget-editor-button").firstMatch
        if editorDone.exists, editorDone.label == "Done" {
            guard NSScreen.screens.contains(where: { $0.frame.contains(editorDone.frame) }) else {
                XCTFail("Desktop editor Done control is outside the screen")
                return
            }
            editorDone.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
        let editingEnded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !editorDone.exists || editorDone.label != "Done"
        }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [editingEnded], timeout: 5),
            .completed,
            "Desktop remained in widget editing mode")

        let installed = notificationCenter.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@ AND identifier CONTAINS %@",
            "widget-local:", "com.steipete.codexbar.debug", "CodexBarSwitcherWidget")).firstMatch
        guard installed.waitForExistence(timeout: 15) else {
            self.attach("installed-switcher-missing", app: notificationCenter)
            XCTFail("Dragging the gallery preview did not create an installed desktop Switcher")
            return
        }
        XCTAssertTrue(
            galleryFamily == "small"
                ? (140...200).contains(installed.frame.width) && (140...200).contains(installed.frame.height)
                : (320...380).contains(installed.frame.width) && (140...200).contains(installed.frame.height),
            "Installed Switcher is not the expected \(galleryFamily) family")
        XCTAssertFalse(installed.buttons["Remove"].exists, "Installed widget is still in edit mode")
        if widgetFamily == "large" {
            installed.rightClick()
            self.attach("installed-switcher-context-menu-before-medium", app: notificationCenter)
            // The observed menu belongs to Notification Center and exposes AppKit title text.
            let mediumActions = notificationCenter.menuItems.matching(NSPredicate(
                format: "title == %@", "Large")).allElementsBoundByIndex.filter { item in
                item.exists && item.frame.width > 0 && item.frame.height > 0 &&
                    NSScreen.screens.contains(where: { $0.frame.contains(item.frame) })
            }
            guard mediumActions.count == 1, let medium = mediumActions.first else {
                XCTFail("Expected one observed on-screen Medium widget size action")
                return
            }
            medium.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (320...380).contains(installed.frame.width) && (320...400).contains(installed.frame.height)
            }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [resized], timeout: 10),
                .completed,
                "Medium action did not resize Switcher")
        }

        // The gallery leaves Notification Center's notifications panel open. Close that
        // observed panel before interacting with the fixture app, so XCTest does not
        // mistake the desktop widget for a notification interruption.
        let clearNotifications = notificationCenter.menuButtons.matching(identifier: "xmark").firstMatch
        if clearNotifications.exists {
            clock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            let closed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: clearNotifications)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        }
        XCTAssertTrue(installed.frame.height > 300, "Must exercise a large installed widget")
        func waitForText(_ text: String, present: Bool) {
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                installed.debugDescription.contains(text) == present
            }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [changed], timeout: 90),
                .completed,
                "Expected \(text) present=\(present)")
        }
        waitForText("fixture-alpha", present: true)
        waitForText("80%", present: true)
        self.attach("complete-installed-large", app: notificationCenter)
        let app = XCUIApplication(bundleIdentifier: "com.steipete.codexbar.debug")
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        let root = try XCTUnwrap(ProcessInfo.processInfo.environment["CODEXBAR_CI_SEED_ROOT"])
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launch.arguments = [
            "-n",
            "-a",
            "/Applications/CodexBar.app",
            "--args",
            "--widget-host-proof",
            root + "/incomplete-fixture",
        ]
        launch.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        try launch.run()
        launch.waitUntilExit()
        XCTAssertEqual(launch.terminationStatus, 0)
        waitForText("fixture-alpha", present: false)
        waitForText("Last 14 days", present: true)
        self.attach("incomplete-installed-large", app: notificationCenter)
    }

    private func waitForNotificationCenterIdentifier() -> String? {
        for attempt in 0..<10 {
            if let identifier = self.systemOwnerIdentifiers().first(where: {
                $0 == "com.apple.notificationcenterui"
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
