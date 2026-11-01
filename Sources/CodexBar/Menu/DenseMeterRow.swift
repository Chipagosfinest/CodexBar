import CodexBarCore
import SwiftUI

extension UsageMenuCardView.Model.Metric {
    /// Remaining share at or below which a limit turns red.
    static let nearLimitRemainingPercent: Double = 10

    var isNearLimit: Bool {
        let remaining = self.percentStyle == .left ? self.percent : 100 - self.percent
        return remaining <= Self.nearLimitRemainingPercent
    }

    /// The only note that keeps a visible line: an unfavorable pace forecast, or provider text that is not a forecast.
    var denseWarningText: String? {
        if self.detailIsPaceDerived {
            guard let forecast = self.detailRightText, !forecast.hasPrefix(L("Lasts until reset")) else { return nil }
            return forecast
        }
        return self.detailText ?? self.linePresentation(title: "").metaText
    }

    func denseHelpText(presentation: LinePresentation) -> String {
        [
            self.resetText,
            presentation.metaText,
            self.detailText,
            self.dailyTargetText,
            self.helpText,
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }
}

/// Title, thin bar, value, reset on a single line. Neutral fill: colour only signals a limit that is close.
struct DenseMeterRow: View {
    static let criticalColor = Color(nsColor: .systemRed)

    let title: String
    let percent: Double?
    var isCritical = false
    var accessibilityLabel = ""
    let value: String
    var trailing: String?
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(self.title)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 46, alignment: .leading)
                .layoutPriority(1)
            if let percent {
                UsageProgressBar(
                    percent: percent,
                    tint: self.isCritical ? Self.criticalColor : Color.primary.opacity(0.62),
                    accessibilityLabel: self.accessibilityLabel)
                    .frame(minWidth: 36)
            } else {
                Spacer(minLength: 4)
            }
            Text(self.value)
                .font(.footnote)
                .fontWeight(self.isCritical ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(self.isCritical
                    ? MenuHighlightStyle.error(self.isHighlighted)
                    : MenuHighlightStyle.primary(self.isHighlighted))
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 52, alignment: .trailing)
                .layoutPriority(2)
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: 40, alignment: .trailing)
                    .layoutPriority(2)
            }
        }
        .frame(minHeight: 16)
    }

    /// "Updated 5m ago" reads as "5m ago" beside the account; the word adds no information in a header.
    static func shortFreshness(_ text: String) -> String {
        let prefix = L("Updated") + " "
        return text.hasPrefix(prefix) ? String(text.dropFirst(prefix.count)) : text
    }

    /// "Resets in 2h 18m" reads as "2h 18m" next to a meter; the localized template supplies what to strip.
    static func shortReset(_ text: String) -> String {
        for template in [L("Resets in %@"), L("Resets %@")] {
            let parts = template.components(separatedBy: "%@")
            guard parts.count == 2,
                  text.hasPrefix(parts[0]),
                  text.hasSuffix(parts[1]),
                  text.count > parts[0].count + parts[1].count
            else { continue }
            return String(text.dropFirst(parts[0].count).dropLast(parts[1].count))
        }
        return text
    }
}

/// Text rows with an effort-tier dot: the share is already a number, so the section adds no more bars.
struct TopModelsContent: View {
    let models: [InlineUsageDashboardModel.TopModel]
    let title: String
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(self.title)
                .font(.caption2)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            ForEach(self.models) { model in
                HStack(spacing: 6) {
                    Circle()
                        .fill(self.color(for: model))
                        .frame(width: 6, height: 6)
                    Text(model.name)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    Text(model.shareText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .lineLimit(1)
                        .fixedSize()
                    Text(model.value)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func color(for model: InlineUsageDashboardModel.TopModel) -> Color {
        if self.isHighlighted { return MenuHighlightStyle.secondary(true) }
        let color = model.tier.color(dark: self.colorScheme == .dark)
        return Color(red: color.red, green: color.green, blue: color.blue)
    }
}
