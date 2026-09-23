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
                .padding(.top, 49)
            self.mix
                .padding(.top, 50)
            Spacer(minLength: 24)
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
                ShareStatsMark(colors: self.visibleModels.map(self.color(for:)))
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
        HStack(alignment: .bottom, spacing: 35) {
            VStack(alignment: .leading, spacing: 7) {
                Text(self.trackedTokensText)
                    .font(.system(size: 112, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .contentTransition(.numericText())
                Text("TOKENS TRACKED")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(self.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(self.secondary.opacity(0.27))
                .frame(width: 1, height: 76)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("COST CONTEXT")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(self.secondary)
                ForEach(self.payload.currencies) { currency in
                    HStack(spacing: 7) {
                        Text(self.spendText(for: currency))
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(self.provenanceLabel(currency.provenance))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(self.secondary)
                            .lineLimit(1)
                    }
                }
                if self.payload.currencies.isEmpty {
                    Text("No cost data")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(self.secondary)
                }
            }
            .frame(width: 330, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    private var mix: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.payload.hasPartialModels ? "KNOWN MODEL MIX" : "MODEL MIX")
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
                HStack(spacing: 3) {
                    ForEach(Array(self.mixSegments.enumerated()), id: \.offset) { _, segment in
                        Capsule(style: .continuous)
                            .fill(segment.color)
                            .frame(width: max(
                                3,
                                (geometry.size.width - CGFloat((self.mixSegments.count - 1) * 3)) * segment.share))
                    }
                    if self.mixSegments.isEmpty {
                        Capsule(style: .continuous).fill(self.track)
                    }
                }
            }
            .frame(height: 13)
            .background(self.track, in: Capsule())

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
                            Text("\(segment.sharePercent)% · \(segment.tokenText)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(self.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 0.34, green: 0.78, blue: 0.66)).frame(width: 6, height: 6)
            Text("LOCAL USAGE LOGS")
                .tracking(0.8)
            Text("·")
            Text("Through \(ShareStatsFormatting.dataThrough(self.payload))")
            Spacer()
            Text("\(self.payload.providers.count) providers")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(self.secondary)
        .padding(.top, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(self.secondary.opacity(0.18)).frame(height: 1)
        }
    }

    private var visibleModels: [ShareStatsModelPayload] {
        Array(self.payload.topModels.prefix(4))
    }

    private var mixSegments: [ShareStatsMixSegment] {
        let models = self.payload.topModels.filter { ($0.totalTokens ?? 0) > 0 }
        let displayed = Array(models.prefix(4))
        let total = models.reduce(0.0) { $0 + Double($1.totalTokens ?? 0) }
        guard total > 0 else { return [] }
        var segments = displayed.map { model in
            ShareStatsMixSegment(
                name: model.modelName,
                share: Double(model.totalTokens ?? 0) / total,
                tokenText: ShareStatsFormatting.compactCount(model.totalTokens ?? 0),
                color: self.color(for: model))
        }
        let remainder = models.dropFirst(displayed.count).reduce(0.0) { $0 + Double($1.totalTokens ?? 0) }
        if remainder > 0 {
            segments.append(ShareStatsMixSegment(
                name: "Other models",
                share: remainder / total,
                tokenText: ShareStatsFormatting.compactCount(Int(remainder)),
                color: self.secondary))
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
        case .listPriceEstimate: "list-price estimate"
        case .vendorMetered: "provider reported"
        case .mixed: "mixed basis"
        case .unknown: "basis unknown"
        }
    }

    private func color(for model: ShareStatsModelPayload) -> Color {
        guard let index = self.payload.providers.firstIndex(where: { $0.provider == model.provider }) else {
            return self.secondary
        }
        return ShareStatsPalette.color(at: index)
    }
}

private struct ShareStatsMixSegment {
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
