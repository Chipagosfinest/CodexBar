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
        let widgetFamily = environment["CODEXBAR_CI_WIDGET_FAMILY"] ?? "small"
        // Install the only gallery family proven on both runner images, then ask macOS
        // to resize that real installed widget through its public context menu.
        let galleryFamily = "small"
        let rawUpgradePhase = environment["CODEXBAR_CI_UPGRADE_PHASE"] ?? ""
        let upgradePhase = rawUpgradePhase.hasPrefix("$(") ? "" : rawUpgradePhase
        let providerProof = environment["CODEXBAR_CI_PROVIDER_SWITCH_PROOF"] ?? "1"
        guard ["0", "1"].contains(providerProof) else {
            XCTFail("Provider proof mode must be explicit")
            return
        }
        let checksProviderSwitching = providerProof == "1"
        guard ["small", "medium"].contains(widgetFamily) else {
            XCTFail("Widget family must be small or medium")
            return
        }
        guard Self.isStrictDescendant(packagedAppPath, of: runnerTemporaryPath) else {
            XCTFail("Packaged app must be a disposable runner artifact")
            return
        }

        let codexBar = XCUIApplication(bundleIdentifier: "com.steipete.codexbar.debug")
        XCTAssertTrue(
            codexBar.wait(for: .runningBackground, timeout: 10) || codexBar.wait(for: .runningForeground, timeout: 1),
            "The previously proven packaged app must be running for gallery discovery")
        if upgradePhase == "verify" {
            try self.verifyRetainedWidgetUpgrade(
                app: codexBar,
                runnerTemporaryPath: runnerTemporaryPath,
                widgetFamily: widgetFamily)
            return
        }
        guard upgradePhase.isEmpty || upgradePhase == "install" else {
            XCTFail("Upgrade phase must be install or verify")
            return
        }
        self.closeSharePreviewIfVisible(in: codexBar)
        let permissionOwner = XCUIApplication(bundleIdentifier: "com.apple.UserNotificationCenter")
        let localNetworkPrompt = permissionOwner.staticTexts.matching(NSPredicate(
            format: "value CONTAINS %@ AND value CONTAINS %@", "CodexBar", "local networks")).firstMatch
        if localNetworkPrompt.exists {
            self.attach("disposable-local-network-prompt", app: permissionOwner)
            let deny = permissionOwner.buttons.matching(identifier: "action-button-2").firstMatch
            guard deny.exists, NSScreen.screens.contains(where: { $0.frame.contains(deny.frame) }) else {
                XCTFail("Observed local-network prompt lacks its explicit deny control")
                return
            }
            deny.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            let denied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !localNetworkPrompt.exists
            }, object: nil)
            guard XCTWaiter.wait(for: [denied], timeout: 5) == .completed else {
                XCTFail("Disposable local-network prompt remained after denial")
                return
            }
        }

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
        if widgetFamily == "medium" {
            installed.rightClick()
            self.attach("installed-switcher-context-menu-before-medium", app: notificationCenter)
            // The observed menu belongs to Notification Center and exposes AppKit title text.
            let mediumActions = notificationCenter.menuItems.matching(NSPredicate(
                format: "title == %@", "Medium")).allElementsBoundByIndex.filter { item in
                item.exists && item.frame.width > 0 && item.frame.height > 0 &&
                    NSScreen.screens.contains(where: { $0.frame.contains(item.frame) })
            }
            guard mediumActions.count == 1, let medium = mediumActions.first else {
                XCTFail("Expected one observed on-screen Medium widget size action")
                return
            }
            medium.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (320...380).contains(installed.frame.width) && (140...200).contains(installed.frame.height)
            }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [resized], timeout: 10),
                .completed,
                "Medium action did not resize Switcher")
        }
        let codexProvider = installed.buttons["Codex"]
        let claudeProvider = installed.buttons["Claude"]
        XCTAssertTrue(claudeProvider.waitForExistence(timeout: 5), "Switcher lacks enabled Claude button")
        guard claudeProvider.exists else { return }
        if checksProviderSwitching {
            XCTAssertTrue(codexProvider.waitForExistence(timeout: 5), "Switcher lacks enabled empty Codex button")
            guard codexProvider.exists else { return }
            claudeProvider.click()
        } else {
            XCTAssertFalse(codexProvider.exists, "Single-provider route fixture unexpectedly has Codex enabled")
        }
        let populated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            installed.debugDescription.contains("110K") && installed.debugDescription.contains("0.45")
        }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [populated], timeout: 15),
            .completed,
            "Widget did not render the app-published synthetic Claude snapshot")
        self.attach("installed-switcher-claude-selected", app: notificationCenter)
        if checksProviderSwitching {
            codexProvider.click()
            let codexEmpty = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                installed.debugDescription.contains("Open CodexBar")
            }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [codexEmpty], timeout: 15),
                .completed,
                "Codex switch did not render its empty state")
            XCTAssertFalse(codexBar.windows["Share AI Usage"].exists, "Codex provider button opened the share preview")
            claudeProvider.click()
            let claudeUsage = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                installed.debugDescription.contains("110K tokens") && installed.debugDescription.contains("$0.45")
            }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [claudeUsage], timeout: 15),
                .completed,
                "Claude switch did not restore its synthetic usage state")
            XCTAssertFalse(codexBar.windows["Share AI Usage"].exists, "Claude provider button opened the share preview")
            self.attach("installed-switcher-provider-buttons", app: notificationCenter)
        }
        if upgradePhase == "install" {
            try self.recordUpgradeInstall(
                installed: installed,
                appPath: packagedAppPath,
                app: codexBar)
            return
        }
        self.assertWidgetSharePreviews(installed: installed, app: codexBar, widgetFamily: widgetFamily)

        let desktopCandidates = finder.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "Desktop", "Desktop"))
        let summaries = (0..<desktopCandidates.count).compactMap { index -> String? in
            let candidate = desktopCandidates.element(boundBy: index)
            guard candidate.exists, candidate.frame.width > 0, candidate.frame.height > 0 else { return nil }
            return "\(candidate.elementType) | \(candidate.identifier) | \(candidate.label) | \(candidate.frame)"
        }
        self.attachText(summaries.joined(separator: "\n"), named: "accessible-desktop-candidates")
        self.attachText(
            "A \(widgetFamily) Switcher opened populated previews through actual warm and cold widget clicks. Provider-switch proof mode: \(checksProviderSwitching). Inspect replacement evidence separately for any upgrade claim; other families remain unverified.",
            named: "widget-gallery-discovery-boundary")
    }

    private func recordUpgradeInstall(
        installed: XCUIElement,
        appPath: String,
        app: XCUIApplication) throws
    {
        let info = try self.bundleMetadata(at: appPath)
        guard info["CFBundleVersion"] as? String == "146" else {
            XCTFail("Upgrade install phase requires build 146")
            return
        }
        let state: [String: String] = [
            "schemaVersion": "1",
            "installedIdentifier": installed.identifier,
            "baselineBuild": "146",
            "selectedProvider": "claude",
        ]
        let attachment = try XCTAttachment(
            data: JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted]),
            uniformTypeIdentifier: "public.json")
        attachment.name = "retained-widget-state.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        self.attach(
            "baseline-widget-installed-before-upgrade",
            app: XCUIApplication(bundleIdentifier: "com.apple.notificationcenterui"))
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Baseline app did not quit before workflow replacement")
    }

    private func verifyRetainedWidgetUpgrade(
        app: XCUIApplication,
        runnerTemporaryPath: String,
        widgetFamily: String) throws
    {
        let proof = URL(fileURLWithPath: runnerTemporaryPath).appendingPathComponent("widget-synthetic-cli-preflight")
        let stateData = try Data(contentsOf: proof.appendingPathComponent("retained-widget-state.json"))
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: stateData) as? [String: String])
        let identifier = try XCTUnwrap(state["installedIdentifier"])
        XCTAssertEqual(state["baselineBuild"], "146")
        XCTAssertEqual(state["selectedProvider"], "claude")
        XCTAssertTrue(identifier.hasPrefix("widget-local:") && identifier.contains("com.steipete.codexbar.debug") &&
            identifier.contains("CodexBarSwitcherWidget"))
        let appPath = proof.appendingPathComponent("app/CodexBar.app").path
        let info = try self.bundleMetadata(at: appPath)
        XCTAssertEqual(info["CFBundleVersion"] as? String, "147", "Verification phase requires build 147")
        let runningReplacement = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "com.steipete.codexbar.debug"
        }
        XCTAssertEqual(
            runningReplacement?.bundleURL?.standardizedFileURL.path,
            URL(fileURLWithPath: appPath).standardizedFileURL.path)
        let notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.notificationcenterui")
        let retained = notificationCenter.descendants(matching: .any).matching(identifier: identifier)
        let installed = retained.firstMatch
        XCTAssertTrue(
            installed.waitForExistence(timeout: 15),
            "Baseline widget did not remain installed after app replacement")
        XCTAssertEqual(retained.count, 1, "Expected exactly one installed widget with the baseline identifier")
        XCTAssertTrue(
            installed.debugDescription.contains("110K tokens") && installed.debugDescription.contains("$0.45"),
            "Retained widget did not preserve selected Claude usage")
        self.attach("retained-widget-after-workflow-replacement", app: notificationCenter)
        // WidgetKit can retain the old rendered archive after an app replacement.
        // Wait for the new production affordance before attributing a click to the new route.
        let updatedShare = installed.images["Share selected usage and spend overview"]
        guard updatedShare.waitForExistence(timeout: 90) else {
            self.attach("retained-widget-awaiting-new-archive", app: notificationCenter)
            XCTFail("Retained widget did not adopt the build 147 share affordance within 90 seconds")
            return
        }
        self.attach("retained-widget-new-share-affordance", app: notificationCenter)
        self.assertWidgetSharePreviews(installed: installed, app: app, widgetFamily: widgetFamily)
    }

    private func assertWidgetSharePreviews(
        installed: XCUIElement,
        app: XCUIApplication,
        widgetFamily: String)
    {
        for phase in ["warm", "cold"] {
            if phase == "cold" {
                app.terminate()
                XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
            }
            guard NSScreen.screens.contains(where: { $0.frame.contains(installed.frame) }) else {
                XCTFail("Installed widget moved outside the captured screen")
                return
            }
            if widgetFamily == "small" {
                installed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).click()
            } else {
                let shareOverview = installed.links["Share selected usage and spend overview"]
                XCTAssertTrue(
                    shareOverview.waitForExistence(timeout: 5),
                    "Medium Switcher lacks its Share overview link")
                guard shareOverview.exists else { return }
                shareOverview.click()
            }
            let preview = app.windows["Share AI Usage"]
            XCTAssertTrue(preview.waitForExistence(timeout: 20), "Installed widget did not open \(phase) preview")
            for expected in ["Claude", "110K", "$0.45"] {
                let text = preview.staticTexts.matching(NSPredicate(
                    format: "label CONTAINS %@ OR value CONTAINS %@", expected, expected)).firstMatch
                XCTAssertTrue(text.waitForExistence(timeout: 5), "Installed \(phase) preview lacks \(expected)")
            }
            XCTAssertEqual(app.windows.matching(identifier: "Share AI Usage").count, 1)
            self.attach("installed-widget-share-\(phase)", app: app)
            self.closeSharePreviewIfVisible(in: app)
        }
    }

    private func bundleMetadata(at appPath: String) throws -> [String: Any] {
        let plist = try Data(contentsOf: URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any])
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
