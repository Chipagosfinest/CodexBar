import AppKit
import CodexBarCore
import Foundation
import SwiftUI

struct OverviewSpendSummary: Equatable {
    let primarySpendText: String
    let providerCoverageText: String
    let tokenText: String?
    let historyCoverageText: String
    let pricingCoverageText: String
    let provenanceText: String
    let isPartial: Bool

    init(
        model: SpendDashboardModel,
        providerCount: Int,
        knownCostProviderCount: Int? = nil,
        knownTokenProviderCount: Int? = nil)
    {
        let includedProviders = model.groups.flatMap(\.providers)
        let subscriptionProviders = includedProviders.filter { $0.sourceKind != .localHistory }
        let providerCount = max(max(0, providerCount), subscriptionProviders.count)
        let pricedProviderCount = subscriptionProviders.count { $0.totalCost != nil }
        let tokenProviderCount = subscriptionProviders.count { $0.totalTokens != nil }
        let resolvedKnownCostProviderCount = knownCostProviderCount.map {
            min(providerCount, max(pricedProviderCount, $0))
        }
        let isPartial = pricedProviderCount > 0 &&
            (resolvedKnownCostProviderCount ?? pricedProviderCount) < providerCount
        self.isPartial = isPartial

        if model.groups.isEmpty {
            self.primarySpendText = providerCount > 0 && resolvedKnownCostProviderCount == providerCount
                ? L("No usage yet")
                : L("Spend unavailable")
        } else {
            self.primarySpendText = model.groups.map { group in
                let text = spendDashboardGroupCostText(group)
                guard isPartial, group.totalCost != nil, !text.hasPrefix("~") else { return text }
                return "~\(text)"
            }.joined(separator: " · ")
        }
        self.providerCoverageText = L(
            "%d of %d subscriptions have spend",
            pricedProviderCount,
            providerCount)

        let tokens = Self.safeTokenSum(model.groups.compactMap(\.totalTokens))
        self.tokenText = tokens.map {
            let value = ShareStatsFormatting.compactCount($0)
            let resolvedKnownTokenProviderCount = knownTokenProviderCount.map {
                min(providerCount, max(tokenProviderCount, $0))
            }
            let isPartial = if let resolvedKnownTokenProviderCount {
                resolvedKnownTokenProviderCount < providerCount
            } else {
                tokenProviderCount < providerCount
            }
            return L("%@ tokens", isPartial ? "~\(value)" : value)
        }

        let coveredDays = model.groups.map(\.coveredDayCount).min() ?? 0
        self.historyCoverageText = spendDashboardCoverageText(
            covered: coveredDays,
            requested: model.requestedDays)

        let coverage = model.groups.reduce(into: CostUsageCoverageAccumulator()) { result, group in
            result.merge(group.coverageAccumulator)
        }
        self.pricingCoverageText = spendDashboardCoverageChipText(coverage.counts)
        self.provenanceText = model.groups
            .map(\.provenance)
            .reduce(into: [CostProvenance]()) { values, provenance in
                guard !values.contains(provenance) else { return }
                values.append(provenance)
            }
            .map(spendDashboardProvenanceText)
            .joined(separator: " · ")
    }

    private static func safeTokenSum(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        var total = 0
        for value in values {
            let result = total.addingReportingOverflow(value)
            guard !result.overflow else { return nil }
            total = result.partialValue
        }
        return total
    }
}

struct OverviewSpendSummaryCardView: View {
    let summary: OverviewSpendSummary
    let days: Int
    var topModels: [InlineUsageDashboardModel.TopModel] = []
    var daily: OverviewDailySpend?
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: self.daily == nil ? 8 : 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // The share card's voice: the one figure on this surface allowed to be big.
                Text(self.summary.primarySpendText)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                Text(spendDashboardDayRangeText(self.days))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let tokenText = self.summary.tokenText {
                    Text(tokenText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if self.summary.isPartial, self.daily == nil {
                Text(self.summary.providerCoverageText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let daily {
                OverviewDailySpendStrip(daily: daily)
            }
            if !self.topModels.isEmpty {
                TopModelsContent(models: self.topModels, title: L("TOP MODELS"))
            }
        }
        .help([
            self.summary.providerCoverageText,
            "\(self.summary.historyCoverageText) · \(self.summary.provenanceText)",
            self.summary.pricingCoverageText,
        ].joined(separator: "\n"))
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .padding(.vertical, 6)
        .frame(width: self.width, alignment: .leading)
    }
}

/// The in-flight overview share presentation. `generation` identifies it so a task that resumes
/// after being superseded clears only its own handle and never its successor's.
struct OverviewSharePresentation {
    var task: Task<Void, Never>?
    var generation: UInt64 = 0
}

extension StatusItemController {
    func makeOverviewShareStatsMenuItem(model: SpendDashboardModel) -> NSMenuItem? {
        guard ShareStatsPayloadFactory.make(model: model, store: self.store) != nil else { return nil }
        let title = L("Share Usage Snapshot…")
        let item = NSMenuItem(
            title: title,
            action: #selector(self.presentOverviewShareStats),
            keyEquivalent: "")
        item.target = self
        item.representedObject = "overviewShareStats"
        if let image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: title) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        return item
    }

    /// Top models across every provider, in the dashboard's own ranking. Empty when its history is incomplete.
    func overviewTopModels(
        model: SpendDashboardModel,
        limit: Int = 3) -> [InlineUsageDashboardModel.TopModel]
    {
        guard model.groups.count == 1, let group = model.groups.first,
              group.modelHistoryCompleteness == .complete
        else { return [] }
        let rows = group.models
        let totalCost = rows.compactMap(\.totalCost).reduce(0, +)
        let totalTokens = rows.compactMap(\.totalTokens).reduce(0) { $0 + Double($1) }
        let usesCost = totalCost > 0
        let total = usesCost ? totalCost : totalTokens
        guard total > 0 else { return [] }
        return rows
            .sorted { ($0.totalCost ?? 0, $0.totalTokens ?? 0) > ($1.totalCost ?? 0, $1.totalTokens ?? 0) }
            .prefix(limit)
            .map { row in
                InlineUsageDashboardModel.TopModel(
                    id: row.id,
                    name: row.modelName,
                    shareFraction: (usesCost ? row.totalCost ?? 0 : Double(row.totalTokens ?? 0)) / total,
                    value: usesCost
                        ? UsageFormatter.currencyString(row.totalCost ?? 0, currencyCode: group.currencyCode)
                        : UsageFormatter.tokenCountString(row.totalTokens ?? 0),
                    tier: .classify(row.modelName))
            }
    }

    @objc func presentOverviewShareStats() {
        if let payload = self.overviewShareStatsPayload() {
            self.overviewSharePresentation.task?.cancel()
            self.overviewSharePresentation.task = nil
            ShareStatsPresenter.shared.present(payload: payload)
            return
        }
        guard self.overviewSharePresentation.task == nil else { return }

        let dashboard = self.store.sharedSpendDashboardController()
        let configuration = SpendDashboardSource.configuration(settings: self.settings, store: self.store)
        dashboard.update(configuration: configuration)
        if !dashboard.isRefreshing {
            dashboard.refresh()
        }
        self.overviewSharePresentation.generation &+= 1
        let generation = self.overviewSharePresentation.generation
        self.overviewSharePresentation.task = Task { @MainActor [weak self, weak dashboard] in
            defer {
                if self?.overviewSharePresentation.generation == generation {
                    self?.overviewSharePresentation.task = nil
                }
            }
            guard let dashboard else { return }
            for _ in 0..<200 where dashboard.isRefreshing {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
            }
            guard !Task.isCancelled, let self else { return }
            if let payload = self.overviewShareStatsPayload() {
                ShareStatsPresenter.shared.present(payload: payload)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                self.presentLoginAlert(
                    title: L("Usage snapshot unavailable"),
                    message: L("CodexBar couldn't prepare a shareable usage snapshot. "
                        + "Refresh Usage & Spend and try again."))
            }
        }
    }

    func overviewShareStatsPayload(now: Date = Date()) -> ShareStatsPayload? {
        let enabledProviders = self.store.enabledFirstPartyProvidersForDisplay()
        let providers = self.overviewProviderScopes(enabledProviders: enabledProviders).spend
        let model = self.overviewSpendDashboardModel(providers: providers, now: now)
        return ShareStatsPayloadFactory.make(model: model, store: self.store)
    }

    func overviewSpendSubscriptionCount(providers: [UsageProvider]) -> Int {
        let providerScope = Set(providers)
        let publication = self.store.spendDashboardPublication
        guard let configuration = publication.configuration,
              configuration.menuOwnershipFingerprint == SpendDashboardSource.currentMenuOwnershipFingerprint(
                  settings: self.settings,
                  store: self.store)
        else {
            // Provider-specific by design: Pi contributes local history, not subscription coverage.
            return providerScope.count { $0 != .pi }
        }
        return publication.subscriptionCount(
            providerScope: providerScope,
            hiddenSourceIDs: Set(self.settings.spendDashboardHiddenSourceIDs),
            hideNativeCodexWhenOpenCodexPresent: self.settings.hideNativeCodexCostWhenOpenCodexPresent)
    }

    func overviewSpendKnownSubscriptionCounts(
        providers: [UsageProvider],
        model: SpendDashboardModel) -> (cost: Int, tokens: Int)
    {
        let providerScope = Set(providers)
        let publication = self.store.spendDashboardPublication
        guard let configuration = publication.configuration,
              configuration.menuOwnershipFingerprint == SpendDashboardSource.currentMenuOwnershipFingerprint(
                  settings: self.settings,
                  store: self.store)
        else { return (0, 0) }
        let hiddenSourceIDs = Set(self.settings.spendDashboardHiddenSourceIDs)
        return (
            publication.knownCostSubscriptionCount(
                model: model,
                providerScope: providerScope,
                hiddenSourceIDs: hiddenSourceIDs,
                hideNativeCodexWhenOpenCodexPresent: self.settings.hideNativeCodexCostWhenOpenCodexPresent),
            publication.knownTokenSubscriptionCount(
                model: model,
                providerScope: providerScope,
                hiddenSourceIDs: hiddenSourceIDs,
                hideNativeCodexWhenOpenCodexPresent: self.settings.hideNativeCodexCostWhenOpenCodexPresent))
    }

    func overviewSpendDashboardModel(
        providers: [UsageProvider],
        now: Date = Date()) -> SpendDashboardModel
    {
        let publication = self.store.spendDashboardPublication
        if let configuration = publication.configuration {
            guard configuration.menuOwnershipFingerprint == SpendDashboardSource.currentMenuOwnershipFingerprint(
                settings: self.settings,
                store: self.store)
            else {
                return SpendDashboardModel.build(
                    inputs: [],
                    requestedDays: self.settings.costUsageHistoryDays,
                    reportingPeriod: self.settings.costReportingPeriod,
                    now: now,
                    calendar: self.settings.costUsageBucketCalendar,
                    preferredCurrencyCode: self.settings.preferredCurrencyCode)
            }
            return publication.model(
                requestedDays: self.settings.costUsageHistoryDays,
                reportingPeriod: self.settings.costReportingPeriod,
                now: now,
                calendar: self.settings.costUsageBucketCalendar,
                preferredCurrencyCode: self.settings.preferredCurrencyCode,
                hiddenSourceIDs: Set(self.settings.spendDashboardHiddenSourceIDs),
                hideNativeCodexWhenOpenCodexPresent: self.settings.hideNativeCodexCostWhenOpenCodexPresent,
                providerScope: Set(providers))
        }
        let inputs = providers.compactMap { provider -> SpendDashboardModel.ProviderInput? in
            // Provider-level snapshots cannot honor account-level source exclusions before publication.
            guard self.settings.spendDashboardHiddenSourceIDs.isEmpty else { return nil }
            guard let snapshot = self.store.tokenSnapshotForCurrentProviderConfig(for: provider)?.snapshot else {
                return nil
            }
            return SpendDashboardModel.ProviderInput(
                provider: provider,
                displayName: self.store.metadata(for: provider).displayName,
                snapshot: snapshot)
        }
        return SpendDashboardModel.build(
            inputs: inputs,
            requestedDays: self.settings.costUsageHistoryDays,
            reportingPeriod: self.settings.costReportingPeriod,
            now: now,
            calendar: self.settings.costUsageBucketCalendar,
            preferredCurrencyCode: self.settings.preferredCurrencyCode)
    }
}
