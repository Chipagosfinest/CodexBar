import AppKit
import CodexBarCore
import Foundation
import SwiftUI

struct OverviewSpendSummary: Equatable {
    let primarySpendText: String
    let spendAmounts: [String]
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
            self.spendAmounts = []
            self.primarySpendText = providerCount > 0 && resolvedKnownCostProviderCount == providerCount
                ? L("No usage yet")
                : L("Spend unavailable")
        } else {
            self.spendAmounts = model.groups.map { group in
                let text = spendDashboardGroupCostText(group)
                guard isPartial, group.totalCost != nil, !text.hasPrefix("~") else { return text }
                return "~\(text)"
            }
            self.primarySpendText = self.spendAmounts.joined(separator: " · ")
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

struct OverviewSpendHorizon: Identifiable {
    let days: Int
    let summary: OverviewSpendSummary

    var id: Int {
        self.days
    }

    var label: String {
        switch self.days {
        case 1: L("Today")
        case 7: L("7d")
        case 30: L("30d")
        default: L("All")
        }
    }
}

struct OverviewSpendSummaryCardView: View {
    let summary: OverviewSpendSummary
    let days: Int
    let width: CGFloat
    var horizons: [OverviewSpendHorizon] = []
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text(L("Usage & Spend"))
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 4)
                Text(L("Total"))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))

            if self.horizons.isEmpty, self.summary.spendAmounts.count > 1 {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(self.summary.spendAmounts.enumerated()), id: \.offset) { _, amount in
                        self.amountText(amount, size: 21)
                    }
                }
            } else if self.horizons.isEmpty {
                self.amountText(self.summary.primarySpendText, size: 27)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(self.horizons) { horizon in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(horizon.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            self.amountText(horizon.summary.primarySpendText, size: 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .help(
                            "\(horizon.label): \(horizon.summary.primarySpendText). \(horizon.summary.providerCoverageText). \(horizon.summary.historyCoverageText)")
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: self.summary.isPartial ? "circle.lefthalf.filled" : "checkmark.circle.fill")
                    .foregroundStyle(
                        self.summary.isPartial
                            ? MenuHighlightStyle.secondary(self.isHighlighted)
                            : Color.green)
                    .accessibilityHidden(true)
                Text(self.summary.providerCoverageText)
                if let tokenText = self.summary.tokenText {
                    Text("/")
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    Text(tokenText)
                }
            }
            .font(.caption)
            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            .lineLimit(1)

            HStack(spacing: 6) {
                Text(self.summary.provenanceText)
                Text("·")
                Text(self.summary.historyCoverageText)
            }
            .font(.caption2)
            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .padding(.vertical, 11)
        .frame(width: self.width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(self.isHighlighted ? Color.white.opacity(0.055) : Color.primary.opacity(0.02))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(self.isHighlighted ? 0.1 : 0.04), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func amountText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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
                    title: "Usage snapshot unavailable",
                    message: "CodexBar couldn't prepare a shareable usage snapshot. "
                        + "Refresh Usage & Spend and try again.")
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
        now: Date = Date(),
        requestedDays: Int? = nil) -> SpendDashboardModel
    {
        let requestedDays = requestedDays ?? self.settings.costUsageHistoryDays
        let publication = self.store.spendDashboardPublication
        if let configuration = publication.configuration {
            guard configuration.menuOwnershipFingerprint == SpendDashboardSource.currentMenuOwnershipFingerprint(
                settings: self.settings,
                store: self.store)
            else {
                return SpendDashboardModel.build(
                    inputs: [],
                    requestedDays: requestedDays,
                    now: now,
                    calendar: self.settings.costUsageBucketCalendar,
                    preferredCurrencyCode: self.settings.preferredCurrencyCode)
            }
            return publication.model(
                requestedDays: requestedDays,
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
            requestedDays: requestedDays,
            now: now,
            calendar: self.settings.costUsageBucketCalendar,
            preferredCurrencyCode: self.settings.preferredCurrencyCode)
    }
}
