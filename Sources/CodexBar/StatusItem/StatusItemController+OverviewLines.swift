import AppKit
import CodexBarCore
import SwiftUI

extension StatusItemController {
    /// Hard cap on inline rows. NSMenu has no sticky footer, so a bounded list is what keeps Quit on screen.
    static let overviewInlineLineLimit = 12
    static let overviewProviderDetailID = "overviewProviderDetail"

    /// Compact Overview: one fixed-height line per provider, most urgent first.
    func addOverviewLinesIfCompact(
        _ rows: [MergedOverviewRow],
        _ menu: NSMenu,
        _ scopes: (visible: [ProviderInstanceID], spend: [UsageProvider]),
        _ menuWidth: CGFloat,
        _ interactionMenu: NSMenu) -> Bool
    {
        guard self.settings.mergedOverviewLayout == .compact else { return false }
        self.addOverviewLinesSummary(to: menu, providers: scopes.spend, menuWidth: menuWidth)
        self.addOverviewLineRows(
            rows,
            to: menu,
            providers: scopes.visible,
            menuWidth: menuWidth,
            interactionMenu: interactionMenu)
        return true
    }

    private func addOverviewLineRows(
        _ rows: [MergedOverviewRow],
        to menu: NSMenu,
        providers: [ProviderInstanceID],
        menuWidth: CGFloat,
        interactionMenu: NSMenu)
    {
        var pluginRows: [MergedOverviewRow] = []
        var entries: [String: MergedOverviewRow] = [:]
        var lines: [OverviewProviderLine] = []
        for row in rows {
            guard let model = row.model else {
                pluginRows.append(row)
                continue
            }
            let id = "\(Self.overviewRowIdentifierPrefix)\(row.id)"
            entries[id] = row
            lines.append(OverviewProviderLine(
                id: id,
                model: model,
                account: row.accountID == nil ? nil : model.email))
        }
        let sorted = OverviewProviderLine.sortedByUrgency(lines)
        let visibleLines = sorted.prefix(Self.overviewInlineLineLimit)
        // The heads describe bars and percentages, so they need at least one row that has them.
        if visibleLines.contains(where: { $0.percent != nil }),
           let style = rows.lazy.compactMap({ $0.model?.metrics.first?.percentStyle }).first
        {
            menu.addItem(self.makeMenuCardItem(
                OverviewLinesHeaderView(percentStyle: style, width: menuWidth),
                id: "overviewLinesHeader",
                width: menuWidth))
        }
        let attention = self.makeOverviewAttentionItem(
            providers: providers,
            menuWidth: menuWidth,
            interactionMenu: interactionMenu)
        var attentionAdded = attention == nil
        for line in visibleLines {
            guard let row = entries[line.id] else { continue }
            // A signed-out provider is stopped now, so it follows only the limits about to stop.
            if !attentionAdded, line.status != .critical, let attention {
                menu.addItem(attention)
                attentionAdded = true
            }
            menu.addItem(self.makeOverviewLineItem(
                line,
                row: row,
                menuWidth: menuWidth,
                interactionMenu: interactionMenu))
        }
        if !attentionAdded, let attention { menu.addItem(attention) }
        for row in pluginRows {
            guard let plugin = UserProviderPluginRegistry.plugin(for: row.provider) else { continue }
            let instanceID = row.provider
            let item = self.makeUserPluginMenuCardItem(
                plugin,
                width: menuWidth,
                id: "\(Self.overviewRowIdentifierPrefix)\(row.id)",
                onClick: plugin.manifest.topLevel ? { [weak self, weak interactionMenu] in
                    guard let self, let interactionMenu else { return }
                    self.selectOverviewProvider(instanceID, menu: interactionMenu)
                } : nil)
            if plugin.manifest.topLevel {
                item.target = self
                item.action = #selector(self.selectOverviewProvider(_:))
            }
            menu.addItem(item)
        }
        if sorted.count > Self.overviewInlineLineLimit {
            menu.addItem(self.makeOverviewOverflowItem(Array(sorted.dropFirst(Self.overviewInlineLineLimit))))
        }
    }

    private func makeOverviewLineItem(
        _ line: OverviewProviderLine,
        row: MergedOverviewRow,
        menuWidth: CGFloat,
        interactionMenu: NSMenu) -> NSMenuItem
    {
        let instanceID = row.provider
        let submenu = row.accountID == nil
            ? self.makeOverviewLineSubmenu(provider: line.provider, width: menuWidth)
            : nil
        let item = self.makeMenuCardItem(
            OverviewProviderLineView(line: line, width: menuWidth),
            id: line.id,
            width: menuWidth,
            heightCacheScope: "overviewLine",
            heightCacheFingerprint: "line",
            submenu: submenu,
            showsSubmenuIndicator: false,
            usesGPUSelection: true,
            onClick: { [weak self, weak interactionMenu] in
                guard let self, let interactionMenu else { return }
                self.selectOverviewProvider(instanceID, menu: interactionMenu)
            })
        if submenu == nil {
            // Keep plain rows wired for keyboard activation and accessibility action paths.
            item.target = self
            item.action = #selector(self.selectOverviewProvider(_:))
        }
        return item
    }

    /// The healthiest rows, by construction: the list is sorted before it is cut.
    private func makeOverviewOverflowItem(_ lines: [OverviewProviderLine]) -> NSMenuItem {
        let item = NSMenuItem(title: "\(L("More")) (\(lines.count))", action: nil, keyEquivalent: "")
        item.representedObject = "overviewOverflow"
        let submenu = NSMenu(title: item.title)
        submenu.autoenablesItems = false
        for line in lines {
            let title = [line.name, line.caption, line.value, line.trailing]
                .compactMap(\.self)
                .joined(separator: " · ")
            let child = NSMenuItem(title: title, action: #selector(self.selectOverviewProvider(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = line.id
            submenu.addItem(child)
        }
        item.submenu = submenu
        return item
    }

    /// Error-only providers are not limit rows, but a signed-out provider must not vanish without a word.
    private func makeOverviewAttentionItem(
        providers: [ProviderInstanceID],
        menuWidth: CGFloat,
        interactionMenu: NSMenu) -> NSMenuItem?
    {
        let failing = providers.compactMap { instanceID -> (ProviderInstanceID, UsageMenuCardView.Model)? in
            guard let provider = instanceID.firstPartyProvider else { return nil }
            let model = self.store.menuCardModel(for: provider)
            return model.isOverviewErrorOnly ? (instanceID, model) : nil
        }
        guard let first = failing.first else { return nil }
        let isSingle = failing.count == 1
        let instanceID = first.0
        let submenu = isSingle ? nil : NSMenu()
        submenu?.autoenablesItems = false
        for (id, model) in failing {
            let child = NSMenuItem(
                title: "\(model.providerName): \(model.subtitleText)",
                action: #selector(self.selectOverviewProvider(_:)),
                keyEquivalent: "")
            child.target = self
            child.representedObject = "\(Self.overviewRowIdentifierPrefix)\(id.rawValue)"
            submenu?.addItem(child)
        }
        return self.makeMenuCardItem(
            OverviewAttentionRowView(
                provider: isSingle ? first.1.provider : nil,
                name: isSingle ? first.1.providerName : nil,
                message: isSingle ? first.1.subtitleText : failing.map(\.1.providerName).joined(separator: ", "),
                width: menuWidth),
            id: "overviewAttention",
            width: menuWidth,
            heightCacheScope: "overviewLine",
            heightCacheFingerprint: "attention",
            submenu: submenu,
            usesGPUSelection: true,
            onClick: { [weak self, weak interactionMenu] in
                guard let self, let interactionMenu else { return }
                self.selectOverviewProvider(instanceID, menu: interactionMenu)
            })
    }

    /// Closes the rows. Compact Overview's share action leads the footer, where the number's flex is one click away.
    func addOverviewRowsFooter(to menu: NSMenu, enabledProviders: [UsageProvider]) {
        menu.addItem(.separator())
        guard self.settings.mergedOverviewLayout == .compact else { return }
        let providers = self.overviewProviderScopes(enabledProviders: enabledProviders).spend
        guard self.overviewSpendSubscriptionCount(providers: providers) > 0,
              let share = self.makeOverviewShareStatsMenuItem(
                  model: self.overviewSpendDashboardModel(providers: providers))
        else { return }
        menu.addItem(share)
    }

    /// The big number, the 30-day spark under it, and the model mix.
    private func addOverviewLinesSummary(to menu: NSMenu, providers: [UsageProvider], menuWidth: CGFloat) {
        let model = self.overviewSpendDashboardModel(providers: providers)
        let subscriptionCount = self.overviewSpendSubscriptionCount(providers: providers)
        guard subscriptionCount > 0 else { return }
        let knownCounts = self.overviewSpendKnownSubscriptionCounts(providers: providers, model: model)
        let summary = OverviewSpendSummary(
            model: model,
            providerCount: subscriptionCount,
            knownCostProviderCount: knownCounts.cost,
            knownTokenProviderCount: knownCounts.tokens)
        let daily = self.overviewDailySpend(model: model)
        menu.addItem(self.makeMenuCardItem(
            OverviewSpendSummaryCardView(
                summary: summary,
                days: model.requestedDays,
                daily: daily,
                width: menuWidth),
            id: "overviewSpendSummary",
            width: menuWidth,
            heightCacheScope: "overviewSpendSummary",
            heightCacheFingerprint: [
                summary.primarySpendText,
                summary.providerCoverageText,
                summary.tokenText ?? "",
                summary.historyCoverageText,
                summary.pricingCoverageText,
                summary.provenanceText,
                "daily=\(daily != nil)",
            ].joined(separator: "|"),
            containsInteractiveControls: daily != nil))
        if let modelsItem = self.makeOverviewModelsItem(model: model, width: menuWidth) {
            menu.addItem(modelsItem)
        }
        menu.addItem(.separator())
    }

    /// One line for the mix; spend per model sits in its submenu.
    func makeOverviewModelsItem(model: SpendDashboardModel, width: CGFloat) -> NSMenuItem? {
        let models = self.overviewTopModels(model: model, limit: 10)
        guard !models.isEmpty else { return nil }
        let submenu = NSMenu(title: L("Models"))
        submenu.autoenablesItems = false
        submenu.minimumWidth = width
        submenu.addItem(self.makeMenuCardItem(
            TopModelsContent(models: models, title: L("TOP MODELS"))
                .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
                .frame(width: width, alignment: .leading),
            id: "overviewModelsDetail",
            width: width))
        return self.makeMenuCardItem(
            OverviewModelMixRowView(models: Array(models.prefix(3)), width: width),
            id: "overviewModels",
            width: width,
            heightCacheScope: "overviewLine",
            heightCacheFingerprint: "models",
            submenu: submenu,
            submenuIndicatorAlignment: .trailing,
            submenuIndicatorTopPadding: 0)
    }

    /// One bar per day of the range, across providers. Single currency only: spend cannot be summed across them.
    func overviewDailySpend(model: SpendDashboardModel) -> OverviewDailySpend? {
        guard model.groups.count == 1, let group = model.groups.first, !group.dailySummaries.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = group.timeZone
        let summaries = Dictionary(
            group.dailySummaries.map { (calendar.startOfDay(for: $0.day), $0) },
            uniquingKeysWith: { first, _ in first })
        let last = max(
            calendar.startOfDay(for: group.chartDomain.upperBound),
            summaries.keys.max() ?? group.chartDomain.upperBound)
        guard let first = calendar.date(byAdding: .day, value: 1 - model.requestedDays, to: last) else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        formatter.timeZone = group.timeZone
        var points: [MenuUsageBarPoint] = []
        var day = first
        while day <= last {
            let cost = summaries[day]?.totalCost
            let valueText = cost.map { UsageFormatter.currencyString($0, currencyCode: group.currencyCode) }
            let summary = "\(formatter.string(from: day)): \(valueText ?? L("Unknown"))"
            points.append(MenuUsageBarPoint(
                id: "\(day.timeIntervalSince1970)",
                value: cost,
                hoverSummary: summary,
                accessibilityValue: summary))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        let todayStart = calendar.startOfDay(for: Date())
        let today = summaries[todayStart]?.totalCost
        return OverviewDailySpend(
            points: points,
            todayValue: today.map { UsageFormatter.currencyString($0, currencyCode: group.currencyCode) },
            todayPointID: today == nil ? nil : "\(todayStart.timeIntervalSince1970)")
    }
}
