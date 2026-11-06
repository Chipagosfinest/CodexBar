import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct MenuBarUsageTotalTests {
    private typealias Entry = MenuBarUsageTotal.Entry

    private static func options(
        showUsed: Bool = false,
        highContrast: Bool = false,
        verticalAdjustment: Int = 0) -> MenuBarLayoutRenderOptions
    {
        MenuBarLayoutRenderOptions(
            size: .regular,
            highContrast: highContrast,
            showUsed: showUsed,
            conditionals: [],
            appearanceName: NSAppearance.Name.darkAqua.rawValue,
            isDebugApp: false,
            isStale: false,
            verticalAdjustment: verticalAdjustment,
            now: Date())
    }

    private static func window(used: Double) -> RateWindow {
        RateWindow(usedPercent: used, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
    }

    private static func snapshot(used: Double, weeklyUsed: Double? = nil) -> UsageSnapshot {
        UsageSnapshot(
            primary: self.window(used: used),
            secondary: weeklyUsed.map {
                RateWindow(usedPercent: $0, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
            },
            updatedAt: Date())
    }

    private static func data(
        session: Double?,
        weekly: Double? = nil,
        scoped: Double? = nil,
        automatic: Double? = nil,
        automaticText: String? = nil) -> MenuBarLayoutRenderData
    {
        let render = { (used: Double?) in used.flatMap { MenuBarLayoutRenderWindow(Self.window(used: $0)) } }
        return MenuBarLayoutRenderData(
            provider: UsageProvider.claude.instanceID,
            iconKey: UsageProvider.claude.rawValue,
            providerName: "Claude",
            accountLabel: nil,
            laneLabels: MenuBarLayoutLaneLabels(provider: .claude, snapshot: nil),
            primary: render(session),
            secondary: render(weekly),
            tertiary: nil,
            session: render(session),
            weekly: render(weekly),
            scopedWeekly: render(scoped),
            scopedWeeklyTitle: nil,
            automatic: render(automatic),
            automaticText: automaticText,
            sessionPace: nil,
            weeklyPace: nil,
            automaticPace: nil,
            runsOut: nil,
            balance: nil,
            costToday: nil,
            cost30d: nil,
            metrics: MenuBarLayoutRenderMetrics(
                sessionPaceDelta: nil,
                weeklyPaceDelta: nil,
                automaticPaceDelta: nil,
                runsOutMinutes: nil,
                balanceRemainingUSD: nil,
                balanceUsedUSD: nil,
                costTodayUSD: nil,
                cost30dUSD: nil))
    }

    // MARK: - The reading

    @Test
    func `total averages each provider and keeps no reading without quotas`() throws {
        #expect(MenuBarUsageTotal(entries: []) == nil)
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 80, isStale: false),
            Entry(provider: .codex, remainingPercent: 40, isStale: false),
        ]))
        #expect(total.averageRemainingPercent == 60)
        #expect(total.providerCount == 2)
        #expect(total.nearLimit.isEmpty)
    }

    @Test
    func `near limit starts at ten percent left with the tightest provider first`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .cursor, remainingPercent: 10.5, isStale: false),
            Entry(provider: .codex, remainingPercent: 10, isStale: false),
            Entry(provider: .gemini, remainingPercent: 4, isStale: false),
            Entry(provider: .claude, remainingPercent: 4, isStale: false),
        ]))
        // Equal limits keep the user's provider order, so the warning does not flip between refreshes.
        #expect(total.nearLimit.map(\.provider) == [.gemini, .claude, .codex])
    }

    @Test
    func `a forecast within the hour warns like the dropdown does`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 40, isStale: false, runsOutMinutes: 45),
            Entry(provider: .cursor, remainingPercent: 40, isStale: false, runsOutMinutes: 61),
            Entry(provider: .codex, remainingPercent: 5, isStale: false),
            Entry(provider: .gemini, remainingPercent: 40, isStale: true, runsOutMinutes: 5),
        ]))
        // Limits left low come first; a forecast only says when one will get there.
        #expect(total.nearLimit.map(\.provider) == [.codex, .claude])
    }

    @Test
    func `stale data never raises the warning but still counts toward the total`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 2, isStale: true),
            Entry(provider: .codex, remainingPercent: 60, isStale: false),
        ]))
        #expect(total.nearLimit.isEmpty)
        #expect(total.averageRemainingPercent == 31)
        #expect(!total.isStale)

        let allStale = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 2, isStale: true),
        ]))
        #expect(allStale.isStale)
    }

    @Test
    func `a provider reads as its tightest limit`() {
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: Self.data(session: 20, weekly: 70)) == 30)
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: Self.data(session: 20, weekly: 30, scoped: 95)) == 5)
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: Self.data(session: nil, automatic: 25)) == 75)
    }

    @Test
    func `a measured quota outside the semantic lanes can still be the tightest`() {
        // Cursor-shaped: Auto is the weekly lane while Total only exists as a raw window.
        let data = Self.data(session: nil, weekly: 30)
        let total = Self.window(used: 95)
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: data) == 70)
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: data, measured: [total]) == 5)

        let balance = Self.data(session: nil, automatic: 99, automaticText: "$4.20")
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: balance, measured: []) == nil)
    }

    @Test
    func `balance backed lanes are not quotas`() {
        // Their automatic percent is meaningless, which is why the existing bar token refuses to draw it.
        let balance = Self.data(session: nil, automatic: 99, automaticText: "$4.20")
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: balance) == nil)
        #expect(MenuBarUsageTotal.tightestRemainingPercent(data: Self.data(session: nil)) == nil)
    }

    // MARK: - Rendering

    @Test(arguments: [false, true], [false, true])
    func `saved vertical adjustment moves every total attachment equally`(
        highContrast: Bool, warning: Bool) throws
    {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: warning ? 8 : 62, isStale: false),
        ]))
        let logo = try #require(ProviderBrandIcon.image(for: .claude))
        let original = MenuBarLayoutRenderer.renderUsageTotal(
            total, logo: logo, options: Self.options(highContrast: highContrast))
        let originalBaselines = Self.attachmentBaselines(original.attributedTitle)
        #expect(originalBaselines.count == (highContrast ? 1 : 0) + (warning ? 1 : 0))
        if !highContrast, !warning {
            // The ordinary calm state is an image, covered by the leading-icon rendering contract.
            #expect(originalBaselines.isEmpty)
            #expect(original.leadingIcon?.isTemplate == true)
        }
        for adjustment in [-3, 3] {
            let shifted = MenuBarLayoutRenderer.renderUsageTotal(
                total,
                logo: logo,
                options: Self.options(highContrast: highContrast, verticalAdjustment: adjustment))
            let shiftedBaselines = Self.attachmentBaselines(shifted.attributedTitle)
            #expect(shiftedBaselines.count == originalBaselines.count)
            for (before, after) in zip(originalBaselines, shiftedBaselines) {
                #expect(abs((after - before) - CGFloat(adjustment)) < 0.001)
            }
            #expect(shifted.statusItemWidth(gap: .regular) == original.statusItemWidth(gap: .regular))
            #expect(shifted.accessibilityLabel == original.accessibilityLabel)
        }
    }

    private static func attachmentBaselines(_ title: NSAttributedString) -> [CGFloat] {
        var baselines: [CGFloat] = []
        title.enumerateAttribute(.attachment, in: NSRange(location: 0, length: title.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            let offset = (title.attribute(.baselineOffset, at: range.location, effectiveRange: nil) as? NSNumber)?
                .doubleValue ?? 0
            // Either attachment bounds or attributed baseline can implement the saved nudge.
            baselines.append(attachment.bounds.minY + CGFloat(offset))
        }
        return baselines
    }

    @Test
    func `calm total is one template image so AppKit tints it for any menu bar`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 62, isStale: false),
        ]))
        let rendered = MenuBarLayoutRenderer.renderUsageTotal(total, logo: nil, options: Self.options())
        let image = try #require(rendered.leadingIcon)
        #expect(image.isTemplate)
        #expect(rendered.attributedTitle.length == 0)
        #expect(rendered.accessibilityLabel.contains("62%"))
    }

    @Test
    func `warning names the provider with its logo and a capsule that ignores the wallpaper`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 8, isStale: false),
            Entry(provider: .codex, remainingPercent: 90, isStale: false),
        ]))
        let logo = try #require(ProviderBrandIcon.image(for: .claude))
        let calm = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 88, isStale: false),
        ]))
        let calmImage = try #require(MenuBarLayoutRenderer.renderUsageTotal(calm, logo: nil, options: Self.options())
            .leadingIcon)

        let rendered = MenuBarLayoutRenderer.renderUsageTotal(total, logo: logo, options: Self.options())
        // Meter and logo stay a native template; only the warning capsule carries its own colour.
        let neutral = try #require(rendered.leadingIcon)
        #expect(neutral.isTemplate)
        let attachment = try #require(rendered.attributedTitle.attribute(
            .attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
        let capsule = try #require(attachment.image)
        #expect(!capsule.isTemplate)
        #expect(rendered.accessibilityLabel.contains("Claude"))
        #expect(rendered.accessibilityLabel.contains("8%"))
        #expect(rendered.accessibilityLabel.contains("49%"))
        // The warning stays compact: it trades the total's digits for a logo and the capsule.
        #expect(rendered.statusItemWidth(gap: .regular) - calmImage.size.width <= 40)
    }

    @Test
    func `warning without a logo still names the provider`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 3, isStale: false),
        ]))
        let rendered = MenuBarLayoutRenderer.renderUsageTotal(total, logo: nil, options: Self.options())
        #expect(rendered.accessibilityLabel.contains("Claude"))
        #expect(rendered.attributedTitle.length > 0)
    }

    @Test
    func `show used follows the setting everywhere`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 8, isStale: false),
            Entry(provider: .codex, remainingPercent: 90, isStale: false),
        ]))
        let rendered = MenuBarLayoutRenderer.renderUsageTotal(
            total,
            logo: nil,
            options: Self.options(showUsed: true))
        #expect(rendered.accessibilityLabel.contains("92%"))
        #expect(rendered.accessibilityLabel.contains("51%"))
    }

    @Test
    func `no quota reading renders a placeholder rather than an empty item`() throws {
        let rendered = MenuBarLayoutRenderer.renderUsageTotal(nil, logo: nil, options: Self.options())
        let image = try #require(rendered.leadingIcon)
        #expect(image.isTemplate)
        #expect(!rendered.accessibilityLabel.isEmpty)
    }

    // MARK: - Status item

    @Test
    func `all providers source drives the merged status item and leaves other sources alone`() throws {
        let settings = testSettingsStore(suiteName: "MenuBarUsageTotalTests-source")
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuBarShowsBrandIconWithPercent = true
        settings.selectedMenuProvider = .codex

        let registry = ProviderRegistry.shared
        for provider in [UsageProvider.codex, .claude] {
            try settings.setProviderEnabled(
                provider: provider,
                metadata: #require(registry.metadata[provider]),
                enabled: true)
        }
        let fetcher = UsageFetcher()
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        store._setSnapshotForTesting(Self.snapshot(used: 40), provider: .codex)
        store._setSnapshotForTesting(Self.snapshot(used: 20, weeklyUsed: 96), provider: .claude)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)
        defer { controller.releaseStatusItemsForTesting() }
        let button = try #require(controller.statusItem.button)

        #expect(settings.unifiedIconSource == .currentSelection)
        controller.updateIcons()
        #expect(button.accessibilityTitle()?.contains("near limit") != true)

        settings.unifiedIconSource = .allProviders
        controller.updateIcons()
        let total = try #require(controller.menuBarUsageTotal())
        #expect(total.providerCount == 2)
        #expect(total.nearLimit.map(\.provider) == [.claude])
        #expect(total.averageRemainingPercent == 32)
        #expect(button.accessibilityTitle()?.contains("Claude") == true)
        #expect(button.accessibilityTitle()?.contains("4%") == true)
        #expect(button.attributedTitle.length > 0)
        #expect(button.image?.isTemplate == true)
        let observed = controller.storeIconObservationSignature()

        // A quota on a provider that is not the primary still reaches the status item.
        store._setSnapshotForTesting(Self.snapshot(used: 41), provider: .codex)
        #expect(controller.storeIconObservationSignature() != observed)

        store._setSnapshotForTesting(Self.snapshot(used: 20, weeklyUsed: 30), provider: .claude)
        controller.updateIcons()
        #expect(button.attributedTitle.length == 0)
        #expect(button.accessibilityTitle()?.contains("near limit") != true)

        // Leaving mid-warning must not strand the capsule on the shared merged status item.
        store._setSnapshotForTesting(Self.snapshot(used: 20, weeklyUsed: 96), provider: .claude)
        controller.updateIcons()
        #expect(button.attributedTitle.length > 0)
        for style in [false, true] {
            settings.unifiedIconSource = .allProviders
            settings.menuBarShowsBrandIconWithPercent = style
            controller.updateIcons()
            #expect(button.accessibilityTitle()?.contains("near limit") == true)
            settings.unifiedIconSource = .currentSelection
            controller.updateIcons()
            #expect(button.accessibilityTitle()?.contains("near limit") != true)
            #expect(button.attributedTitle.containsAttachments == false)
        }
    }

    @Test
    func `a session forecast warns even when the weekly window would last`() throws {
        let settings = testSettingsStore(suiteName: "MenuBarUsageTotalTests-session-forecast")
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.unifiedIconSource = .allProviders
        try settings.setProviderEnabled(
            provider: .claude,
            metadata: #require(ProviderRegistry.shared.metadata[.claude]),
            enabled: true)
        let fetcher = UsageFetcher()
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let now = Date()
        // One hour in, 60% used: 40 minutes left. The weekly window, used by the layout metric, has about 16 hours.
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(
                    usedPercent: 60,
                    windowMinutes: 300,
                    resetsAt: now.addingTimeInterval(4 * 3600),
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: 60,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(6 * 86400),
                    resetDescription: nil),
                updatedAt: now),
            provider: .claude)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)
        defer { controller.releaseStatusItemsForTesting() }

        let total = try #require(controller.menuBarUsageTotal(now: now))
        #expect(total.nearLimit.map(\.provider) == [.claude])
        #expect(total.nearLimit.first?.remainingPercent == 40)
    }

    private static func totalController(
        suite: String,
        provider: UsageProvider,
        snapshot: UsageSnapshot) throws -> (StatusItemController, SettingsStore)
    {
        let settings = testSettingsStore(suiteName: suite)
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.unifiedIconSource = .allProviders
        // Merging needs two enabled providers; the one without a snapshot stays out of the total.
        for enabled in [UsageProvider.codex, .claude] {
            try settings.setProviderEnabled(
                provider: enabled,
                metadata: #require(ProviderRegistry.shared.metadata[enabled]),
                enabled: true)
        }
        let fetcher = UsageFetcher()
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        store._setSnapshotForTesting(snapshot, provider: provider)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)
        return (controller, settings)
    }

    @Test
    func `a limit whose reset has passed no longer warns`() throws {
        let now = Date()
        let (controller, _) = try Self.totalController(
            suite: "MenuBarUsageTotalTests-reset",
            provider: .codex,
            snapshot: UsageSnapshot(
                primary: RateWindow(
                    usedPercent: 1,
                    windowMinutes: 300,
                    resetsAt: now.addingTimeInterval(3600),
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: 100,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(-10),
                    resetDescription: nil),
                updatedAt: now))
        defer { controller.releaseStatusItemsForTesting() }

        let total = try #require(controller.menuBarUsageTotal(now: now))
        #expect(total.nearLimit.isEmpty)
        #expect(total.averageRemainingPercent == 99)
    }

    @Test
    func `the warning follows the clock on manual refresh in every menu bar style`() throws {
        let now = Date()
        // One hour in at 60% used warns; 35 idle minutes later the same usage lasts more than an hour.
        let (controller, settings) = try Self.totalController(
            suite: "MenuBarUsageTotalTests-clock",
            provider: .claude,
            snapshot: UsageSnapshot(
                primary: RateWindow(
                    usedPercent: 60,
                    windowMinutes: 300,
                    resetsAt: now.addingTimeInterval(4 * 3600),
                    resetDescription: nil),
                secondary: nil,
                updatedAt: now))
        defer { controller.releaseStatusItemsForTesting() }

        #expect(try #require(controller.menuBarUsageTotal(now: now)).nearLimit.map(\.provider) == [.claude])
        #expect(try #require(controller.menuBarUsageTotal(now: now.addingTimeInterval(35 * 60))).nearLimit.isEmpty)

        controller.updateIcons()
        #expect(controller._test_isMenuBarCountdownRefreshScheduled())
        settings.unifiedIconSource = .currentSelection
        controller.updateIcons()
        #expect(!controller._test_isMenuBarCountdownRefreshScheduled())
    }

    @Test
    func `all providers choice is opt in and persists`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: "MenuBarUsageTotalTests-prefs", userDefaults: defaults)
        defer { settings.configFileWatcher?.stop() }
        #expect(settings.unifiedIconSource == .currentSelection)
        settings.unifiedIconSource = .allProviders
        #expect(defaults.string(forKey: "unifiedIconSource") == "allProviders")
        #expect(!settings.menuBarShowsHighestUsage)
    }

    @Test
    func `high contrast tints the neutral part instead of using a template`() throws {
        let total = try #require(MenuBarUsageTotal(entries: [
            Entry(provider: .claude, remainingPercent: 62, isStale: false),
        ]))
        let options = MenuBarLayoutRenderOptions(
            size: .regular,
            highContrast: true,
            showUsed: false,
            conditionals: [],
            appearanceName: NSAppearance.Name.darkAqua.rawValue,
            isDebugApp: false,
            isStale: false,
            now: Date())
        let rendered = MenuBarLayoutRenderer.renderUsageTotal(total, logo: nil, options: options)
        #expect(rendered.leadingIcon == nil)
        #expect(rendered.attributedTitle.length > 0)
    }
}
