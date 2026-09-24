import CodexBarCore
import SwiftUI

struct ShareStatsCardView: View {
    static let size = CGSize(width: 1200, height: 630)

    let payload: ShareStatsPayload

    private let background = Color(red: 0.055, green: 0.071, blue: 0.086)
    private let primary = Color(red: 0.93, green: 0.95, blue: 0.96)
    private let secondary = Color(red: 0.55, green: 0.62, blue: 0.68)
    private let track = Color(red: 0.14, green: 0.17, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            self.hero
                .padding(.top, 42)
            self.mix
                .padding(.top, 39)
            Spacer(minLength: 20)
            self.footer
        }
        .padding(.horizontal, 58)
        .padding(.vertical, 40)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(self.background)
        .foregroundStyle(self.primary)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 11) {
                ShareStatsMark(colors: Array(self.mixSegments.prefix(3)).map(\.color))
                    .frame(width: 26, height: 26)
                Text("CodexBar")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text(self.periodLabel.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(self.secondary)
        }
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 19) {
            Text(self.trackedTokensText)
                .font(.system(size: 138, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.52)
                .contentTransition(.numericText())
                .layoutPriority(1)
            Text("TOKENS\nTRACKED")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(self.secondary)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mix: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.payload.hasPartialModels ? "KNOWN MODEL FAMILY MIX" : "MODEL FAMILY MIX")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(self.secondary)
                Spacer()
                if self.payload.hasPartialModels {
                    Text("Some model data unavailable")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(self.secondary)
                }
            }

            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(Array(self.mixSegments.enumerated()), id: \.offset) { _, segment in
                        let width = max(
                            4,
                            (geometry.size.width - CGFloat((self.mixSegments.count - 1) * 4)) * segment.share)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(segment.color)
                            .frame(width: width)
                            .overlay(alignment: .bottomLeading) {
                                if width > 155 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(segment.sharePercent)%")
                                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                        Text(segment.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(self.background)
                                    .padding(16)
                                }
                            }
                    }
                    if self.mixSegments.isEmpty {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(self.track)
                    }
                }
            }
            .frame(height: 125)

            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(self.mixSegments.enumerated()), id: \.offset) { _, segment in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 7, height: 7)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(segment.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Text("\(segment.sharePercent)% · \(segment.tokenText) tokens")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(self.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            self.costContext
                .padding(.top, 8)
        }
    }

    private var costContext: some View {
        HStack(alignment: .top, spacing: 15) {
            Text("COST CONTEXT")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(self.secondary)
                .padding(.top, 2)
            if self.payload.currencies.isEmpty {
                Text("No cost data")
                    .foregroundStyle(self.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(self.payload.currencies.prefix(2))) { currency in
                        let coverage = ShareStatsFormatting.coverageFraction(
                            covered: currency.coveredDayCount,
                            payload: self.payload)
                        HStack(spacing: 6) {
                            Text(currency.currencyCode)
                                .foregroundStyle(self.secondary)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(self.spendText(for: currency))
                                .foregroundStyle(self.primary)
                                .monospacedDigit()
                            Text("· \(coverage) · \(self.provenanceLabel(currency.provenance))")
                                .foregroundStyle(self.secondary)
                        }
                        .lineLimit(1)
                    }
                    if self.payload.currencies.count > 2 {
                        Text("+\(self.payload.currencies.count - 2) more currencies in copied stats")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(self.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 0.34, green: 0.78, blue: 0.66)).frame(width: 6, height: 6)
            Text("LOCAL SNAPSHOT")
                .tracking(0.8)
            Text("·")
            Text("Through \(ShareStatsFormatting.dataThrough(self.payload))")
            Spacer()
            Text("\(Set(self.payload.providers.map(\.provider)).count) providers")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(self.secondary)
        .padding(.top, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(self.secondary.opacity(0.18)).frame(height: 1)
        }
    }

    private var mixSegments: [ShareStatsMixSegment] {
        Self.mixSegments(for: self.payload, otherColor: self.secondary)
    }

    /// Groups models by display name across serving providers, keeps the four largest
    /// families, and folds the rest into one "Other" segment. Fails closed to an empty
    /// mix when any family total overflows.
    static func mixSegments(for payload: ShareStatsPayload, otherColor: Color) -> [ShareStatsMixSegment] {
        let families = Dictionary(
            grouping: payload.topModels.filter { ($0.totalTokens ?? 0) > 0 },
            by: \.modelName)
        let models = families.compactMap { name, rows -> (name: String, tokens: Int)? in
            guard let tokens = CheckedSum.integers(rows.compactMap(\.totalTokens)) else { return nil }
            return (name: name, tokens: tokens)
        }.sorted { lhs, rhs in
            lhs.tokens == rhs.tokens ? lhs.name < rhs.name : lhs.tokens > rhs.tokens
        }
        guard models.count == families.count else { return [] }
        let displayed = Array(models.prefix(4))
        let total = models.reduce(0.0) { $0 + Double($1.tokens) }
        guard total > 0 else { return [] }
        var segments = displayed.enumerated().map { index, model in
            ShareStatsMixSegment(
                name: model.name,
                share: Double(model.tokens) / total,
                tokenText: ShareStatsFormatting.compactCount(model.tokens),
                color: ShareStatsPalette.color(at: index))
        }
        let remainder = models.dropFirst(displayed.count).reduce(0.0) { $0 + Double($1.tokens) }
        if remainder > 0 {
            segments.append(ShareStatsMixSegment(
                name: "Other model families",
                share: remainder / total,
                tokenText: ShareStatsFormatting.compactCount(Int(remainder)),
                color: otherColor))
        }
        return segments
    }

    private var isAllTime: Bool {
        self.payload.days >= SpendDashboardSource.scanDays
    }

    private var periodLabel: String {
        self.isAllTime ? "All time" : "Last \(self.payload.days) days"
    }

    private var trackedTokensText: String {
        guard let tokens = self.payload.totalTokens else { return "—" }
        let formatted = ShareStatsFormatting.compactCount(tokens)
        return self.payload.hasPartialTokens ? "~\(formatted)" : formatted
    }

    private func spendText(for currency: ShareStatsCurrencyPayload) -> String {
        guard let cost = currency.estimatedCost else { return "Unavailable" }
        let formatted = ShareStatsFormatting.currency(cost, code: currency.currencyCode)
        return currency.isPartial ? "~\(formatted)" : formatted
    }

    private func provenanceLabel(_ provenance: CostProvenance) -> String {
        switch provenance {
        case .listPriceEstimate: "API value estimate · not billed"
        case .vendorMetered: "provider reported"
        case .mixed: "mixed basis"
        case .unknown: "basis unknown"
        }
    }
}

struct ShareStatsMixSegment {
    let name: String
    let share: Double
    let tokenText: String
    let color: Color

    var sharePercent: Int {
        Int((self.share * 100).rounded())
    }
}

private enum ShareStatsPalette {
    static let colors = [
        Color(red: 0.34, green: 0.78, blue: 0.66),
        Color(red: 0.50, green: 0.68, blue: 0.98),
        Color(red: 0.91, green: 0.72, blue: 0.38),
        Color(red: 0.81, green: 0.55, blue: 0.84),
        Color(red: 0.34, green: 0.77, blue: 0.85),
        Color(red: 0.94, green: 0.51, blue: 0.55),
    ]

    static func color(at index: Int) -> Color {
        self.colors[index % self.colors.count]
    }
}

private struct ShareStatsMark: View {
    let colors: [Color]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array([0.42, 0.72, 1.0].enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(self.colors.indices.contains(index) ? self.colors[index] : Color.white.opacity(0.65))
                    .frame(width: 4, height: 23 * height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
