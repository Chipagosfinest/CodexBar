import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct OverviewProviderLineTests {
    private func metric(
        _ title: String,
        percent: Double,
        style: UsageMenuCardView.Model.PercentStyle = .left,
        reset: String? = "Resets in 2h 18m",
        eta: TimeInterval? = nil) -> UsageMenuCardView.Model.Metric
    {
        UsageMenuCardView.Model.Metric(
            id: title,
            title: title,
            percent: percent,
            percentStyle: style,
            resetText: reset,
            detailText: nil,
            detailLeftText: nil,
            detailRightText: nil,
            pacePercent: nil,
            detailIsPaceDerived: eta != nil,
            exhaustionETASeconds: eta,
            paceOnTop: true)
    }

    private func model(
        _ provider: UsageProvider = .claude,
        metrics: [UsageMenuCardView.Model.Metric],
        error: String? = nil) -> UsageMenuCardView.Model
    {
        UsageMenuCardView.Model(
            provider: provider,
            providerName: provider.rawValue,
            email: "",
            subtitleText: error ?? "Updated just now",
            subtitleStyle: error == nil ? .info : .error,
            planText: nil,
            metrics: metrics,
            usageNotes: [],
            openAIAPIUsage: nil,
            inlineUsageDashboard: nil,
            tokenUsage: nil,
            placeholder: nil,
            progressColor: .gray)
    }

    private func line(_ provider: UsageProvider, _ percent: Double, eta: TimeInterval? = nil) -> OverviewProviderLine {
        OverviewProviderLine(
            id: provider.rawValue,
            model: self.model(provider, metrics: [self.metric("Session", percent: percent, eta: eta)]))
    }

    @Test
    func `the row shows the tightest window in either percent style`() {
        let left = OverviewProviderLine(id: "a", model: self.model(metrics: [
            self.metric("Session", percent: 62),
            self.metric("Weekly", percent: 39),
        ]))
        #expect(left.caption == "Weekly")
        #expect(left.remainingPercent == 39)
        #expect(left.percent == 39)

        let used = OverviewProviderLine(id: "a", model: self.model(metrics: [
            self.metric("Session", percent: 38, style: .used),
            self.metric("Weekly", percent: 61, style: .used),
        ]))
        #expect(used.caption == "Weekly")
        #expect(used.remainingPercent == 39)
        #expect(used.percent == 61)
    }

    @Test
    func `the value drops the suffix because the column head carries it`() {
        let line = self.line(.claude, 8)
        #expect(line.value == "8%")
        #expect(line.trailing == "2h 18m")
    }

    @Test
    func `an imminent forecast beats a lower percentage and takes the caption, not the reset column`() {
        let line = OverviewProviderLine(id: "a", model: self.model(metrics: [
            self.metric("Weekly", percent: 5),
            self.metric("Session", percent: 30, eta: 20 * 60),
        ]))
        #expect(line.caption?.hasSuffix("~20m") == true)
        #expect(line.captionIsCritical)
        #expect(line.status == .critical)
        #expect(line.remainingPercent == 30)
        #expect(line.trailing == "2h 18m")
    }

    @Test
    func `an exhausted limit outranks a forecast on another window`() {
        let line = OverviewProviderLine(id: "a", model: self.model(metrics: [
            self.metric("Session", percent: 0),
            self.metric("Weekly", percent: 60, eta: 30 * 60),
        ]))
        #expect(line.caption == "Session")
        #expect(line.remainingPercent == 0)
    }

    @Test
    func `an account row keeps its account when stale or close to running out`() {
        let imminent = OverviewProviderLine(
            id: "a",
            model: self.model(metrics: [self.metric("Session", percent: 40, eta: 20 * 60)]),
            account: "work@example.com")
        #expect(imminent.caption == "work@example.com")
        #expect(imminent.status == .critical)
        let stale = OverviewProviderLine(
            id: "a",
            model: self.model(metrics: [self.metric("Session", percent: 40)], error: "Refresh failed"),
            account: "work@example.com")
        #expect(stale.caption == "work@example.com")
        #expect(stale.status == .stale)
    }

    @Test
    func `model names that would collapse keep their full identifiers`() {
        let names = ["claude-3-5-sonnet-20240620", "claude-3-5-sonnet-20241022"]
        #expect(OverviewModelMixRowView.displayNames(names) == names)
        #expect(OverviewModelMixRowView.displayNames(["claude-opus-4-5", "gpt-5.1-codex"]) == ["Opus 4.5", "5.1 Codex"])
    }

    @Test
    func `a distant forecast does not raise an alarm`() {
        let line = self.line(.claude, 42, eta: 9 * 86400)
        #expect(line.status == .normal)
        #expect(line.trailing == "2h 18m")
    }

    @Test
    func `stale numbers never read as critical`() {
        let line = OverviewProviderLine(
            id: "a",
            model: self.model(metrics: [self.metric("Session", percent: 3)], error: "Refresh failed"))
        #expect(line.status == .stale)
        #expect(line.caption == L("stale data"))
        #expect(!line.captionIsCritical)
        #expect(line.trailing == "2h 18m")
    }

    @Test
    func `urgent rows sort by when they stop and the rest read from least left to most`() {
        let sorted = OverviewProviderLine.sortedByUrgency([
            self.line(.cursor, 70),
            self.line(.copilot, 60),
            self.line(.gemini, 3),
            self.line(.codex, 8, eta: 20 * 60),
            self.line(.claude, 39),
            self.line(.factory, 29),
        ])
        #expect(sorted.map(\.provider) == [.codex, .gemini, .factory, .claude, .copilot, .cursor])
    }

    @Test
    func `a stale row sorts by its figure instead of jumping ahead of fresh rows`() {
        let stale = OverviewProviderLine(
            id: "stale",
            model: self.model(.cursor, metrics: [self.metric("Total", percent: 53)], error: "Refresh failed"))
        let sorted = OverviewProviderLine.sortedByUrgency([stale, self.line(.claude, 39)])
        #expect(sorted.map(\.provider) == [.claude, .cursor])
    }

    @Test
    func `equal figures keep the users order and rows without a limit come last`() {
        let noLimit = OverviewProviderLine(id: "none", model: self.model(.copilot, metrics: []))
        let sorted = OverviewProviderLine.sortedByUrgency([
            noLimit,
            self.line(.cursor, 44),
            self.line(.claude, 44),
            self.line(.factory, 41),
        ])
        #expect(sorted.map(\.provider) == [.factory, .cursor, .claude, .copilot])
    }

    @Test
    func `the forecast caption says empty in words`() {
        let line = self.line(.codex, 8, eta: 20 * 60)
        #expect(line.caption == L("empty ~%@", "20m"))
        #expect(line.caption?.contains("\u{2192}") == false)
        #expect(line.captionIsCritical)
    }

    @Test
    func `the selected tab plate is neutral on both appearances`() {
        for isLight in [true, false] {
            let components = ProviderSwitcherSelectionPlate.color(isLight: isLight)
                .converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components ?? []
            #expect(components.count == 4)
            #expect(components[0] == components[1] && components[1] == components[2])
        }
    }

    @Test
    func `critical text stays readable on a light menu's glass`() {
        var components: [CGFloat] = []
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            let color = MenuHighlightStyle.criticalNSColor.usingColorSpace(.sRGB)
            components = [color?.redComponent ?? 1, color?.greenComponent ?? 1, color?.blueComponent ?? 1]
        }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let text = 0.2126 * linear(components[0]) + 0.7152 * linear(components[1]) + 0.0722 * linear(components[2])
        // 138/255 grey is what a real popped menu measures in Light Mode over a dark desktop.
        let glass = linear(138.0 / 255)
        #expect((glass + 0.05) / (text + 0.05) > 3)
    }

    @Test
    func `only a window name may be dropped from a tight row`() {
        #expect(self.line(.kimi, 94).captionIsOptional)
        #expect(!self.line(.codex, 8, eta: 20 * 60).captionIsOptional)
        let stale = OverviewProviderLine(
            id: "a",
            model: self.model(metrics: [self.metric("Session", percent: 40)], error: "Refresh failed"))
        #expect(!stale.captionIsOptional)
        let account = OverviewProviderLine(
            id: "b",
            model: self.model(metrics: [self.metric("Session", percent: 40)]),
            account: "work@example.com")
        #expect(!account.captionIsOptional)
    }

    @Test
    func `model display names keep the version and drop the vendor and build date`() {
        #expect(OverviewModelMixRowView.displayName("claude-opus-4-5") == "Opus 4.5")
        #expect(OverviewModelMixRowView.displayName("claude-sonnet-4-5-20250929") == "Sonnet 4.5")
        #expect(OverviewModelMixRowView.displayName("gpt-5.1-codex-max") == "5.1 Codex Max")
        #expect(OverviewModelMixRowView.displayName("gemini-2.5-pro") == "Gemini 2.5 Pro")
        #expect(OverviewModelMixRowView.displayName("claude") == "Claude")
    }

    @Test
    func `the overview defaults to the provider limit when nothing is selected`() throws {
        let suite = "OverviewProviderLineTests-limit-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        let active: [ProviderInstanceID] = [
            .codex, .claude, .cursor, .opencode, .warp, .gemini, .grok,
            .copilot, .kimi, .factory, .windsurf, .perplexity, .zai,
        ]
        #expect(store.resolvedMergedOverviewProviders(activeProviders: active)
            == Array(active.prefix(SettingsStore.mergedOverviewProviderLimit)))
    }

    // MARK: - Real menu

    private func controller(providers: [UsageProvider]) -> (StatusItemController, UsageStore) {
        let suite = "OverviewProviderLineTests-\(UUID().uuidString)"
        let settings = SettingsStore(
            userDefaults: UserDefaults(suiteName: suite)!,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.mergedMenuLastSelectedWasOverview = true
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
        for (index, provider) in providers.enumerated() {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: Double(10 + index),
                        windowMinutes: 300,
                        resetsAt: Date().addingTimeInterval(3600),
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: Date()),
                provider: provider)
        }
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: NSStatusBar())
        return (controller, store)
    }

    /// What a user with several providers needs: no scrolling on a 14-inch laptop, no provider left out.
    @Test
    func `eight providers all appear and the menu stays under a laptop screen`() {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let providers: [UsageProvider] = [.codex, .claude, .cursor, .gemini, .copilot, .factory, .windsurf, .kimi]
        let (controller, _) = self.controller(providers: providers)
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)

        let ids = menu.items.compactMap { $0.representedObject as? String }
        #expect(ids.filter { $0.hasPrefix("overviewRow-") }.count == providers.count)
        let height = menu.items.reduce(CGFloat(0)) { total, item in
            total + (item.isSeparatorItem ? 11 : (item.view?.frame.height ?? 22))
        }
        #expect(height <= 500, "Overview grew to \(height)pt")
        #expect(menu.items.last?.title == L("Quit"))
    }

    @Test
    func `the worst case roster still leaves the footer on a laptop screen`() {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let providers: [UsageProvider] = [
            .codex, .claude, .cursor, .gemini, .copilot, .factory, .windsurf, .kimi,
            .kiro, .amp, .warp, .augment, .devin, .perplexity, .kilo, .ollama,
        ]
        let (controller, store) = self.controller(providers: providers)
        defer { controller.releaseStatusItemsForTesting() }
        store._setSnapshotForTesting(nil, provider: .kimi)
        store._setErrorForTesting("Session expired after a very long explanation that would wrap", provider: .kimi)
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let height = menu.items.reduce(CGFloat(0)) { total, item in
            total + (item.isSeparatorItem ? 11 : (item.view?.frame.height ?? 22))
        }
        #expect(height <= 620, "Overview grew to \(height)pt")
        #expect(menu.items.last?.title == L("Quit"))
    }

    @Test
    func `a provider row is one line however many windows it has`() {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let (controller, store) = self.controller(providers: [.claude, .codex])
        defer { controller.releaseStatusItemsForTesting() }
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 20, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                tertiary: RateWindow(usedPercent: 30, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                updatedAt: Date()),
            provider: .claude)
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let rows = menu.items.filter { ($0.representedObject as? String)?.hasPrefix("overviewRow-") == true }
        #expect(rows.count == 2)
        #expect(Set(rows.compactMap { $0.view?.frame.height }).count == 1)
    }

    /// The flyout is how detail opens, and it must not move anything in the menu it came from.
    @Test
    func `the row flyout carries the detail and leaves the parent menu alone`() throws {
        let wasEnabled = StatusItemController.menuCardRenderingEnabled
        StatusItemController.menuCardRenderingEnabled = true
        defer { StatusItemController.menuCardRenderingEnabled = wasEnabled }
        let (controller, _) = self.controller(providers: [.claude, .codex])
        defer { controller.releaseStatusItemsForTesting() }
        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.populateMenu(menu, provider: nil)
        let parentItems = menu.items.count

        let row = try #require(menu.items.first { ($0.representedObject as? String) == "overviewRow-claude" })
        let flyout = try #require(row.submenu)
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
}
