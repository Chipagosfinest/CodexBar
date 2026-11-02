import CodexBarCore
import SwiftUI

/// One provider on one line: the limit that stops it next. Detail lives in the flyout, so the height is fixed.
struct OverviewProviderLine: Equatable, Identifiable {
    enum Status: Equatable {
        case normal
        case critical
        case stale
    }

    let id: String
    let provider: UsageProvider
    let name: String
    /// The window the figures describe, or the account on a per-account row.
    let caption: String?
    let captionIsCritical: Bool
    /// Only names the window, so a tight row drops it rather than clip it. A forecast, stale note or account stays.
    let captionIsOptional: Bool
    /// Bar fill. Follows the Show Used setting. Nil when the provider reports no limit.
    let percent: Double?
    let accessibilityLabel: String
    let value: String?
    let trailing: String?
    let status: Status
    let remainingPercent: Double?
    let exhaustionETASeconds: TimeInterval?

    init(id: String, model: UsageMenuCardView.Model, account: String? = nil) {
        self.id = id
        self.provider = model.provider
        self.name = model.providerName
        let metrics = model.metrics.filter { $0.statusText == nil }
        let imminent = metrics.filter(\.isExhaustionImminent)
            .min { ($0.exhaustionETASeconds ?? 0) < ($1.exhaustionETASeconds ?? 0) }
        let lowest = metrics.min { $0.remainingPercent < $1.remainingPercent }
        // An exhausted limit has already stopped the provider; a forecast only says when one will.
        let tightest = (lowest?.remainingPercent ?? 100) <= 0 ? lowest : (imminent ?? lowest)
        let isStale = model.subtitleStyle == .error

        guard let tightest else {
            self.caption = account
            self.captionIsCritical = false
            self.captionIsOptional = false
            self.percent = nil
            self.accessibilityLabel = ""
            self.value = Self.fallbackValue(model)
            self.trailing = nil
            self.status = isStale ? .stale : .normal
            self.remainingPercent = nil
            self.exhaustionETASeconds = nil
            return
        }
        self.percent = tightest.percent
        self.accessibilityLabel = tightest.percentStyle.accessibilityLabel
        self.value = tightest.percentLabel
            .replacingOccurrences(of: tightest.percentStyle.labelSuffix, with: "")
            .trimmingCharacters(in: .whitespaces)
        self.remainingPercent = tightest.remainingPercent
        self.exhaustionETASeconds = tightest.exhaustionETASeconds
        self.status = isStale ? .stale : (tightest.isUrgent ? .critical : .normal)
        // Each column keeps one meaning, so the forecast and the stale note take the caption, not the reset's slot.
        // A per-account row keeps the account: without it two rows from one provider read the same.
        let imminentETA = account == nil && !isStale && tightest.isExhaustionImminent
            ? tightest.exhaustionETASeconds : nil
        self.captionIsCritical = imminentETA != nil
        self.captionIsOptional = account == nil && imminentETA == nil && !isStale
        self.caption = if let account {
            account
        } else if let imminentETA {
            L("empty ~%@", UsagePaceText.durationText(seconds: imminentETA, now: Date()))
        } else if isStale {
            L("stale data")
        } else {
            tightest.title
        }
        self.trailing = tightest.resetText.map(DenseMeterRow.shortReset)
    }

    private static func fallbackValue(_ model: UsageMenuCardView.Model) -> String? {
        model.creditsText
            ?? model.providerCost?.spendLine
            ?? model.providerDetails.first?.rows.first?.value
            ?? model.placeholder
    }

    // MARK: - Urgency

    /// Urgent rows sort by when they stop; the rest read from least left to most, so the figures scan as a list.
    static func sortedByUrgency(_ lines: [OverviewProviderLine]) -> [OverviewProviderLine] {
        lines.enumerated().sorted { lhs, rhs in
            let (left, right) = (lhs.element, rhs.element)
            let (leftUrgent, rightUrgent) = (left.status == .critical, right.status == .critical)
            if leftUrgent != rightUrgent { return leftUrgent }
            if leftUrgent {
                let leftETA = left.exhaustionETASeconds ?? .infinity
                let rightETA = right.exhaustionETASeconds ?? .infinity
                if leftETA != rightETA { return leftETA < rightETA }
            }
            let leftRemaining = left.remainingPercent ?? .infinity
            let rightRemaining = right.remainingPercent ?? .infinity
            if leftRemaining != rightRemaining { return leftRemaining < rightRemaining }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }
}

/// Shared columns so the bars, percentages and resets line up down the list.
private enum OverviewLineColumns {
    static let logo: CGFloat = 15
    static let name: CGFloat = 104
    static let value: CGFloat = 30
    static let trailing: CGFloat = 46
    static let spacing: CGFloat = 6
}

struct OverviewProviderLineView: View {
    let line: OverviewProviderLine
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(spacing: OverviewLineColumns.spacing) {
            SpendProviderIcon(
                provider: self.line.provider,
                style: self.isHighlighted ? .monochrome : .brand,
                size: OverviewLineColumns.logo,
                foreground: MenuHighlightStyle.primary(self.isHighlighted))
            self.nameCell
            if let percent = self.line.percent {
                UsageProgressBar(
                    percent: percent,
                    tint: self.barTint,
                    accessibilityLabel: self.line.accessibilityLabel)
                    .frame(maxWidth: .infinity)
                self.valueText
                    .frame(width: OverviewLineColumns.value, alignment: .trailing)
                self.trailingText
                    .frame(width: OverviewLineColumns.trailing, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
                self.valueText
            }
        }
        .frame(height: 17)
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .frame(width: self.width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var nameCell: some View {
        ViewThatFits(in: .horizontal) {
            self.nameAndCaption(truncates: !self.line.captionIsOptional)
            self.nameAndCaption(truncates: true, showsCaption: !self.line.captionIsOptional)
        }
        .frame(width: OverviewLineColumns.name, alignment: .leading)
    }

    private func nameAndCaption(truncates: Bool, showsCaption: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(self.line.name)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                .lineLimit(1)
                .layoutPriority(1)
            if showsCaption, let caption = self.line.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(self.line.captionIsCritical
                        ? MenuHighlightStyle.error(self.isHighlighted)
                        : MenuHighlightStyle.secondary(self.isHighlighted))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: !truncates, vertical: false)
            }
        }
    }

    private var valueText: some View {
        Text(self.line.value ?? "")
            .font(.footnote)
            .fontWeight(self.line.status == .critical ? .semibold : .regular)
            .monospacedDigit()
            .foregroundStyle(self.valueColor)
            .lineLimit(1)
    }

    private var trailingText: some View {
        Text(self.line.trailing ?? "")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var barTint: Color {
        switch self.line.status {
        case .critical: DenseMeterRow.criticalColor
        case .stale: Color.primary.opacity(0.2)
        // A full bar means plenty left, so the fill stays quiet and the figure beside it does the talking.
        case .normal: Color.primary.opacity(0.42)
        }
    }

    private var valueColor: Color {
        switch self.line.status {
        case .critical: MenuHighlightStyle.error(self.isHighlighted)
        case .stale: MenuHighlightStyle.secondary(self.isHighlighted)
        case .normal: MenuHighlightStyle.primary(self.isHighlighted)
        }
    }
}

/// Column heads for the list. A bare "8%" only reads correctly if it says whether that is left or used.
struct OverviewLinesHeaderView: View {
    let percentStyle: UsageMenuCardView.Model.PercentStyle
    let width: CGFloat

    var body: some View {
        HStack(spacing: OverviewLineColumns.spacing) {
            Text(L("Usage"))
            Spacer(minLength: 0)
            Text(self.percentStyle.labelSuffix.localizedCapitalized)
                .frame(minWidth: OverviewLineColumns.value, alignment: .trailing)
            Text(L("Resets"))
                .frame(width: OverviewLineColumns.trailing, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(MenuHighlightStyle.normalSecondaryText)
        .lineLimit(1)
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .frame(width: self.width, alignment: .leading)
        .frame(height: 8)
    }
}

/// Providers whose only state is an error. One line however many, so a broken provider cannot push the footer.
struct OverviewAttentionRowView: View {
    let provider: UsageProvider?
    /// Nil on the combined row, where the message already lists every provider.
    let name: String?
    let message: String
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(alignment: .center, spacing: OverviewLineColumns.spacing) {
            if let provider {
                SpendProviderIcon(
                    provider: provider,
                    style: self.isHighlighted ? .monochrome : .brand,
                    size: OverviewLineColumns.logo,
                    foreground: MenuHighlightStyle.primary(self.isHighlighted))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                    .frame(width: OverviewLineColumns.logo)
            }
            if let name {
                Text(name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Text(self.message)
                .font(.caption)
                .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: 17)
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .frame(width: self.width, alignment: .leading)
        .help([self.name, self.message].compactMap(\.self).joined(separator: ": "))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Daily spend and model mix

struct OverviewDailySpend: Equatable {
    let points: [MenuUsageBarPoint]
    /// Nil before the first spend of the day.
    let todayValue: String?
    /// The bar the Today figure describes. Nil when today has no spend yet.
    var todayPointID: String?
}

/// Today's spend beside one 30-day spark across every provider. Hovering a bar swaps the label for that day.
struct OverviewDailySpendStrip: View {
    let daily: OverviewDailySpend
    @State private var selectedPointID: String?
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        let hover = self.daily.points.first { $0.id == self.selectedPointID }?.hoverSummary
        HStack(alignment: .center, spacing: 8) {
            // Today's figure takes the emphasized bar's colour: the same fact, said twice.
            (hover.map { Text($0) } ?? self.todayText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                .lineLimit(1)
                .frame(minWidth: 84, alignment: .leading)
                .layoutPriority(1)
            MenuUsageBarStrip(
                points: self.daily.points,
                baseColor: Color.primary.opacity(0.32),
                emphasizedPointID: self.daily.todayPointID,
                selection: self.$selectedPointID)
                .frame(height: 18)
        }
    }

    private var todayText: Text {
        let value = Text(self.daily.todayValue ?? "\u{2014}")
            .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
        return Text("\(L("Today")) \(value)")
    }
}

/// The top models on one line. Spend per model is one level down, in this row's submenu.
struct OverviewModelMixRowView: View {
    let models: [InlineUsageDashboardModel.TopModel]
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Whole entries only: drop the last model rather than clip a name or its share. All of them are in the submenu.
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: self.models.count, to: 0, by: -1)), id: \.self) { count in
                Text(self.mix(count: count))
                    .fixedSize()
            }
        }
        .font(.caption)
        .monospacedDigit()
        .frame(height: 12)
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .padding(.trailing, 12)
        .frame(width: self.width, alignment: .leading)
    }

    private func mix(count: Int) -> AttributedString {
        var result = AttributedString()
        let names = Self.displayNames(self.models.map(\.name))
        for (index, model) in self.models.prefix(count).enumerated() {
            var dot = AttributedString((index > 0 ? "   " : "") + "\u{25CF} ")
            dot.foregroundColor = self.color(for: model)
            var name = AttributedString(names[index] + " ")
            name.foregroundColor = MenuHighlightStyle.primary(self.isHighlighted)
            var share = AttributedString(model.shareText)
            share.foregroundColor = MenuHighlightStyle.secondary(self.isHighlighted)
            result += dot + name + share
        }
        return result
    }

    /// Friendly names, unless shortening would make two different models read the same.
    static func displayNames(_ names: [String]) -> [String] {
        let friendly = names.map(self.displayName)
        return Set(friendly).count == Set(names).count ? friendly : names
    }

    /// "claude-opus-4-5" reads "Opus 4.5". Versions stay, because they are what tells two models apart.
    static func displayName(_ name: String) -> String {
        var parts = name.split(separator: "-").map(String.init)
        if parts.count > 1, ["claude", "gpt"].contains(parts[0]) { parts.removeFirst() }
        if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber), parts.count > 1 { parts.removeLast() }
        var words: [String] = []
        for part in parts {
            if let previous = words.last, previous.allSatisfy(\.isNumber), part.allSatisfy(\.isNumber) {
                words[words.count - 1] = "\(previous).\(part)"
            } else {
                words.append(part.prefix(1).uppercased() + part.dropFirst())
            }
        }
        return words.joined(separator: " ")
    }

    private func color(for model: InlineUsageDashboardModel.TopModel) -> Color {
        if self.isHighlighted { return MenuHighlightStyle.secondary(true) }
        let color = model.tier.color(dark: self.colorScheme == .dark)
        return Color(red: color.red, green: color.green, blue: color.blue)
    }
}
