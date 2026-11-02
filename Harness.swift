import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct OverviewProviderFlyoutTests {
    private func controller(layout: MergedOverviewLayout) -> StatusItemController {
        let suite = "OverviewProviderFlyoutTests-\(UUID().uuidString)"
        let settings = testSettingsStore(suiteName: suite, userDefaults: InMemoryUserDefaults())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.mergedMenuLastSelectedWasOverview = true
        settings.mergedOverviewLayout = layout
        let providers: [UsageProvider] = [.claude, .codex]
        for provider in UsageProvider.allCases {
            guard let metadata = ProviderRegistry.shared.metadata[provider] else { continue }
            settings.setProviderEnabled(provider: provider, metadata: metadata, enabled: providers.contains(provider))
        }
        let fetcher = UsageFetcher()
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing)
        for provider in providers {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: 40,
                        windowMinutes: 300,
                        resetsAt: Date().addingTimeInterval(3600),
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: Date()),
                provider: provider)
        }
        return StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: testStatusBar())
    }

    /// The flyout is how detail opens, and it must not move anything in the menu it came from.
    @Test
    func `the row flyout carries the detail and leaves the parent menu alone`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let parentItems = menu.items.count

        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        let flyout = try #require(row.submenu)
        #expect(flyout is OverviewProviderDetailMenu)
        #expect(controller.isHostedSubviewMenu(flyout))
        #expect(controller.hydrateHostedSubviewMenuIfNeeded(flyout, width: 310))
        #expect(flyout.items.first?.view != nil)
        #expect(flyout.items.contains { $0.action == #selector(StatusItemController.selectOverviewProvider(_:)) })
        // A hydrated flyout stays hosted, or its next open would rebuild it as the root menu.
        #expect(controller.isHostedSubviewMenu(flyout))
        controller.menuWillOpen(flyout)
        defer { controller.menuDidClose(flyout) }
        #expect(flyout.items.first?.view != nil)
        #expect(!flyout.items.contains { $0.title == L("Quit") })
        #expect(menu.items.count == parentItems)
    }

    @Test
    func `a reopened flyout rebuilds only when its provider's data changed`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        /// No reset date, so nothing in the card ticks with the clock between opens.
        func publish(_ secondary: RateWindow?) {
            controller.store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                    secondary: secondary,
                    updatedAt: Date(timeIntervalSince1970: 1_800_000_000)),
                provider: .claude)
        }
        publish(nil)
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        let flyout = try #require(row.submenu)
        func reopen() throws -> NSView {
            controller.menuWillOpen(flyout)
            defer { controller.menuDidClose(flyout) }
            return try #require(flyout.items.first?.view)
        }
        _ = try reopen()
        let settled = try reopen()
        #expect(try reopen() === settled)

        // A new window fails the live monitor's layout check, so only this rebuild can show it.
        publish(RateWindow(usedPercent: 20, windowMinutes: 10080, resetsAt: nil, resetDescription: nil))
        let refreshed = try reopen()
        #expect(refreshed !== settled)
        #expect(flyout.items.contains { $0.action == #selector(StatusItemController.selectOverviewProvider(_:)) })
    }

    @Test
    func `an open flyout refreshes when only storage presentation changes`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        controller.settings.providerStorageFootprintsEnabled = true
        controller.store._setSnapshotForTesting(nil, provider: .claude)
        controller.store._setErrorForTesting("Synthetic provider unavailable", provider: .claude)
        let model = String(describing: controller.store.menuCardModel(for: .claude))
        let flyout = controller.makeOverviewLineSubmenu(provider: .claude, width: 310)
        controller.menuWillOpen(flyout)
        defer { controller.menuDidClose(flyout) }

        // First scan arrives, then only the total changes; finally storage is hidden.
        for bytes in [Int64(1_048_576), 2_097_152, 0] {
            let previous = try #require(flyout.items.first?.view)
            controller.store.providerStorageFootprints[.claude] = ProviderStorageFootprint(
                provider: .claude,
                totalBytes: bytes,
                paths: ["/synthetic/claude"],
                missingPaths: [],
                unreadablePaths: [],
                components: [],
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
            controller.settings.providerStorageFootprintsEnabled = bytes != 0
            #expect(String(describing: controller.store.menuCardModel(for: .claude)) == model)

            controller.refreshHostedSubviewMenu(flyout)

            let refreshed = try #require(flyout.items.first?.view)
            #expect(refreshed !== previous, "Storage-only changes must replace the captured card content")
            controller.refreshHostedSubviewMenu(flyout)
            #expect(flyout.items.first?.view === refreshed, "Unchanged storage must keep reusing the card")
        }
    }

    @Test
    func `show details in the flyout opens the provider tab from the parent menu`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-codex" })
        let flyout = try #require(row.submenu)
        #expect(controller.hydrateHostedSubviewMenuIfNeeded(flyout, width: 310))
        let open = try #require(flyout.items.first {
            $0.action == #selector(StatusItemController.selectOverviewProvider(_:))
        })
        #expect(open.menu?.supermenu === menu)

        controller.selectOverviewProvider(open)

        #expect(controller.settings.mergedMenuLastSelectedWasOverview == false)
        #expect(controller.settings.selectedMenuProvider == .codex)
    }

    /// Replays the order the packaged app logged for a real click: the nested chart closes, which queues a flyout
    /// rebuild that waits on the native highlight, then mouse-up clears that highlight just before the menus close
    /// and AppKit sends the action. Sending it directly from the item would skip all of this.
    @Test
    func `clicking show details after the chart closed selects the provider through the menu lifecycle`() async throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        controller.menuRefreshEnabledOverrideForTesting = true
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        let flyout = try #require(row.submenu)
        controller.menuWillOpen(menu)
        controller.menuWillOpen(flyout)
        let open = try self.showDetailsItem(in: flyout)
        let chartItem = try #require(flyout.items.first { $0.submenu != nil })
        let chart = try #require(chartItem.submenu)

        controller.menu(flyout, willHighlight: chartItem, eventType: .mouseMoved)
        controller.menuWillOpen(chart)
        self.publishNewClaudeData(to: controller)
        controller.menuDidClose(chart)
        controller.menu(flyout, willHighlight: open, eventType: .mouseMoved)
        await self.drainMainRunLoop()
        #expect(open.menu === flyout)

        controller.menu(flyout, willHighlight: nil, eventType: .leftMouseUp)
        controller.menu(menu, willHighlight: nil, eventType: .leftMouseUp)
        await self.drainMainRunLoop()
        #expect(open.menu === flyout)
        controller.menuDidClose(flyout)
        controller.menuDidClose(menu)
        try self.sendNativeAction(of: open)

        #expect(controller.settings.mergedMenuLastSelectedWasOverview == false)
        #expect(controller.settings.selectedMenuProvider == .claude)
        controller.menuWillOpen(menu)
        defer { controller.menuDidClose(menu) }
        #expect(!menu.items.contains { ($0.representedObject as? String) == "overviewRow-claude" })
    }

    /// A data refresh can still finish between mouse-up and the action, leaving the item without a menu.
    @Test
    func `show details still selects its provider when a rebuild detached the clicked item`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        let flyout = try #require(row.submenu)
        controller.menuWillOpen(flyout)
        defer { controller.menuDidClose(flyout) }
        let open = try self.showDetailsItem(in: flyout)

        self.publishNewClaudeData(to: controller)
        controller.refreshHostedSubviewMenu(flyout)
        #expect(open.menu == nil)
        try self.sendNativeAction(of: open)

        #expect(controller.settings.mergedMenuLastSelectedWasOverview == false)
        #expect(controller.settings.selectedMenuProvider == .claude)
    }

    private func showDetailsItem(in flyout: NSMenu) throws -> NSMenuItem {
        try #require(flyout.items.first { $0.action == #selector(StatusItemController.selectOverviewProvider(_:)) })
    }

    private func publishNewClaudeData(to controller: StatusItemController) {
        controller.store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 70, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 20, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000)),
            provider: .claude)
    }

    private func sendNativeAction(of item: NSMenuItem) throws {
        let action = try #require(item.action)
        #expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }

    /// Runs both the queued tasks and the run-loop blocks that menu rebuilds use while AppKit tracks.
    private func drainMainRunLoop() async {
        for _ in 0..<5 {
            await Task.yield()
            self.spinMainRunLoop()
        }
    }

    private func spinMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    @Test
    func `the detailed layout keeps its existing chart submenu`() throws {
        let controller = self.controller(layout: .detailed)
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        #expect(!(row.submenu is OverviewProviderDetailMenu))
    }
    @Test
    func `synthetic open storage flyout proof`() throws {
        guard let output = ProcessInfo.processInfo.environment["STORAGE_PROOF_OUT"] else { return }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .aqua)
        StatusItemController.menuCardRenderingEnabled = true
        let controller = self.controller(layout: .compact)
        defer { controller.releaseStatusItemsForTesting() }
        controller.settings.providerStorageFootprintsEnabled = true
        controller.store._setSnapshotForTesting(nil, provider: .claude)
        controller.store._setErrorForTesting("Synthetic provider unavailable", provider: .claude)
        let publish: @MainActor @Sendable (Int64) -> Void = { bytes in
            controller.store.providerStorageFootprints[.claude] = ProviderStorageFootprint(
                provider: .claude, totalBytes: bytes, paths: ["/synthetic/claude"],
                missingPaths: [], unreadablePaths: [], components: [],
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        }
        publish(1_048_576)
        let model = String(describing: controller.store.menuCardModel(for: .claude))
        let flyout = controller.makeOverviewLineSubmenu(provider: .claude, width: 310)
        let state = StorageProofState(menu: flyout)
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated {
                let flyout = state.menu
                do {
                    let request = output + "/.request"
                    guard !FileManager.default.fileExists(atPath: request) else { return }
                    switch state.phase {
                    case 0:
                        state.before = flyout.items.first?.view
                        let view = try #require(state.before)
                        view.wantsLayer = true
                        view.layer?.backgroundColor = NSColor.white.cgColor
                        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        try bitmap.representation(using: .png, properties: [:])!.write(
                            to: URL(fileURLWithPath: output + "/before.png"))
                        state.phase = 1
                    case 1:
                        publish(2_097_152)
                        controller.refreshHostedSubviewMenu(flyout)
                        #expect(String(describing: controller.store.menuCardModel(for: .claude)) == model)
                        state.changed = flyout.items.first?.view !== state.before
                        state.phase = 2
                    case 2:
                        let view = try #require(flyout.items.first?.view)
                        view.wantsLayer = true
                        view.layer?.backgroundColor = NSColor.white.cgColor
                        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        try bitmap.representation(using: .png, properties: [:])!.write(
                            to: URL(fileURLWithPath: output + "/after.png"))
                        state.phase = 3
                    default:
                        let result = "Synthetic Claude unavailable; usage model unchanged.\n" +
                            "Storage scan total: 1048576 -> 2097152 bytes.\n" +
                            "Open flyout rebuilt: \(state.changed).\n"
                        try result.write(toFile: output + "/result.txt", atomically: true, encoding: .utf8)
                        flyout.cancelTracking()
                    }
                } catch {
                    try? "\(error)".write(toFile: output + "/error.txt", atomically: true, encoding: .utf8)
                    flyout.cancelTracking()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flyout.popUp(positioning: nil, at: NSPoint(x: 500, y: 600), in: nil)
        timer.invalidate()
    }

}

@MainActor
private final class StorageProofState {
    let menu: NSMenu
    init(menu: NSMenu) { self.menu = menu }
    var phase = 0
    var before: NSView?
    var changed = false
}
