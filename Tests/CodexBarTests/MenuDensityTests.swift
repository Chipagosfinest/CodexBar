import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct MenuDensityTests {
    private func metric(
        percent: Double,
        style: UsageMenuCardView.Model.PercentStyle = .left,
        detailText: String? = nil,
        left: String? = nil,
        right: String? = nil,
        paceDerived: Bool = false) -> UsageMenuCardView.Model.Metric
    {
        UsageMenuCardView.Model.Metric(
            id: "session",
            title: "Session",
            percent: percent,
            percentStyle: style,
            resetText: "Resets in 2h 18m",
            detailText: detailText,
            detailLeftText: left,
            detailRightText: right,
            pacePercent: nil,
            detailIsPaceDerived: paceDerived,
            paceOnTop: true)
    }

    @Test
    func `near limit follows remaining share in both percent styles`() {
        #expect(self.metric(percent: 8, style: .left).isNearLimit)
        #expect(!self.metric(percent: 11, style: .left).isNearLimit)
        #expect(self.metric(percent: 92, style: .used).isNearLimit)
        #expect(!self.metric(percent: 89, style: .used).isNearLimit)
    }

    @Test
    func `a favorable forecast moves to the tooltip and an unfavorable one stays visible`() {
        let favorable = self.metric(
            percent: 62, left: "16% in reserve", right: L("Lasts until reset"), paceDerived: true)
        #expect(favorable.denseWarningText == nil)
        #expect(favorable.denseHelpText(presentation: favorable.linePresentation(title: "Session"))
            .contains("16% in reserve"))

        let headroom = self.metric(
            percent: 62, right: L("%@ · %@", L("Lasts until reset"), "1.5x headroom"), paceDerived: true)
        #expect(headroom.denseWarningText == nil)

        let unfavorable = self.metric(percent: 8, right: "Projected empty in 20m", paceDerived: true)
        #expect(unfavorable.denseWarningText == "Projected empty in 20m")
    }

    @Test
    func `provider text that is not a forecast keeps its line`() {
        #expect(self.metric(percent: 50, detailText: "120 / 300 requests").denseWarningText == "120 / 300 requests")
    }

    @Test
    func `reset and freshness shorten through their localized templates`() {
        #expect(DenseMeterRow.shortReset(L("Resets in %@", "2h 18m")) == "2h 18m")
        #expect(DenseMeterRow.shortReset("unparsed text") == "unparsed text")
        #expect(DenseMeterRow.shortFreshness("\(L("Updated")) 5m ago") == "5m ago")
        #expect(DenseMeterRow.shortFreshness("Refreshing") == "Refreshing")
    }

    private func entry(_ models: [(String, Double?, Int?)]) -> CostUsageDailyReport.Entry {
        CostUsageDailyReport.Entry(
            date: "2026-10-01",
            inputTokens: 1,
            outputTokens: 1,
            totalTokens: 2,
            costUSD: 1,
            modelsUsed: models.map(\.0),
            modelBreakdowns: models.map {
                CostUsageDailyReport.ModelBreakdown(modelName: $0.0, costUSD: $0.1, totalTokens: $0.2)
            })
    }

    @Test
    func `top models rank by cost and share the total of every model`() {
        let models = UsageMenuCardView.Model.topModels(
            from: [
                self.entry([("fictional-max", 60, 10), ("fictional-standard", 25, 20)]),
                self.entry([("fictional-mini", 10, 30), ("fictional-other", 5, 40)]),
            ],
            format: { "$\(Int($0))" })
        #expect(models.map(\.name) == ["fictional-max", "fictional-standard", "fictional-mini"])
        #expect(models.map(\.shareText) == ["60%", "25%", "10%"])
        #expect(models.map(\.value) == ["$60", "$25", "$10"])
        #expect(models.map(\.tier) == [.high, .standard, .fast])
    }

    @Test
    func `top models fall back to token share when no cost is known`() {
        let models = UsageMenuCardView.Model.topModels(
            from: [self.entry([("fictional-a", nil, 900), ("fictional-b", nil, 100)])],
            format: { _ in "unused" })
        #expect(models.map(\.shareText) == ["90%", "10%"])
        #expect(models.first?.value == UsageFormatter.tokenCountString(900))
    }

    @Test
    func `a tiny model share never reads as zero`() {
        let model = InlineUsageDashboardModel.TopModel(
            id: "fictional", name: "fictional", shareFraction: 0.002, value: "$1", tier: .fast)
        #expect(model.shareText == "<1%")
    }

    @Test
    func `dashboards without a summary keep every figure`() {
        let kpis = (0..<5).map { InlineUsageDashboardModel.KPI(title: "t\($0)", value: "v", emphasis: false) }
        let model = InlineUsageDashboardModel(
            accessibilityLabel: "",
            valueStyle: .tokens,
            kpis: kpis,
            points: [],
            detailLines: [])
        #expect(model.displayedSummaryKPIs.count == 5)
    }

    @Test
    func `about and update checks live under more while quit stays on top`() {
        let section = MenuDescriptor.metaSection(updateReady: false, canCheckForUpdates: true, versionText: "1.2.3")
        var more: [MenuDescriptor.SubmenuItem] = []
        var topLevel: [String] = []
        for entry in section.entries {
            switch entry {
            case let .action(title, _): topLevel.append(title)
            case let .submenu(_, _, items): more = items
            default: break
            }
        }
        #expect(topLevel == [L("Refresh"), L("Settings..."), L("Quit")])
        #expect(more.map(\.action) == [.checkForUpdates, .about])
    }

    @Test
    func `a ready update stays at the top level`() {
        let section = MenuDescriptor.metaSection(updateReady: true)
        let hasInstall = section.entries.contains { entry in
            if case let .action(_, action) = entry { return action == .installUpdate }
            return false
        }
        #expect(hasInstall)
    }

    @Test
    func `meters keep their footprint and step out of the mask only near a limit`() {
        let size = NSSize(width: MenuBarLayoutRenderer.usageMeterWidth, height: MenuBarLayoutRenderer.usageMeterHeight)
        let calm = MenuBarLayoutRenderer.usageMetersImage(
            bars: [.init(fill: 38, isCritical: false), .init(fill: 61, isCritical: false)],
            size: size,
            tint: .labelColor)
        let hot = MenuBarLayoutRenderer.usageMetersImage(
            bars: [.init(fill: 92, isCritical: true), .init(fill: 41, isCritical: false)],
            size: size,
            tint: .labelColor)
        #expect(calm.isTemplate)
        #expect(!hot.isTemplate)
        #expect(calm.size == hot.size)
    }

    @Test
    func `model names that shorten alike keep separate identities`() {
        let long = String(repeating: "fictional-model-", count: 3)
        let models = UsageMenuCardView.Model.topModels(
            from: [self.entry([("\(long)a", 2, 1), ("\(long)b", 1, 1)])],
            format: { "$\(Int($0))" })
        #expect(models.count == 2)
        #expect(Set(models.map(\.id)).count == 2)
        #expect(models[0].name == models[1].name)
    }

    @Test
    func `the meters preset round trips and downgrades to a percentage`() {
        let layout = MenuBarLayoutPreset.iconAndMeters.layout
        #expect(layout == MenuBarLayout(lines: [[.icon, .usageMeters]]))
        #expect(MenuBarLayoutPreset.matching(MenuBarLayout(lines: [[.icon, .usageMeters]])) == .iconAndMeters)
        #expect(MenuBarLayoutToken.usageMeters.v4Compatible == .percent(window: .automatic))
        #expect(MenuBarLayoutToken.usageMeters.v6Compatible == .progressBar(window: .automatic))
    }

    @Test
    func `more holds the selected provider's status page and overview omits it`() throws {
        let suite = "MenuDensityTests-\(UUID().uuidString)"
        let settings = try SettingsStore(
            userDefaults: #require(UserDefaults(suiteName: suite)),
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        for provider in UsageProvider.allCases {
            guard let metadata = ProviderRegistry.shared.metadata[provider] else { continue }
            settings.setProviderEnabled(
                provider: provider,
                metadata: metadata,
                enabled: [.codex, .claude].contains(provider))
        }
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)
        defer { controller.releaseStatusItemsForTesting() }

        func moreTitles(_ menu: NSMenu) -> [String] {
            menu.items.first { $0.title == L("More") }?.submenu?.items.map(\.title) ?? []
        }
        let providerMenu = controller.makeMenu(for: .claude)
        controller.populateMenu(providerMenu, provider: .claude)
        #expect(moreTitles(providerMenu).contains(L("Status Page")))
        #expect(!providerMenu.items.contains { $0.title == L("Status Page") })
        #expect(providerMenu.items.contains { $0.title == L("Usage Dashboard") })

        settings.mergedMenuLastSelectedWasOverview = true
        let overview = controller.makeMenu()
        controller.mergedMenu = overview
        controller.populateMenu(overview, provider: nil)
        #expect(!moreTitles(overview).contains(L("Status Page")))
        #expect(moreTitles(overview).contains { $0.hasPrefix(L("About CodexBar")) })
    }
}
