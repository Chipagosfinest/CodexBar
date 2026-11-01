import AppKit
@testable import CodexBar
import CodexBarCore
import Foundation
import SwiftUI
import Testing

/// Dropdown proof: production `StatusItemController.populateMenu` over synthetic data. Hosted rows are the real
/// `item.view`s; native rows are drawn from the real `NSMenuItem` title, image and shortcut. Local-only target.
@MainActor
@Suite(.serialized)
struct ShipProof {
    static let now = Date()

    static func window(_ used: Double, minutes: Int, hoursToReset: Double) -> RateWindow {
        RateWindow(
            usedPercent: used,
            windowMinutes: minutes,
            resetsAt: now.addingTimeInterval(hoursToReset * 3600),
            resetDescription: nil)
    }

    static func tokens(
        _ models: [(String, Double, Int)],
        todayScale: Double,
        days: Int = 30,
        phase: Int = 0) -> CostUsageTokenSnapshot
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let weights: [Double] = [0.4, 0.7, 0.2, 1, 0.9, 0.3, 0.1, 0.6, 1.2, 0.8, 0.5, 0.9, 1.1, 0.2, 0.3]
        let daily = (0..<days).map { offset -> CostUsageDailyReport.Entry in
            let day = Self.now.addingTimeInterval(-Double(days - 1 - offset) * 86400)
            let weight = offset == days - 1 ? todayScale : weights[(offset + phase) % weights.count]
            let breakdowns = models.map { name, cost, tokens in
                CostUsageDailyReport.ModelBreakdown(
                    modelName: name,
                    costUSD: cost * weight / 18,
                    totalTokens: Int(Double(tokens) * weight / 18))
            }
            let cost = breakdowns.compactMap(\.costUSD).reduce(0, +)
            let total = breakdowns.compactMap(\.totalTokens).reduce(0, +)
            return CostUsageDailyReport.Entry(
                date: formatter.string(from: day),
                inputTokens: total / 2,
                outputTokens: total / 2,
                totalTokens: total,
                costUSD: cost,
                modelsUsed: models.map(\.0),
                modelBreakdowns: breakdowns)
        }
        let last = daily.last
        return CostUsageTokenSnapshot(
            sessionTokens: last?.totalTokens,
            sessionCostUSD: last?.costUSD,
            last30DaysTokens: daily.compactMap(\.totalTokens).reduce(0, +),
            last30DaysCostUSD: daily.compactMap(\.costUSD).reduce(0, +),
            daily: daily,
            updatedAt: Self.now)
    }

    static let five: [UsageProvider] = [.codex, .claude, .cursor, .gemini, .copilot]
    static let eight: [UsageProvider] = [.codex, .claude, .cursor, .gemini, .copilot, .factory, .windsurf, .kimi]

    static func fixture(
        codexNearLimit: Bool,
        providers: [UsageProvider] = [.codex, .claude, .cursor],
        degraded: Bool = false) -> (SettingsStore, UsageStore, UsageFetcher)
    {
        let suite = "MenuProof-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: CodexBarConfigStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("\(suite)/config.json")),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.costUsageEnabled = true
        settings.mergeIcons = true
        settings.hidePersonalInfo = false
        for provider in UsageProvider.allCases {
            guard let metadata = ProviderRegistry.shared.metadata[provider] else { continue }
            settings.setProviderEnabled(
                provider: provider,
                metadata: metadata,
                enabled: providers.contains(provider))
        }
        let environment = ["HOME": FileManager.default.temporaryDirectory.path]
        let fetcher = UsageFetcher(environment: environment)
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(homeDirectory: FileManager.default.temporaryDirectory.path, cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: environment)
        store._test_widgetSnapshotSaveOverride = { _ in }

        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: Self.window(38, minutes: 300, hoursToReset: 2.3),
                secondary: Self.window(61, minutes: 10080, hoursToReset: 62),
                tertiary: Self.window(24, minutes: 10080, hoursToReset: 62),
                providerCost: ProviderCostSnapshot(
                    used: 18.4, limit: 50, currencyCode: "USD", period: "Monthly",
                    resetsAt: now.addingTimeInterval(86400 * 12), updatedAt: now),
                updatedAt: now,
                identity: ProviderIdentitySnapshot(
                    providerID: .claude,
                    accountEmail: "sample@example.com",
                    accountOrganization: nil,
                    loginMethod: "Max")),
            provider: .claude)
        store._setTokenSnapshotForTesting(
            Self.tokens(
                [("claude-opus-4-5", 412.6, 918_000_000), ("claude-sonnet-4-5", 138.2, 402_000_000),
                 ("claude-haiku-4-5", 6.1, 31_000_000)],
                todayScale: 0.85),
            provider: .claude)

        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: Self.window(codexNearLimit ? 92 : 22, minutes: 300, hoursToReset: 1.2),
                secondary: Self.window(41, minutes: 10080, hoursToReset: 96),
                updatedAt: now,
                identity: ProviderIdentitySnapshot(
                    providerID: .codex,
                    accountEmail: "sample@example.com",
                    accountOrganization: nil,
                    loginMethod: "Pro")),
            provider: .codex)
        store._setTokenSnapshotForTesting(
            Self.tokens(
                [("gpt-5.1-codex-max", 188.4, 540_000_000), ("gpt-5.1-codex", 74.5, 260_000_000),
                 ("gpt-5-codex-mini", 9.3, 48_000_000)],
                todayScale: 0.5,
                phase: 4),
            provider: .codex)
        store.credits = CreditsSnapshot(remaining: 184.5, events: [], updatedAt: now)

        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: Self.window(47, minutes: 43200, hoursToReset: 300),
                secondary: Self.window(12, minutes: 43200, hoursToReset: 300),
                providerCost: ProviderCostSnapshot(
                    used: 7.25, limit: 20, currencyCode: "USD", period: "Monthly",
                    resetsAt: now.addingTimeInterval(86400 * 12), updatedAt: now),
                updatedAt: now,
                identity: ProviderIdentitySnapshot(
                    providerID: .cursor,
                    accountEmail: "sample@example.com",
                    accountOrganization: nil,
                    loginMethod: "Pro")),
            provider: .cursor)
        // Stress fixture: spend on every enabled provider, including ones with no cost history in production.
        store._setTokenSnapshotForTesting(
            Self.tokens(
                [("cursor-max", 61, 90_000_000), ("composer-1", 52.4, 120_000_000), ("cursor-small", 16, 30_000_000)],
                todayScale: 0.7,
                phase: 2),
            provider: .cursor)
        for (provider, models, phase) in [
            (UsageProvider.copilot, [("gpt-5-pro", 38.0, 50_000_000), ("gpt-5", 31.0, 70_000_000), ("gpt-5-mini", 9.0, 30_000_000)], 9),
            (.factory, [("claude-opus-4-1", 44.0, 40_000_000), ("glm-4.6", 22.0, 90_000_000)], 11),
            (.windsurf, [("swe-1", 26.0, 40_000_000), ("swe-1-lite", 12.0, 30_000_000)], 5),
            (.kimi, [("kimi-k2-thinking", 21.0, 30_000_000), ("kimi-k2-turbo", 9.0, 20_000_000)], 13),
        ] where providers.contains(provider) {
            store._setTokenSnapshotForTesting(
                Self.tokens(models.map { ($0.0, $0.1, $0.2) }, todayScale: 0.4, phase: phase),
                provider: provider)
        }
        if providers.contains(.gemini) {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: Self.window(degraded ? 97 : 71, minutes: 1440, hoursToReset: 4.5),
                    secondary: Self.window(33, minutes: 1440, hoursToReset: 4.5),
                    updatedAt: now,
                    identity: ProviderIdentitySnapshot(
                        providerID: .gemini, accountEmail: "sample@example.com",
                        accountOrganization: nil, loginMethod: "Pro")),
                provider: .gemini)
            store._setTokenSnapshotForTesting(
                Self.tokens(
                    [("gemini-2.5-pro", 42.4, 88_000_000), ("gemini-2.5-flash", 18.1, 40_000_000)],
                    todayScale: 0.3,
                    phase: 7),
                provider: .gemini)
        }
        if providers.contains(.copilot) {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: Self.window(58, minutes: 43200, hoursToReset: 410),
                    secondary: Self.window(12, minutes: 43200, hoursToReset: 410),
                    updatedAt: now,
                    identity: ProviderIdentitySnapshot(
                        providerID: .copilot, accountEmail: "sample@example.com",
                        accountOrganization: nil, loginMethod: "Business")),
                provider: .copilot)
        }
        if providers.contains(.factory) {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: Self.window(44, minutes: 43200, hoursToReset: 200),
                    secondary: nil,
                    updatedAt: now,
                    identity: ProviderIdentitySnapshot(
                        providerID: .factory, accountEmail: nil,
                        accountOrganization: nil, loginMethod: "Max")),
                provider: .factory)
        }
        if providers.contains(.windsurf) {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: Self.window(14, minutes: 300, hoursToReset: 3.1),
                    secondary: Self.window(29, minutes: 10080, hoursToReset: 120),
                    updatedAt: now,
                    identity: ProviderIdentitySnapshot(
                        providerID: .windsurf, accountEmail: "sample@example.com",
                        accountOrganization: nil, loginMethod: "Pro")),
                provider: .windsurf)
        }
        if providers.contains(.kimi) {
            if degraded {
                store._setErrorForTesting("Session expired. Sign in again.", provider: .kimi)
            } else {
                store._setSnapshotForTesting(
                    UsageSnapshot(
                        primary: Self.window(6, minutes: 10080, hoursToReset: 30),
                        secondary: nil,
                        updatedAt: now,
                        identity: ProviderIdentitySnapshot(
                            providerID: .kimi, accountEmail: "sample@example.com",
                            accountOrganization: nil, loginMethod: "Allegretto")),
                    provider: .kimi)
            }
        }
        if degraded {
            // Stale: last good numbers plus a failed refresh.
            store._setErrorForTesting("Refresh failed: network timeout", provider: .cursor)
        }
        return (settings, store, fetcher)
    }

    struct Scenario {
        let name: String
        var nearLimit = false
        var providers: [UsageProvider] = [.codex, .claude, .cursor]
        var degraded = false
        var accounts = 0
    }

    static let allScenarios: [Scenario] = [
        Scenario(name: "overview-3"),
        Scenario(name: "overview-8", providers: eight),
        Scenario(name: "overview-8-urgent", nearLimit: true, providers: eight, degraded: true),
        Scenario(name: "overflow-accounts", providers: [.codex, .claude], accounts: 14),
    ]

    /// Pops the real NSMenu built by production `populateMenu`. A shell watcher captures only this process's windows
    /// by window ID (the test helper has no Screen Recording grant), so nothing else on screen can appear.
    @Test
    func `pop real menus`() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["CB_OUT"] else { return }
        let wanted = Set((env["CB_SCENARIOS"] ?? "overview-8").split(separator: ",").map(String.init))
        let hoverRow = env["CB_HOVER"]
        let layout = env["CB_LAYOUT"].flatMap(MergedOverviewLayout.init(rawValue:))
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        StatusItemController.menuCardRenderingEnabled = true
        StatusItemController.setMenuRefreshEnabledForTesting(false)
        var lines: [String] = []
        let appearances: [(String, NSAppearance)] = (env["CB_APPEARANCES"] ?? "dark,light").split(separator: ",").map {
            ($0 == "dark" ? "dark" : "light", NSAppearance(named: $0 == "dark" ? .darkAqua : .aqua)!)
        }
        for (appearanceName, appearance) in appearances {
            NSApp.appearance = appearance
            for scenario in Self.allScenarios where wanted.contains(scenario.name) {
                let (settings, store, fetcher) = Self.fixture(
                    codexNearLimit: scenario.nearLimit, providers: scenario.providers, degraded: scenario.degraded)
                settings.mergedMenuLastSelectedWasOverview = true
                if let layout { settings.mergedOverviewLayout = layout }
                if scenario.accounts > 0 {
                    settings.mergedOverviewAllAccounts = true
                    for index in 0..<scenario.accounts {
                        settings.addTokenAccount(
                            provider: .claude,
                            label: "account\(index + 1)@example.com",
                            token: "fixture-\(index)")
                    }
                }
                let controller = StatusItemController(
                    store: store,
                    settings: settings,
                    account: fetcher.loadAccountInfo(),
                    updater: DisabledUpdaterController(),
                    preferencesSelection: PreferencesSelection(),
                    statusBar: .system)
                defer { controller.releaseStatusItemsForTesting() }
                let menu = controller.makeMenu()
                controller.mergedMenu = menu
                controller.populateMenu(menu, provider: nil)
                let name = "\(scenario.name)-\(appearanceName)"
                let rows = menu.items.compactMap { $0.representedObject as? String }
                    .filter { $0.hasPrefix("overviewRow-") }
                let content = menu.items.reduce(CGFloat(0)) { total, item in
                    total + (item.isHidden ? 0 : item.isSeparatorItem ? 11 : (item.view?.frame.height ?? 22))
                }
                lines.append("\(name): content \(Int(content))pt, \(rows.count) rows")
                lines.append("\(name): rows \(rows.map { $0.replacingOccurrences(of: "overviewRow-", with: "") })")
                lines.append("\(name): items \(menu.items.map { $0.isSeparatorItem ? "---" : ($0.view == nil ? $0.title : ($0.representedObject as? String ?? "view")) })")
                let start = Date()
                let box = LiveBox(menu: menu)
                let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        let elapsed = Date().timeIntervalSince(start)
                        guard elapsed > 1 else { return }
                        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                            as? [[String: Any]] ?? []
                        let own = info.filter {
                            ($0[kCGWindowOwnerPID as String] as? Int32) == ProcessInfo.processInfo.processIdentifier
                                && ($0[kCGWindowLayer as String] as? Int ?? 0) > 0
                                && ($0[kCGWindowBounds as String] as? [String: CGFloat])?["Height"] ?? 0 > 100
                        }
                        let bounds = own.compactMap { $0[kCGWindowBounds as String] as? [String: CGFloat] }
                            .max { ($0["Height"] ?? 0) < ($1["Height"] ?? 0) }
                        if !box.requested {
                            box.requested = true
                            box.line = "\(name): \(Int(bounds?["Width"] ?? 0))x\(Int(bounds?["Height"] ?? 0))"
                            if let id = own.first?[kCGWindowNumber as String] as? Int {
                                try? "\(id) \(out)/live-\(name).png"
                                    .write(toFile: "\(out)/.request", atomically: true, encoding: .utf8)
                            }
                            return
                        }
                        let pending = FileManager.default.fileExists(atPath: "\(out)/.request")
                        if let hoverRow, !pending, !box.moved,
                           let row = box.menu.items.first(where: { ($0.representedObject as? String) == hoverRow }),
                           let view = row.view, let window = view.window
                        {
                            box.moved = true
                            box.movedAt = elapsed
                            box.savedCursor = NSEvent.mouseLocation.flippedForCG
                            let location = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
                            CGWarpMouseCursorPosition(window.convertPoint(toScreen: location).flippedForCG)
                            if let event = NSEvent.mouseEvent(
                                with: .mouseMoved, location: location, modifierFlags: [],
                                timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: window.windowNumber, context: nil,
                                eventNumber: 0, clickCount: 0, pressure: 0) { NSApp.postEvent(event, atStart: false) }
                            return
                        }
                        if box.moved, !box.flyoutDone {
                            if elapsed - box.movedAt < 1.5 { return }
                            if box.hoverShots == nil {
                                box.line += " | after hover: " + own.compactMap {
                                    ($0[kCGWindowBounds as String] as? [String: CGFloat]).map {
                                        "\(Int($0["Width"] ?? 0))x\(Int($0["Height"] ?? 0))"
                                    }
                                }.joined(separator: ", ")
                                box.hoverShots = own.first.flatMap { $0[kCGWindowNumber as String] as? Int }
                                    .map { ["\($0) \(out)/live-hover-\(name).png"] } ?? []
                            }
                            if pending { return }
                            if let next = box.hoverShots?.first {
                                box.hoverShots?.removeFirst()
                                try? next.write(toFile: "\(out)/.request", atomically: true, encoding: .utf8)
                                return
                            }
                            box.flyoutDone = true
                            return
                        }
                        if !pending || elapsed > 15 {
                            if let saved = box.savedCursor { CGWarpMouseCursorPosition(saved) }
                            box.menu.cancelTracking()
                        }
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                menu.popUp(positioning: nil, at: NSPoint(x: 600, y: 1040), in: nil)
                timer.invalidate()
                lines.append(box.line)
                try? FileManager.default.removeItem(atPath: "\(out)/.request")
                menu.removeAllItems()
            }
        }
        try lines.joined(separator: "\n").write(toFile: "\(out)/live-sizes.txt", atomically: true, encoding: .utf8)
    }
}

private extension NSPoint {
    @MainActor var flippedForCG: CGPoint {
        CGPoint(x: self.x, y: (NSScreen.screens.first?.frame.height ?? 0) - self.y)
    }
}

private final class LiveBox: @unchecked Sendable {
    let menu: NSMenu
    var requested = false
    var line = ""
    var moved = false
    var movedAt: TimeInterval = 0
    var flyoutDone = false
    var savedCursor: CGPoint?
    var hoverShots: [String]?
    init(menu: NSMenu) {
        self.menu = menu
    }
}

